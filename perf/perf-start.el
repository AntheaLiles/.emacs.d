;;; perf-start.el --- Long-running, package-agnostic Emacs telemetry -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;; Purpose:
;;   Observe real-world Emacs runtime performance over days/weeks.
;;   This file deliberately knows nothing about packages or major modes.
;;
;; Installation in early-init.el:
;;   (load (expand-file-name "perf/perf-start.el" user-emacs-directory))
;;
;; No external package is required.  The only library loaded explicitly is
;; the built-in `profiler` library.

(require 'cl-lib)
(require 'seq)
(require 'profiler)

(defgroup my/perf nil
  "Long-running, package-agnostic Emacs performance telemetry."
  :group 'performance)

(defcustom my/perf-root
  (expand-file-name "perf/" user-emacs-directory)
  "Directory containing the performance dataset."
  :type 'directory)

(defcustom my/perf-command-threshold-ms 50.0
  "Log interactive commands whose wall-clock duration exceeds this value."
  :type 'number)

(defcustom my/perf-profiler-sampling-interval-ns 10000000
  "Sampling interval for the native CPU profiler, in nanoseconds.
10,000,000 ns = 10 ms."
  :type 'natnum)

(defcustom my/perf-cpu-rotation-interval-s 600
  "Approximate interval between native CPU profile snapshots."
  :type 'natnum)

(defcustom my/perf-process-snapshot-interval-s 30
  "Interval between system-process snapshots."
  :type 'natnum)

(defcustom my/perf-allocation-snapshot-interval-s 30
  "Interval between allocation-counter snapshots."
  :type 'natnum)

(defcustom my/perf-system-snapshot-interval-s 30
  "Interval between system-load snapshots."
  :type 'natnum)

(defcustom my/perf-flush-interval-s 60
  "Interval between forced flushes of buffered telemetry."
  :type 'natnum)

(defcustom my/perf-buffer-flush-bytes 65536
  "Flush an individual telemetry buffer when it reaches this size."
  :type 'natnum)

(defcustom my/perf-profiler-log-size 10000
  "Maximum number of distinct call stacks retained per CPU segment."
  :type 'natnum)

(defcustom my/perf-profiler-max-stack-depth 16
  "Maximum call-stack depth recorded by the native CPU profiler."
  :type 'natnum)

(defcustom my/perf-cpu-summary-top-n 50
  "Number of top CPU call stacks written to the summary per segment."
  :type 'natnum)

(defcustom my/perf-keep-cpu-profiles t
  "When non-nil, retain native `.elprof' files as well as summaries.
Set this to nil for a lower-storage, summary-only long campaign."
  :type 'boolean)

(defcustom my/perf-log-process-args nil
  "When non-nil, record process command-line arguments.
Disabled by default because command lines can contain sensitive data."
  :type 'boolean)

(defvar my/perf--active nil)
(defvar my/perf--run-id nil)
(defvar my/perf--seq 0)
(defvar my/perf--cpu-segment-id 0)
(defvar my/perf--cpu-segment-start-time nil)
(defvar my/perf--run-start-time nil)
(defvar my/perf--run-start-cpu nil)
(defvar my/perf--process-timer nil)
(defvar my/perf--allocation-timer nil)
(defvar my/perf--system-timer nil)
(defvar my/perf--cpu-timer nil)
(defvar my/perf--flush-timer nil)
(defvar my/perf--buffers nil)
(defvar my/perf--cpu-enabled nil)
(defvar my/perf--saved-profiler-sampling-interval nil)
(defvar my/perf--saved-profiler-log-size nil)
(defvar my/perf--saved-profiler-max-stack-depth nil)
(defvar my/perf--command-start-time nil)
(defvar my/perf--command-start-cpu nil)
(defvar my/perf--command-symbol nil)
(defvar my/perf--command-buffer-before nil)
(defvar my/perf--command-mode-before nil)
(defvar my/perf--command-gcs-before nil)
(defvar my/perf--command-gc-elapsed-before nil)
(defvar my/perf--last-gcs-done 0)
(defvar my/perf--last-gc-elapsed 0.0)
(defvar my/perf--io-disabled nil)

(defun my/perf--iso-time (&optional time)
  "Return TIME as an ISO-8601-like local timestamp with milliseconds."
  (format-time-string "%Y-%m-%dT%H:%M:%S.%3N%z" (or time (current-time))))

(defun my/perf--safe-cell (value)
  "Convert VALUE to one TSV-safe cell."
  (let ((s (cond ((null value) "")
                 ((stringp value) value)
                 ((symbolp value) (symbol-name value))
                 (t (format "%s" value)))))
    (replace-regexp-in-string "[\t\r\n]+" " " s t t)))

(defun my/perf--cpu-snapshot ()
  "Return CURRENT-CPU-TIME, or nil if unavailable."
  (when (fboundp 'current-cpu-time)
    (ignore-errors (current-cpu-time))))

(defun my/perf--cpu-delta-seconds (before after)
  "Return CPU seconds elapsed between BEFORE and AFTER, or nil.
BEFORE and AFTER are values returned by `current-cpu-time'."
  (when (and (consp before) (consp after)
             (numberp (car before)) (numberp (cdr before))
             (numberp (car after)) (numberp (cdr after))
             (> (cdr before) 0)
             (= (cdr before) (cdr after)))
    (let ((delta (- (car after) (car before))))
      (when (>= delta 0)
        (/ (float delta) (cdr before))))))

(defun my/perf--ensure-directory ()
  (make-directory my/perf-root t)
  (make-directory (expand-file-name "cpu" my/perf-root) t))

(defun my/perf--file (name)
  (expand-file-name name my/perf-root))

(defun my/perf--cpu-file (segment-id)
  (expand-file-name
   (format "cpu/%s-%06d.elprof" my/perf--run-id segment-id)
   my/perf-root))

(defun my/perf--buffer-for (file)
  "Return a dedicated hidden buffer associated with FILE."
  (let ((entry (cl-find file my/perf--buffers
                        :key #'car :test #'equal)))
    (if entry
        (cdr entry)
      (let ((buffer (get-buffer-create
                     (format " *my/perf %s*"
                             (file-name-nondirectory file)))))
        (setq my/perf--buffers
              (cons (cons file buffer) my/perf--buffers))
        buffer))))

(defun my/perf--flush-buffer (file buffer)
  "Append BUFFER contents to FILE and empty BUFFER.
The telemetry buffer is made current explicitly so that user buffers
are never read from or erased by the flush operation."
  (when (and (buffer-live-p buffer) (> (buffer-size buffer) 0))
    (with-current-buffer buffer
      (append-to-file (point-min) (point-max) file)
      (erase-buffer)
      (set-buffer-modified-p nil))))

(defun my/perf--flush-file (file)
  "Flush the buffer associated with FILE."
  (when-let* ((entry (cl-find file my/perf--buffers
                             :key #'car :test #'equal)))
    (my/perf--flush-buffer file (cdr entry))))

(defun my/perf--flush-all ()
  "Flush every buffered telemetry file."
  (dolist (entry my/perf--buffers)
    (my/perf--flush-buffer (car entry) (cdr entry))))

(defun my/perf--ensure-header (file header)
  (unless (file-exists-p file)
    (with-temp-file file
      (insert header))))

(defun my/perf--init-files ()
  (my/perf--ensure-header
   (my/perf--file "runtime.tsv")
   "seq\tlifecycle\ttimestamp\trun_id\tpid\temacs_version\tsystem_type\tsystem_configuration\twindow_system\tdaemon\tcpu_sampling_ns\tcpu_log_size\tcpu_max_stack_depth\tcommand_threshold_ms\tgc_cons_threshold\tgc_cons_percentage\tgcs_done\tgc_elapsed_s\temacs_cpu_s_total\n")
  (my/perf--ensure-header
   (my/perf--file "events.tsv")
   "seq\trun_id\ttimestamp\tevent\tcommand\tcommand_wall_ms\temacs_cpu_ms\tbuffer_before\tmode_before\tbuffer_after\tmode_after\tgc_count_delta\tgc_time_delta_ms\n")
  (my/perf--ensure-header
   (my/perf--file "gc.tsv")
   "seq\trun_id\ttimestamp\tgcs_done\tgc_elapsed_total_s\tgc_count_delta\tgc_time_delta_ms\tgc_cons_threshold\tgc_cons_percentage\n")
  (my/perf--ensure-header
   (my/perf--file "alloc.tsv")
   "seq\trun_id\ttimestamp\tcons_cells\tfloats\tvector_cells\tsymbols\tstring_chars\tmisc\tintervals\tstrings\n")
  (my/perf--ensure-header
   (my/perf--file "processes.tsv")
   "seq\trun_id\ttimestamp\tpid\tppid\trole\tsource\temacs_object\temacs_name\temacs_status\tcomm\tstate\tutime_s\tstime_s\tpcpu\tpmem\trss_kb\tvsize_kb\tthreads\tetime_s\targs\n")
  (my/perf--ensure-header
   (my/perf--file "system.tsv")
   "seq\trun_id\ttimestamp\tload1\tload5\tload15\ttotal_memory_kb\tfree_memory_kb\n")
  (my/perf--ensure-header
   (my/perf--file "overhead.tsv")
   "seq\trun_id\ttimestamp\tcomponent\tstatus\twall_ms\temacs_cpu_ms\tdetails\n")
  (my/perf--ensure-header
   (my/perf--file "cpu/index.tsv")
   "seq\trun_id\tsegment_id\ttimestamp_start\ttimestamp_snapshot\ttimestamp_next_start\twall_span_s\tsample_count\trecorded_samples\tdiscarded_samples\tautomatic_gc_samples\tdistinct_stacks\tsummary_file\tprofile_file\tcapture_wall_ms\tcapture_cpu_ms\n")
  (my/perf--ensure-header
   (my/perf--file "cpu/summary.tsv")
   "seq\trun_id\tsegment_id\trank\tsamples\tpercent\tstack\n"))

(defun my/perf--append-row (filename cells)
  "Append CELLS as one TSV row, buffering the write."
  (unless my/perf--io-disabled
    (condition-case err
        (let* ((file (my/perf--file filename))
               (buffer (my/perf--buffer-for file))
               (line (mapconcat #'my/perf--safe-cell cells "\t")))
          (with-current-buffer buffer
            (insert line "\n")
            (when (>= (buffer-size) my/perf-buffer-flush-bytes)
              (my/perf--flush-buffer file buffer))))
      (error
       (setq my/perf--io-disabled t)
       (message "perf-start: telemetry I/O disabled after error: %s"
                (error-message-string err))))))

(defun my/perf--append-cpu-row (cells)
  "Append CELLS as one CPU-index TSV row."
  (my/perf--append-row "cpu/index.tsv" cells))

(defun my/perf--run-id ()
  (format "%s-%d" (format-time-string "%Y%m%dT%H%M%S") (emacs-pid)))

(defun my/perf--collect-runtime (lifecycle)
  "Write one runtime lifecycle row for LIFECYCLE."
  (let* ((now (current-time))
         (cpu-now (my/perf--cpu-snapshot))
         (cpu-total (if (eq lifecycle 'end)
                        (my/perf--cpu-delta-seconds my/perf--run-start-cpu cpu-now)
                      0.0)))
    (my/perf--append-row
     "runtime.tsv"
     (list
      (cl-incf my/perf--seq)
      lifecycle
      (my/perf--iso-time now)
      my/perf--run-id
      (emacs-pid)
      emacs-version
      system-type
      system-configuration
      window-system
      (and (fboundp 'daemonp) (daemonp))
      my/perf-profiler-sampling-interval-ns
      profiler-log-size
      profiler-max-stack-depth
      my/perf-command-threshold-ms
      gc-cons-threshold
      gc-cons-percentage
      gcs-done
      gc-elapsed
      cpu-total))))

(defun my/perf--context-buffer ()
  (buffer-name (current-buffer)))

(defun my/perf--context-mode ()
  major-mode)

(defun my/perf--pre-command ()
  "Record minimal state immediately before an interactive command."
  (when my/perf--active
    (setq my/perf--command-start-time (current-time)
          my/perf--command-start-cpu (my/perf--cpu-snapshot)
          my/perf--command-symbol this-command
          my/perf--command-buffer-before (my/perf--context-buffer)
          my/perf--command-mode-before (my/perf--context-mode)
          my/perf--command-gcs-before gcs-done
          my/perf--command-gc-elapsed-before gc-elapsed)))

(defun my/perf--post-command ()
  "Log an interactive command when its wall-clock cost exceeds the threshold."
  (when (and my/perf--active my/perf--command-start-time)
    (condition-case err
        (let* ((end (current-time))
               (wall-ms (* 1000.0
                           (float-time
                            (time-subtract end my/perf--command-start-time))))
               (cpu-seconds
                (my/perf--cpu-delta-seconds
                 my/perf--command-start-cpu
                 (my/perf--cpu-snapshot)))
               (gc-count-delta (- gcs-done my/perf--command-gcs-before))
               (gc-time-delta-ms
                (* 1000.0
                   (- gc-elapsed my/perf--command-gc-elapsed-before))))
          (when (>= wall-ms my/perf-command-threshold-ms)
            (my/perf--append-row
             "events.tsv"
             (list
              (cl-incf my/perf--seq)
              my/perf--run-id
              (my/perf--iso-time end)
              "command-slow"
              my/perf--command-symbol
              (format "%.3f" wall-ms)
              (and cpu-seconds (format "%.3f" (* 1000.0 cpu-seconds)))
              my/perf--command-buffer-before
              my/perf--command-mode-before
              (my/perf--context-buffer)
              (my/perf--context-mode)
              gc-count-delta
              (format "%.3f" gc-time-delta-ms)))))
      (error
       (my/perf--append-row
        "overhead.tsv"
        (list
         (cl-incf my/perf--seq)
         my/perf--run-id
         (my/perf--iso-time)
         "command-logger"
         "error"
         ""
         ""
         (error-message-string err)))))
    (setq my/perf--command-start-time nil
          my/perf--command-start-cpu nil
          my/perf--command-symbol nil
          my/perf--command-buffer-before nil
          my/perf--command-mode-before nil
          my/perf--command-gcs-before nil
          my/perf--command-gc-elapsed-before nil)))

(defun my/perf--post-gc ()
  "Record the completion of a garbage collection."
  (when my/perf--active
    (let ((count-delta (- gcs-done my/perf--last-gcs-done))
          (time-delta-ms (* 1000.0
                             (- gc-elapsed my/perf--last-gc-elapsed))))
      (my/perf--append-row
       "gc.tsv"
       (list
        (cl-incf my/perf--seq)
        my/perf--run-id
        (my/perf--iso-time)
        gcs-done
        (format "%.6f" gc-elapsed)
        count-delta
        (format "%.3f" time-delta-ms)
        gc-cons-threshold
        gc-cons-percentage))
      (setq my/perf--last-gcs-done gcs-done
            my/perf--last-gc-elapsed gc-elapsed))))

(defun my/perf--snapshot-allocation ()
  "Record cumulative allocation counters."
  (let ((counts (memory-use-counts)))
    (my/perf--append-row
     "alloc.tsv"
     (list
      (cl-incf my/perf--seq)
      my/perf--run-id
      (my/perf--iso-time)
      (nth 0 counts)
      (nth 1 counts)
      (nth 2 counts)
      (nth 3 counts)
      (nth 4 counts)
      (nth 5 counts)
      (nth 6 counts)
      (nth 7 counts)))))

(defun my/perf--snapshot-system ()
  "Record local system load and memory information when available."
  (let ((load (ignore-errors (load-average t)))
        (mem (let ((default-directory user-emacs-directory))
               (ignore-errors (memory-info)))))
    (my/perf--append-row
     "system.tsv"
     (list
      (cl-incf my/perf--seq)
      my/perf--run-id
      (my/perf--iso-time)
      (nth 0 load)
      (nth 1 load)
      (nth 2 load)
      (and (consp mem) (nth 0 mem))
      (and (consp mem) (nth 1 mem))))))

(defun my/perf--system-descendants (root attrs-table)
  "Return ROOT and all descendants represented in ATTRS-TABLE."
  (let ((result nil))
    (maphash
     (lambda (pid _attrs)
       (let ((current pid)
             (seen (make-hash-table :test #'eql))
             (belongs nil))
         (while (and current (not belongs)
                     (not (gethash current seen)))
           (puthash current t seen)
           (cond
            ((= current root)
             (setq belongs t))
            (t
             (let ((a (gethash current attrs-table)))
               (setq current (and a (alist-get 'ppid a)))))))
         (when belongs
           (push pid result))))
     attrs-table)
    (delete-dups (cons root result))))

(defun my/perf--snapshot-processes ()
  "Record Emacs subprocesses and local OS descendants of Emacs."
  (let* ((root (emacs-pid))
         (pids (let ((default-directory user-emacs-directory))
                 (ignore-errors (list-system-processes))))
         (attrs-table (make-hash-table :test #'eql))
         (emacs-objects (make-hash-table :test #'eql)))
    (dolist (pid pids)
      (when-let* ((attrs (let ((default-directory user-emacs-directory))
                          (ignore-errors (process-attributes pid)))))
        (puthash pid attrs attrs-table)))
    (dolist (process (process-list))
      (when-let* ((pid (and (processp process)
                           (ignore-errors (process-id process)))))
        (puthash pid process emacs-objects)))
    (dolist (pid (my/perf--system-descendants root attrs-table))
      (when-let* ((attrs (gethash pid attrs-table)))
        (let* ((proc (gethash pid emacs-objects))
               (source (if proc "emacs+system" "system"))
               (role (if (= pid root) "emacs-root" "descendant")))
          (my/perf--append-row
           "processes.tsv"
           (list
            (cl-incf my/perf--seq)
            my/perf--run-id
            (my/perf--iso-time)
            pid
            (alist-get 'ppid attrs)
            role
            source
            (and proc t)
            (and proc (process-name proc))
            (and proc (process-status proc))
            (alist-get 'comm attrs)
            (alist-get 'state attrs)
            (alist-get 'utime attrs)
            (alist-get 'stime attrs)
            (alist-get 'pcpu attrs)
            (alist-get 'pmem attrs)
            (alist-get 'rss attrs)
            (alist-get 'vsize attrs)
            (alist-get 'thcount attrs)
            (let ((etime (alist-get 'etime attrs)))
              (and etime (float-time etime)))
            (and my/perf-log-process-args (alist-get 'args attrs)))))))))

(defun my/perf--backtrace-string (backtrace)
  "Return a compact printable representation of BACKTRACE."
  (let ((fixed (if (fboundp 'profiler-fixup-backtrace)
                   (profiler-fixup-backtrace backtrace)
                 backtrace)))
    (mapconcat
     (lambda (entry)
       (cond ((symbolp entry) (symbol-name entry))
             ((null entry) "nil")
             (t (format "%S" entry))))
     (append fixed nil)
     " > ")))

(defun my/perf--cpu-log-stats (log)
  "Return summary data for native profiler LOG."
  (let ((total 0)
        (discarded 0)
        (gc 0)
        (special 0)
        (stacks nil))
    (maphash
     (lambda (backtrace count)
       (let* ((first (aref backtrace 0))
              (name (and (symbolp first) (symbol-name first))))
         (setq total (+ total count))
         (cond
          ((equal name "Discarded Samples")
           (setq discarded (+ discarded count))
           (cl-incf special))
          ((equal name "Automatic GC")
           (setq gc (+ gc count))
           (cl-incf special))
          (t
           (push (cons count (my/perf--backtrace-string backtrace)) stacks)))))
     log)
    (setq stacks (sort stacks (lambda (a b) (> (car a) (car b)))))
    (list :total total
          :recorded (- total discarded)
          :discarded discarded
          :gc gc
          :distinct (- (hash-table-count log) special)
          :stacks stacks)))

(defun my/perf--write-cpu-summary (seq segment stats)
  "Write top call-stack rows from STATS for SEGMENT."
  (let ((total (plist-get stats :recorded))
        (rank 0))
    (dolist (entry (cl-subseq (plist-get stats :stacks)
                              0
                              (min my/perf-cpu-summary-top-n
                                   (length (plist-get stats :stacks)))))
      (cl-incf rank)
      (my/perf--append-row
       "cpu/summary.tsv"
       (list
        seq
        my/perf--run-id
        segment
        rank
        (car entry)
        (if (> total 0)
            (format "%.6f" (* 100.0 (/ (float (car entry)) total)))
          "0")
        (cdr entry))))))

(defun my/perf--capture-cpu-segment ()
  "Extract the current native CPU profiler segment without stopping profiling."
  (when my/perf--cpu-enabled
    (let* ((segment (cl-incf my/perf--cpu-segment-id))
           (start my/perf--cpu-segment-start-time)
           (snapshot-time (current-time))
           (seq (cl-incf my/perf--seq))
           (capture-wall-start (current-time))
           (capture-cpu-start (my/perf--cpu-snapshot))
           (log (profiler-cpu-log))
           (capture-end (current-time))
           (next-start (current-time))
           (capture-wall-ms
            (* 1000.0
               (float-time
                (time-subtract capture-end capture-wall-start))))
           (capture-cpu-ms
            (and capture-cpu-start
                 (my/perf--cpu-delta-seconds
                  capture-cpu-start
                  (my/perf--cpu-snapshot))))
           (stats (and log (my/perf--cpu-log-stats log)))
           (profile-name
            (when (and log my/perf-keep-cpu-profiles)
              (my/perf--cpu-file segment))))
      (when stats
        (my/perf--write-cpu-summary seq segment stats)
        (when profile-name
          (condition-case err
              (profiler-write-profile
               (profiler-make-profile
                :type 'cpu
                :timestamp capture-end
                :log log)
               profile-name)
            (error
             (setq profile-name
                   (format "ERROR: %s" (error-message-string err)))))))
      (my/perf--append-cpu-row
       (list
        seq
        my/perf--run-id
        segment
        (my/perf--iso-time start)
        (my/perf--iso-time snapshot-time)
        (my/perf--iso-time next-start)
        (if start
            (format "%.6f"
                    (float-time (time-subtract snapshot-time start)))
          "")
        (or (and stats (plist-get stats :total)) 0)
        (or (and stats (plist-get stats :recorded)) 0)
        (or (and stats (plist-get stats :discarded)) 0)
        (or (and stats (plist-get stats :gc)) 0)
        (or (and stats (plist-get stats :distinct)) 0)
        (if stats "cpu/summary.tsv" "")
        profile-name
        (format "%.3f" capture-wall-ms)
        (and capture-cpu-ms (format "%.3f" (* 1000.0 capture-cpu-ms)))))
      ;; `profiler-cpu-log' starts a fresh sampling log for the next segment.
      (setq my/perf--cpu-segment-start-time next-start))))

(defun my/perf--measure-collector (component function)
  "Run FUNCTION and record the observer's own cost under COMPONENT."
  (let* ((wall-start (current-time))
         (cpu-start (my/perf--cpu-snapshot))
         (status "ok")
         (details ""))
    (condition-case err
        (funcall function)
      (error
       (setq status "error"
             details (error-message-string err))))
    (let ((wall-ms (* 1000.0 (float-time
                              (time-subtract (current-time) wall-start))))
          (cpu-ms (let ((delta (my/perf--cpu-delta-seconds
                                cpu-start (my/perf--cpu-snapshot))))
                    (and delta (* 1000.0 delta)))))
      (my/perf--append-row
       "overhead.tsv"
       (list
        (cl-incf my/perf--seq)
        (my/perf--iso-time)
        component
        status
        (format "%.3f" wall-ms)
        (and cpu-ms (format "%.3f" cpu-ms))
        details)))))

(defun my/perf--timer-process ()
  (when my/perf--active
    (my/perf--measure-collector 'process-snapshot #'my/perf--snapshot-processes)
    (setq my/perf--process-timer
          (run-at-time my/perf-process-snapshot-interval-s
                       nil #'my/perf--timer-process))))

(defun my/perf--timer-allocation ()
  (when my/perf--active
    (my/perf--measure-collector 'allocation-snapshot #'my/perf--snapshot-allocation)
    (setq my/perf--allocation-timer
          (run-at-time my/perf-allocation-snapshot-interval-s
                       nil #'my/perf--timer-allocation))))

(defun my/perf--timer-system ()
  (when my/perf--active
    (my/perf--measure-collector 'system-snapshot #'my/perf--snapshot-system)
    (setq my/perf--system-timer
          (run-at-time my/perf-system-snapshot-interval-s
                       nil #'my/perf--timer-system))))

(defun my/perf--timer-cpu ()
  (when my/perf--active
    (my/perf--measure-collector 'cpu-rotation #'my/perf--capture-cpu-segment)
    (setq my/perf--cpu-timer
          (run-at-time my/perf-cpu-rotation-interval-s
                       nil #'my/perf--timer-cpu))))

(defun my/perf--timer-flush ()
  (when my/perf--active
    (my/perf--measure-collector 'flush #'my/perf--flush-all)
    (setq my/perf--flush-timer
          (run-at-time my/perf-flush-interval-s
                       nil #'my/perf--timer-flush))))

(defun my/perf--cancel-timers ()
  (dolist (timer (list my/perf--process-timer
                       my/perf--allocation-timer
                       my/perf--system-timer
                       my/perf--cpu-timer
                       my/perf--flush-timer))
    (when (timerp timer)
      (cancel-timer timer)))
  (setq my/perf--process-timer nil
        my/perf--allocation-timer nil
        my/perf--system-timer nil
        my/perf--cpu-timer nil
        my/perf--flush-timer nil))

(defun my/perf--restore-profiler-settings ()
  (when (numberp my/perf--saved-profiler-sampling-interval)
    (setq profiler-sampling-interval my/perf--saved-profiler-sampling-interval))
  (when (numberp my/perf--saved-profiler-log-size)
    (setq profiler-log-size my/perf--saved-profiler-log-size))
  (when (numberp my/perf--saved-profiler-max-stack-depth)
    (setq profiler-max-stack-depth my/perf--saved-profiler-max-stack-depth)))

(defun my/perf-stop ()
  "Stop telemetry for the current Emacs runtime and flush all data."
  (interactive)
  (when my/perf--active
    (my/perf--cancel-timers)
    (when my/perf--cpu-enabled
      (my/perf--measure-collector 'cpu-final #'my/perf--capture-cpu-segment)
      (when (and (fboundp 'profiler-cpu-stop)
                 (profiler-cpu-running-p))
        (profiler-cpu-stop)))
    (my/perf--collect-runtime 'end)
    (my/perf--flush-all)
    (my/perf--restore-profiler-settings)
    (setq my/perf--active nil
          my/perf--cpu-enabled nil)))

(defun my/perf-start ()
  "Start long-running package-agnostic telemetry."
  (interactive)
  (unless my/perf--active
    (condition-case err
        (progn
          (my/perf--ensure-directory)
          (my/perf--init-files)
          (setq my/perf--run-id (my/perf--run-id)
                my/perf--seq 0
                my/perf--cpu-segment-id 0
                my/perf--run-start-time (current-time)
                my/perf--run-start-cpu (my/perf--cpu-snapshot)
                my/perf--last-gcs-done gcs-done
                my/perf--last-gc-elapsed gc-elapsed
                my/perf--io-disabled nil)
          ;; Save the user's current profiler configuration before taking
          ;; ownership of the built-in CPU profiler.
          (setq my/perf--saved-profiler-sampling-interval profiler-sampling-interval
                my/perf--saved-profiler-log-size profiler-log-size
                my/perf--saved-profiler-max-stack-depth profiler-max-stack-depth)
          (setq my/perf--active t)
          (add-hook 'pre-command-hook #'my/perf--pre-command)
          (add-hook 'post-command-hook #'my/perf--post-command)
          (add-hook 'post-gc-hook #'my/perf--post-gc)
          (setq my/perf--cpu-enabled
                (and (fboundp 'profiler-cpu-start)
                     (fboundp 'profiler-cpu-running-p)
                     (not (profiler-cpu-running-p))))
          (when my/perf--cpu-enabled
            (setq profiler-sampling-interval my/perf-profiler-sampling-interval-ns
                  profiler-log-size my/perf-profiler-log-size
                  profiler-max-stack-depth my/perf-profiler-max-stack-depth)
            (profiler-cpu-start profiler-sampling-interval)
            (setq my/perf--cpu-segment-start-time (current-time)))
          (my/perf--collect-runtime 'start)
          ;; Delayed first snapshots avoid measuring the startup phase while
          ;; keeping all configuration changes package-independent.
          (setq my/perf--process-timer
                (run-at-time my/perf-process-snapshot-interval-s
                             nil #'my/perf--timer-process)
                my/perf--allocation-timer
                (run-at-time my/perf-allocation-snapshot-interval-s
                             nil #'my/perf--timer-allocation)
                my/perf--system-timer
                (run-at-time my/perf-system-snapshot-interval-s
                             nil #'my/perf--timer-system)
                my/perf--cpu-timer
                (run-at-time my/perf-cpu-rotation-interval-s
                             nil #'my/perf--timer-cpu)
                my/perf--flush-timer
                (run-at-time my/perf-flush-interval-s
                             nil #'my/perf--timer-flush)))
      (error
       (my/perf--cancel-timers)
       (remove-hook 'pre-command-hook #'my/perf--pre-command)
       (remove-hook 'post-command-hook #'my/perf--post-command)
       (remove-hook 'post-gc-hook #'my/perf--post-gc)
       (when (and (fboundp 'profiler-cpu-running-p)
                  (profiler-cpu-running-p))
         (profiler-cpu-stop))
       (my/perf--restore-profiler-settings)
       (setq my/perf--active nil
             my/perf--cpu-enabled nil)
       (message "perf-start: disabled after startup error: %s"
                (error-message-string err))))))

(defun my/perf--install ()
  "Start now if startup is already complete, otherwise after startup."
  (if (boundp 'after-init-time)
      (if after-init-time
          (my/perf-start)
        (add-hook 'emacs-startup-hook #'my/perf-start))
    (add-hook 'emacs-startup-hook #'my/perf-start)))

(add-hook 'kill-emacs-hook #'my/perf-stop)
(my/perf--install)

(provide 'perf-start)
;;; perf-start.el ends here

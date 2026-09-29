;;; perf-self-test.el --- Regression check for perf-start -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;; Run this after perf-start.el has been loaded by the normal Emacs
;; configuration.  It does not start or stop the profiler.

(require 'ert)

;; Variables et fonctions du collecteur (perf-start.el).  Le `defvar' rend
;; `my/perf-root' dynamique ici aussi : sans lui, le `let' du test ci-dessous
;; serait lexical et ne redirigerait aucune écriture.
(defvar my/perf-root)
(defvar my/perf--active)
(defvar my/perf--io-disabled)
(defvar my/perf--command-start-time)
(defvar my/perf--command-symbol)
(declare-function my/perf--flush-buffer "perf-start" (file buffer))
(declare-function my/perf--pre-command "perf-start" ())
(declare-function my/perf--post-command "perf-start" ())

(ert-deftest my/perf-flush-never-touches-current-user-buffer ()
  "Flushing telemetry must not read from or erase the current user buffer."
  (should (fboundp 'my/perf--flush-buffer))
  (let* ((root (make-temp-file "emacs-perf-test-" t))
         (my/perf-root root)
         (target (expand-file-name "system.tsv" root))
         (user (generate-new-buffer " *perf-test-user*"))
         (telemetry (generate-new-buffer " *perf-test-telemetry*")))
    (unwind-protect
        (progn
          (with-current-buffer telemetry
            (insert "telemetry-row\n"))
          (with-current-buffer user
            (insert "USER DATA — MUST SURVIVE\n")
            (let ((before (buffer-string))
                  (size-before (buffer-size)))
              (my/perf--flush-buffer target telemetry)
              (should (equal (buffer-string) before))
              (should (= (buffer-size) size-before))))
          (with-temp-buffer
            (insert-file-contents target)
            (should (equal (buffer-string) "telemetry-row\n"))))
      (when (buffer-live-p user)
        (kill-buffer user))
      (when (buffer-live-p telemetry)
        (kill-buffer telemetry))
      (delete-directory root t))))

(ert-deftest my/perf-hook-functions-are-top-level ()
  "Hook functions must be defined as soon as perf-start.el is loaded.
Regression: a misplaced parenthesis once nested them inside
`my/perf--post-command', so `post-gc-hook' signalled `void-function'
until the first interactive command, and each command redefined them."
  (dolist (fn '(my/perf--post-command
                my/perf--post-gc
                my/perf--snapshot-allocation
                my/perf--snapshot-system
                my/perf--system-descendants))
    (should (fboundp fn))))

(ert-deftest my/perf-post-command-resets-state ()
  "`my/perf--post-command' must clear the per-command state it consumed."
  (let ((my/perf--active t)
        (my/perf--io-disabled t)        ; aucune écriture sur disque
        (this-command 'ignore))
    (my/perf--pre-command)
    (should my/perf--command-start-time)
    (my/perf--post-command)
    (should-not my/perf--command-start-time)
    (should-not my/perf--command-symbol)))

(provide 'perf-self-test)
;;; perf-self-test.el ends here

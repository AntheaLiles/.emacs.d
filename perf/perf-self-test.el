;;; perf-self-test.el --- Regression check for perf-start -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;; Run this after perf-start.el has been loaded by the normal Emacs
;; configuration.  It does not start or stop the profiler.

(require 'ert)

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

(provide 'perf-self-test)
;;; perf-self-test.el ends here

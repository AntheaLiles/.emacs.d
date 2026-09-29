;;; my-performance.el --- Core performance -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Optimisations de performance : rendu, processus, compilation.

;;; Code:

;;;; UI & FEEDBACK
(setopt visible-bell t
        ring-bell-function 'ignore
        use-dialog-box nil
        use-short-answers t
        warning-minimum-level :warning
        echo-keystrokes 0.1)

;;;; RENDU
(setq fast-but-imprecise-scrolling t
      highlight-nonselected-windows nil
      cursor-in-non-selected-windows nil
      inhibit-compacting-font-caches t
      redisplay-skip-fontification-on-input t
      idle-update-delay 1.0)

;;;; BIDI
(setq bidi-paragraph-direction 'left-to-right
      bidi-inhibit-bpa t)

;;;; PROCESSUS EXTERNES
(setq read-process-output-max (* 4 1024 1024)
      process-adaptive-read-buffering nil)

;;;; COMPILATION
(setq byte-compile-warnings '(not obsolete))
(setopt compilation-scroll-output t)

;;;; VERSION CONTROL — limiter aux backends utilisés
(setopt vc-handled-backends '(Git))

(provide 'my-performance)
;;; my-performance.el ends here

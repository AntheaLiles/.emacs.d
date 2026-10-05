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
      redisplay-skip-fontification-on-input t)

;; `idle-update-delay' est obsolète depuis Emacs 30.1 ; il ne servait qu'à
;; which-func, dont c'est désormais la variable propre.
(with-eval-after-load 'which-func
  (setopt which-func-update-delay 1.0))

;;;; BIDI
(setq bidi-paragraph-direction 'left-to-right
      bidi-inhibit-bpa t)

;;;; PROCESSUS EXTERNES
;; (`process-adaptive-read-buffering' vaut nil par défaut depuis Emacs 31.)
(setq read-process-output-max (* 4 1024 1024))

;;;; COMPILATION
;; Avertissements d'obsolescence conservés : les masquer avait caché les API
;; retirées dans Emacs 31 (when-let, hs-looking-at-block-start-p…).
(setopt compilation-scroll-output t)
;; Lake (et d'autres outils) colorie sa sortie : sans filtre, les séquences
;; ANSI brutes empêchent la reconnaissance des erreurs (Emacs ne l'active pas
;; par défaut).
(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

;;;; VERSION CONTROL — limiter aux backends utilisés
(setopt vc-handled-backends '(Git))

(provide 'my-performance)
;;; my-performance.el ends here

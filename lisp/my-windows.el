;;; my-windows.el --- Windows and scrolling -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Configuration des fenêtres, du scrolling et du défilement souris.
;; Le window-divider de 16px fournit une séparation visuelle claire
;; entre les fenêtres, cohérente avec l'internal-border de 8px (early-init).

;;; Code:

;;;; FENÊTRES
(setopt window-combination-resize t
        help-window-select t)

;;;; WINDOW DIVIDER
(setopt window-divider-default-right-width 2
        window-divider-default-places 'right-only)
(window-divider-mode 1)

;;;; SCROLLING
(setopt scroll-conservatively 101
        scroll-margin 2
        scroll-preserve-screen-position t)

;;;; SOURIS
(setopt mouse-wheel-tilt-scroll t
        mouse-wheel-flip-direction nil)

;;;; PIXEL SCROLL
(when (fboundp 'pixel-scroll-precision-mode)
  (setopt pixel-scroll-precision-large-scroll-height 5.0
          pixel-scroll-precision-interpolation-factor 4.0)
  (pixel-scroll-precision-mode 1))

;;;; MWHEEL COALESCING
;; Les advices séparent les événements coalesced ('mwheel-scroll')
;; des non-coalesced ('pixel-scroll-precision').
;; Peut nécessiter une révision si Emacs 31 change l'API mwheel.
(defun my/filter-mwheel-always-coalesce (orig &rest args)
  "Ensure only coalesced scroll events reach ORIG."
  (if mwheel-coalesce-scroll-events
      (apply orig args)
    (setq mwheel-coalesce-scroll-events t)))

(defun my/filter-mwheel-never-coalesce (orig &rest args)
  "Ensure only non-coalesced scroll events reach ORIG."
  (if mwheel-coalesce-scroll-events
      (setq mwheel-coalesce-scroll-events nil)
    (apply orig args)))

(advice-add 'pixel-scroll-precision :around #'my/filter-mwheel-never-coalesce)
(advice-add 'mwheel-scroll          :around #'my/filter-mwheel-always-coalesce)
(advice-add 'mouse-wheel-text-scale :around #'my/filter-mwheel-always-coalesce)

(provide 'my-windows)
;;; my-windows.el ends here

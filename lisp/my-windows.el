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

;; (Les conseils qui basculaient `mwheel-coalesce-scroll-events' à chaque
;; événement de molette sont retirés : pixel-scroll-precision-mode gère seul
;; les événements précis et laisse les autres à mwheel.)

(provide 'my-windows)
;;; my-windows.el ends here

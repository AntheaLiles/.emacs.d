;;; my-appearance.el --- Visual appearance -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Fonte, curseur, numéros de ligne, headings Org, indicateurs visuels.
;; Numéros de ligne : relatifs en prog-mode, absolus en modes texte.

;;; Code:
;;;; CURSOR
(setopt cursor-type 'bar)

;;;; FONTS
(when (display-graphic-p)
  (let ((font "JetBrainsMonoNL Nerd Font Propo"))
    (if (member font (font-family-list))
        (set-face-attribute 'default nil :family font :height 120)
      (message "Font '%s' not found, using default" font))))

;;;; LINE NUMBERING
;; prog-mode : relatifs | org/markdown/tex : absolus | autres : aucun
(defun my/enable-relative-line-numbers ()
  "Enable relative line numbers for programming modes."
  (setq-local display-line-numbers 'relative))

(defun my/enable-absolute-line-numbers ()
  "Enable absolute line numbers for writing modes."
  (setq-local display-line-numbers t))

(add-hook 'prog-mode-hook #'my/enable-relative-line-numbers)
(dolist (hook '(org-mode-hook
               markdown-mode-hook
               latex-mode-hook))
  (add-hook hook #'my/enable-absolute-line-numbers))

;;;; SHOW-PAREN
;; Instant parentheses matching
(setopt show-paren-delay 0.0
        show-paren-style 'parenthesis
        show-paren-when-point-in-periphery t
        show-paren-when-point-inside-paren t)
(show-paren-mode 1)

;;;; HL-LINE
;; Surlignage de la ligne courante (global avec exclusions)
(global-hl-line-mode 1)
(dolist (hook '(pdf-view-mode-hook
               term-mode-hook
               vterm-mode-hook
               shell-mode-hook
               eshell-mode-hook))
  (add-hook hook (lambda () (hl-line-mode -1))))

;;;; PROG-MODE
;; Indicateur de colonne fill-column (colonne 80)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)
;; URLs cliquables dans le code
(add-hook 'prog-mode-hook #'goto-address-mode)
;; Troncature des lignes (pas de line-wrap dans le code)
(add-hook 'prog-mode-hook (lambda () (setq-local truncate-lines t)))

;;;; ORG — BULLETS ET HEADINGS
(with-eval-after-load 'org
  ;; Remplacer les tirets de liste par des bullets
  ;; Peut interférer avec org-indent-mode dans de rares cas.
  ;; Si glitches visuels sur les listes, désactiver ce bloc.
  (font-lock-add-keywords 'org-mode
                          '(("^ +\\([-*]\\)"
                             (0 (prog1 ()
                                  (compose-region (match-beginning 1)
                                                  (match-end 1) "•"))))))
  ;; Tailles proportionnelles pour les niveaux de titre
  (dolist (face-spec '((org-level-1 . 1.30)
                       (org-level-2 . 1.25)
                       (org-level-3 . 1.20)
                       (org-level-4 . 1.15)
                       (org-level-5 . 1.10)
                       (org-level-6 . 1.05)
                       (org-level-7 . 1.00)
                       (org-level-8 . 1.00)))
    (set-face-attribute (car face-spec) nil
                        :height (cdr face-spec))))

(provide 'my-appearance)
;;; my-appearance.el ends here

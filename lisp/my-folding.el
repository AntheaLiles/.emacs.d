;;; my-folding.el --- Org-like folding with Emacs 31 built-ins -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Repliement dans tous les modes, par les mécanismes natifs d'Emacs 31 :
;;
;;   TAB   sur un titre   → cycle replié / enfants / tout (outline, natif)
;;         ailleurs       → indente normalement
;;   S-TAB n'importe où   → cycle global aperçu / contenu / tout
;;   C-c z b              → plie / déplie le bloc de la ligne (hideshow)
;;   frange               → indicateurs cliquables des blocs (Emacs 31)
;;
;; Les blocs ne sont pas liés à TAB (`hs-cycle-filter' reste nil) : en Lisp,
;; presque chaque ligne ouvre un bloc, et TAB doit continuer d'indenter.
;; En Emacs Lisp, les formes de premier niveau sont des titres outline
;; (natif) : TAB sur « (defun … » les replie.
;;
;; Titres propres à ce module : LaTeX (\section… et commentaires %%%),
;; Markdown (#), et repli générique sur les commentaires répétés (### …)
;; pour les modes qui ne définissent pas leurs propres titres.  Blocs LaTeX :
;; environnements \begin…\end, par les variables hs-* locales au buffer
;; (`hs-special-modes-alist' est obsolète depuis Emacs 31).
;;
;; Org-mode est exclu : il a son propre cycling.

;;; Code:

(require 'outline)
(require 'hideshow)

;;;; RÉGLAGES GÉNÉRAUX

(defcustom my/folding-ellipsis " ⧾"
  "Ellipsis displayed for folded outline sections.
Aligné sur `org-ellipsis'."
  :type 'string
  :group 'my-folding)

(setopt outline-blank-line t                  ; ligne vide avant un titre = visible
        outline-minor-mode-highlight 'append  ; surligne les titres sans écraser le thème
        outline-minor-mode-cycle t            ; TAB / S-TAB sur les titres
        hs-hide-comments-when-hiding-all nil  ; hs-hide-all ne plie pas les commentaires
        hs-isearch-open t                     ; isearch ouvre les blocs pliés
        hs-show-indicators t                  ; Emacs 31 : indicateurs en frange
        hs-display-lines-hidden t)            ; Emacs 31 : nombre de lignes pliées

(defun my/folding-set-ellipsis ()
  "Use `my/folding-ellipsis' instead of the default `...' in this buffer."
  (let ((display-table (or buffer-display-table
                           (setq buffer-display-table (make-display-table)))))
    (set-display-table-slot
     display-table 'selective-display
     (vconcat (mapcar (lambda (c) (make-glyph-code c 'shadow))
                      my/folding-ellipsis)))))

;;;; TITRES PAR MODE

;;;;; LaTeX
;; Commandes de sectionnement et commentaires %%% (utilisés dans les
;; préambules de latex/).

(defconst my/latex-section-levels
  '(("part" . 1) ("chapter" . 2) ("section" . 3) ("subsection" . 4)
    ("subsubsection" . 5) ("paragraph" . 6) ("subparagraph" . 7))
  "Mapping between LaTeX sectioning commands and outline levels.")

(defun my/outline-setup-latex ()
  "Configure outline headers and hideshow blocks for LaTeX buffers."
  (setq-local outline-regexp
              (concat "%%%+[ \t]+\\|"
                      "[ \t]*\\\\\\("
                      (mapconcat #'car my/latex-section-levels "\\|")
                      "\\)\\*?{"))
  (setq-local outline-level
              (lambda ()
                (save-excursion
                  (cond
                   ;; %%% → niveau 3, %%%% → 4, etc.
                   ((looking-at "\\(%%%+\\)")
                    (length (match-string 1)))
                   ((looking-at "[ \t]*\\\\\\([a-z]+\\)\\*?{")
                    (or (cdr (assoc (match-string 1) my/latex-section-levels))
                        8))
                   (t 8)))))
  ;; Blocs : environnements.  Posées avant `hs-minor-mode', ces variables
  ;; locales priment sur la détection automatique de hideshow.
  (setq-local hs-block-start-regexp "\\\\begin{[^}]+}"
              hs-block-end-regexp "\\\\end{[^}]+}"
              hs-c-start-regexp "%"
              hs-forward-sexp-function #'my/folding-latex-forward-environment))

(defun my/folding-latex-forward-environment (&optional _arg)
  "Move point after the \\end matching the \\begin at point.
Nested environments are counted.  Signal `scan-error' when unbalanced."
  (let ((depth 0) done)
    (while (and (not done)
                (re-search-forward "\\\\\\(begin\\|end\\){[^}]+}" nil t))
      ;; Hors commentaire.  `syntax-ppss' déplace le point et peut écraser
      ;; les données de correspondance : on préserve les deux.
      (unless (nth 4 (save-excursion
                       (save-match-data (syntax-ppss (match-beginning 0)))))
        (setq depth (if (equal (match-string 1) "begin") (1+ depth) (1- depth)))
        (when (<= depth 0) (setq done t))))
    (unless done
      (signal 'scan-error (list "Unbalanced environment" (point) (point))))))

;;;;; Markdown
(defun my/outline-setup-markdown ()
  "Configure outline headers for Markdown buffers."
  (setq-local outline-regexp "#+[ \t]+")
  (setq-local outline-level
              (lambda () (- (match-end 0) (match-beginning 0) 1))))

;;;;; Repli générique : commentaires répétés (### , --- …)
(defun my/outline-setup-comment-based ()
  "Configure outline headers from repeated comment characters.
Only for modes that define no headers of their own."
  (when (and comment-start (not (string-empty-p comment-start))
             (not (local-variable-p 'outline-regexp))
             (not (bound-and-true-p outline-search-function)))
    (let ((c (regexp-quote (string-trim comment-start))))
      (setq-local outline-regexp (concat c c "+[ \t]+"))
      (setq-local outline-level
                  (lambda ()
                    (let ((len (- (match-end 0) (match-beginning 0))))
                      (max 1 (- len 1))))))))

(defconst my/folding-outline-setup-alist
  '((latex-mode        . my/outline-setup-latex)
    (LaTeX-mode        . my/outline-setup-latex)
    (tex-mode          . my/outline-setup-latex)
    (markdown-mode     . my/outline-setup-markdown)
    (markdown-ts-mode  . my/outline-setup-markdown))
  "Alist mapping major modes to their outline setup function.
Emacs Lisp needs none (built-in headers).  Other modes fall back to
`my/outline-setup-comment-based'.")

(defun my/folding--setup-outline ()
  "Apply the outline setup matching the current major mode."
  (let ((setup (seq-some (lambda (cell)
                           (and (derived-mode-p (car cell)) (cdr cell)))
                         my/folding-outline-setup-alist)))
    (unless (derived-mode-p 'emacs-lisp-mode 'lisp-data-mode)
      (funcall (or setup #'my/outline-setup-comment-based)))))

;;;; KEYMAP
(defvar-keymap my/folding-mode-map
  :doc "Keymap for `my/folding-mode'."
  "<backtab>" #'outline-cycle-buffer          ; S-TAB global, où que soit le point
  "C-c z o"   #'outline-show-entry
  "C-c z O"   #'outline-show-subtree
  "C-c z c"   #'outline-hide-entry
  "C-c z C"   #'outline-hide-subtree
  "C-c z m"   #'outline-hide-body
  "C-c z r"   #'outline-show-all
  "C-c z b"   #'hs-toggle-hiding
  "C-c z B"   #'hs-hide-all
  "C-c z n"   #'outline-next-visible-heading
  "C-c z p"   #'outline-previous-visible-heading
  "C-c z u"   #'outline-up-heading)

;;;; MINOR MODE D'ORCHESTRATION

;;;###autoload
(define-minor-mode my/folding-mode
  "Org-like folding: outline headings cycled with TAB, blocks with hideshow."
  :lighter " ⧾"
  :keymap my/folding-mode-map
  (if my/folding-mode
      (progn
        (my/folding--setup-outline)
        (my/folding-set-ellipsis)
        (outline-minor-mode 1)
        ;; hideshow échoue dans les modes sans support syntaxique : on tolère.
        (ignore-errors (hs-minor-mode 1)))
    (outline-minor-mode -1)
    (ignore-errors (hs-minor-mode -1))))

;;;###autoload
(defun my/setup-folding ()
  "Enable `my/folding-mode' unless the major mode folds natively."
  (unless (derived-mode-p 'org-mode 'outline-mode 'dired-mode 'pdf-view-mode)
    (my/folding-mode 1)))

;;;; ACTIVATION
(dolist (hook '(prog-mode-hook
                LaTeX-mode-hook
                markdown-ts-mode-hook
                conf-mode-hook))
  (add-hook hook #'my/setup-folding))

(provide 'my-folding)
;;; my-folding.el ends here

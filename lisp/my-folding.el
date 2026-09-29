;;; my-folding.el --- Unified Org-like folding across all modes -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Objectif : retrouver le comportement de TAB d'Org-mode dans tous les modes.
;;
;;   TAB   sur un titre  → cycle  replié / enfants / tout (outline-minor-mode)
;;         sur un bloc   → plie/déplie le bloc          (hs-minor-mode)
;;         ailleurs      → indente normalement
;;   S-TAB n'importe où  → cycle global overview / contents / show-all
;;
;; Deux mécanismes complémentaires, unifiés par `my/fold-tab-dwim' :
;;   - outline-minor-mode : titres, détectés par `outline-regexp' (motif textuel)
;;   - hs-minor-mode      : blocs, détectés par la syntaxe (parenthèses, begin/end)
;;
;; Org-mode est volontairement EXCLU : il dérive d'outline-mode et possède
;; déjà son propre cycling. Y activer outline-minor-mode casserait org-cycle.
;;
;; Chargé par init.el via (require 'my-folding).  Aucun paquet externe :
;; outline et hideshow sont intégrés à Emacs.  init.el ne déclare aucun
;; hook outline/hideshow de son côté, ce module en est la seule source.

;;; Code:

(require 'outline)
(require 'hideshow)

;;;; RÉGLAGES GÉNÉRAUX

(defcustom my/folding-ellipsis " ⧾"
  "Ellipsis displayed for folded outline sections.
Aligné sur `org-ellipsis' et `outline-indent-ellipsis'."
  :type 'string
  :group 'my-folding)

(setopt outline-blank-line t                  ; ligne vide avant un titre = visible
        outline-minor-mode-highlight 'append  ; surligne les titres sans écraser le thème
        outline-minor-mode-cycle t
        hs-hide-comments-when-hiding-all nil  ; hs-hide-all ne plie pas les commentaires
        hs-isearch-open t)                    ; isearch ouvre les blocs pliés

;; L'ellipsis d'outline passe par la display table du buffer, pas par une variable.
(defun my/folding-set-ellipsis ()
  "Use `my/folding-ellipsis' instead of the default `...' in this buffer."
  (let ((display-table (or buffer-display-table
                           (setq buffer-display-table (make-display-table)))))
    (set-display-table-slot
     display-table 'selective-display
     (vconcat (mapcar (lambda (c) (make-glyph-code c 'shadow))
                      my/folding-ellipsis)))))

;;;; OUTLINE-REGEXP PAR MODE
;; Chaque mode a besoin de savoir ce qu'est un « titre ». Le niveau est
;; déterminé par `outline-level', qui doit retourner un entier : plus il est
;; petit, plus le titre est haut dans la hiérarchie.

;;;;; Emacs Lisp
;; Calibré sur le style de votre init.el : ;;;; SECTION / ;;;;; sous-section.
;; Les formes de premier niveau ((defun ...), (use-package ...)) sont traitées
;; comme des feuilles, pliables par hideshow.

(defun my/outline-setup-elisp ()
  "Configure outline headers for Emacs Lisp buffers."
  (setq-local outline-regexp ";;;\\(;*\\)[ \t]+\\|(")
  (setq-local outline-level
              (lambda ()
                (if (looking-at ";;;\\(;*\\)[ \t]+")
                    ;; ";;; " → 1, ";;;; " → 2, ";;;;; " → 3 …
                    (1+ (- (match-end 1) (match-beginning 1)))
                    ;; une forme de premier niveau : feuille
                    1000))))

;;;;; LaTeX
;; Deux familles de titres : les commandes de sectionnement et vos
;; commentaires %%% (utilisés dans preamble-article.tex).

(defconst my/latex-section-levels
  '(("part" . 1) ("chapter" . 2) ("section" . 3) ("subsection" . 4)
    ("subsubsection" . 5) ("paragraph" . 6) ("subparagraph" . 7))
  "Mapping between LaTeX sectioning commands and outline levels.")

(defun my/outline-setup-latex ()
  "Configure outline headers for LaTeX buffers."
  (setq-local outline-regexp
              (concat "%%%+[ \t]+\\|"
                      "[ \t]*\\\\\\("
                      (mapconcat #'car my/latex-section-levels "\\|")
                      "\\)\\*?{"))
  (setq-local outline-level
              (lambda ()
                (save-excursion
                  (looking-at outline-regexp)
                  (cond
                   ;; %%% → niveau 3, %%%% → 4, etc.
                   ((looking-at "\\(%%%+\\)")
                    (length (match-string 1)))
                   ((looking-at "[ \t]*\\\\\\([a-z]+\\)\\*?{")
                    (or (cdr (assoc (match-string 1) my/latex-section-levels))
                        8))
                   (t 8))))))

;;;;; Markdown
;; markdown-ts-mode (Emacs 31) gère déjà TAB nativement, mais on aligne
;; outline dessus pour que S-TAB et les commandes C-c z fonctionnent aussi.

(defun my/outline-setup-markdown ()
  "Configure outline headers for Markdown buffers."
  (setq-local outline-regexp "#+[ \t]+")
  (setq-local outline-level
              (lambda () (- (match-end 0) (match-beginning 0) 1))))

;;;;; Modes à commentaires (shell, EBNF, Lean, config…)
;; Repli générique : une ligne de commentaire répété (### , --- , %%% …)
;; est traitée comme un titre, son niveau donné par le nombre de caractères.

(defun my/outline-setup-comment-based ()
  "Configure outline headers from repeated comment characters.
Works in any mode defining `comment-start'."
  (when (and comment-start (not (string-empty-p comment-start)))
    (let ((c (regexp-quote (string-trim comment-start))))
      (setq-local outline-regexp (concat c c "+[ \t]+"))
      (setq-local outline-level
                  (lambda ()
                    (let ((len (- (match-end 0) (match-beginning 0))))
                      (max 1 (- len 1))))))))

;;;; HIDESHOW : SUPPORT DES MODES NON NATIFS
;; hideshow connaît nativement C, Lisp, Python, JS… mais pas LaTeX.
;; Format : (MODE START END COMMENT-START FORWARD-SEXP-FUNC ADJUST-BEG-FUNC)

(defconst my/hs-latex-spec
  '("\\\\begin{[^}]+}" "\\\\end{[^}]+}" "%" nil nil)
  "Hideshow specification for LaTeX environments.")

(with-eval-after-load 'hideshow
  (dolist (mode '(latex-mode LaTeX-mode tex-mode TeX-mode))
    (add-to-list 'hs-special-modes-alist (cons mode my/hs-latex-spec)))
  ;; EBNF : blocs délimités par parenthèses de groupe
  (add-to-list 'hs-special-modes-alist
               '(ebnf-mode "(" ")" "(\\*" nil nil)))

;;;; TAB INTELLIGENT
(defun my/folding--block-on-line-p ()
  "Return non-nil if a hideable block starts on the current line.
Relies on `hs-get-first-block-on-line' (Emacs 31), which replaces the
removed `hs-looking-at-block-start-p'.  With the default
`hs-hide-block-behavior' (`after-bol'), `hs-toggle-hiding' then acts on
that block wherever point is on the line."
  (and (fboundp 'hs-get-first-block-on-line)
       (save-excursion
         (forward-line 0)
         (ignore-errors (hs-get-first-block-on-line)))))

(defun my/fold-tab-dwim (&optional arg)
  "Cycle folding at point, or indent.
On an outline heading, cycle its visibility.
At the start of a foldable block, toggle it.
Anywhere else, fall back to `indent-for-tab-command'.
With prefix ARG, always indent."
  (interactive "P")
  (cond
   (arg (indent-for-tab-command arg))
   ;; 1. Sur un titre outline → cycling à la Org
   ((and (bound-and-true-p outline-minor-mode)
         (outline-on-heading-p))
         (outline-cycle))
   ;; 2. Sur une ligne qui ouvre un bloc hideshow → plier / déplier
   ((and (bound-and-true-p hs-minor-mode)
         (or (hs-already-hidden-p)
             (my/folding--block-on-line-p)))
    (hs-toggle-hiding))
   ;; 3. Ailleurs → indentation normale
   (t (indent-for-tab-command))))

(defun my/fold-global-cycle ()
  "Cycle global visibility: overview / contents / show-all."
  (interactive)
  (outline-cycle-buffer))

;;;; KEYMAP
;; Un keymap dédié, appliqué par le minor mode ci-dessous. Cela évite
;; d'écraser les bindings des major modes et garde un point de contrôle unique.

(defvar-keymap my/folding-mode-map
  :doc "Keymap for `my/folding-mode'."
  "TAB"       #'my/fold-tab-dwim
  "<tab>"     #'my/fold-tab-dwim
  "<backtab>" #'my/fold-global-cycle
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

(defconst my/folding-outline-setup-alist
  '((emacs-lisp-mode      . my/outline-setup-elisp)
    (lisp-interaction-mode . my/outline-setup-elisp)
    (lisp-mode            . my/outline-setup-elisp)
    (latex-mode           . my/outline-setup-latex)
    (LaTeX-mode           . my/outline-setup-latex)
    (tex-mode             . my/outline-setup-latex)
    (markdown-mode        . my/outline-setup-markdown)
    (markdown-ts-mode     . my/outline-setup-markdown))
  "Alist mapping major modes to their outline setup function.
Modes absent from this list fall back to `my/outline-setup-comment-based'.")

(defun my/folding--setup-outline-regexp ()
  "Apply the outline setup matching the current major mode."
  (let ((setup (seq-some (lambda (cell)
                           (and (derived-mode-p (car cell)) (cdr cell)))
                         my/folding-outline-setup-alist)))
    (funcall (or setup #'my/outline-setup-comment-based))))

;;;###autoload
(define-minor-mode my/folding-mode
  "Org-like folding: outline sections and code blocks cycled with TAB."
  :lighter " ⧾"
  :keymap my/folding-mode-map
  (if my/folding-mode
      (progn
        (my/folding--setup-outline-regexp)
        (my/folding-set-ellipsis)
        (outline-minor-mode 1)
        ;; hideshow échoue dans les modes sans support syntaxique : on tolère.
        (ignore-errors (hs-minor-mode 1)))
    (outline-minor-mode -1)
    (ignore-errors (hs-minor-mode -1))))

;;;###autoload
(defun my/setup-folding ()
  "Enable `my/folding-mode' unless the major mode folds natively.
Org-mode is excluded: it derives from `outline-mode' and has its own cycling."
  (unless (derived-mode-p 'org-mode 'outline-mode 'dired-mode 'pdf-view-mode)
    (my/folding-mode 1)))

;;;; ACTIVATION

;;;###autoload
(defun my/folding-install-hooks ()
  "Install `my/setup-folding' on the relevant major mode hooks."
  (dolist (hook '(prog-mode-hook
                  LaTeX-mode-hook
                  markdown-ts-mode-hook
                  conf-mode-hook))
    (add-hook hook #'my/setup-folding)))

(my/folding-install-hooks)

(provide 'my-folding)
;;; my-folding.el ends here

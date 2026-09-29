;;; my-export-config-test.el --- Tests for the shared export config -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Vérifie l'export du code en ligne (section CODE EN LIGNE de
;; lisp/my-export-config.el).  Aucun paquet externe requis : sans
;; engrave-faces, les blocs en ligne passent par le repli verbatim, que le
;; filtre traite de la même façon.
;;
;; Usage, depuis la racine du dépôt :
;;   emacs -Q --batch -L lisp -l tests/my-export-config-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'ox-latex)

;; Pas d'écriture dans ~/.emacs.d réel, pas de nvm ni de wiki requis.
(let ((user-emacs-directory
       (file-name-as-directory
        (expand-file-name ".." (file-name-directory
                                (or load-file-name buffer-file-name))))))
  (require 'my-paths)
  (require 'my-export-config))

(defun my/test--latex-body (org)
  "Export ORG, a string, to a LaTeX body."
  (let ((org-export-with-toc nil))
    (org-export-string-as org 'latex t)))

(ert-deftest my/export-inline-code-markup ()
  "~code~ is wrapped in \\CodeInline, with explicit spaces."
  (let ((out (my/test--latex-body "Voir ~a b~ ici.")))
    (should (string-match-p (regexp-quote "\\CodeInline{a\\ b} ici") out))
    (should-not (string-match-p "texttt" out))))

(ert-deftest my/export-inline-code-escapes ()
  "Special TeX characters stay escaped inside \\CodeInline."
  (let ((out (my/test--latex-body "~50% & x_1~")))
    (should (string-match-p (regexp-quote "\\CodeInline{50\\%\\ \\&\\ x\\_1}")
                            out))))

(ert-deftest my/export-inline-code-in-title ()
  "Titles, exported through an anonymous backend, are covered too."
  (let ((out (my/test--latex-body "* Titre ~f~\nTexte.")))
    (should (string-match-p (regexp-quote "\\section{Titre \\CodeInline{f}}")
                            out))))

(ert-deftest my/export-inline-code-nested-anonymous-backend ()
  "The filter accepts anonymous backends whose parent is a structure.
Regression: Org 9.7 exports titles through such a backend, on which
`org-export-derived-backend-p' signals `wrong-type-argument'."
  (let* ((section (org-export-create-backend :parent 'latex))
         (nested (org-export-create-backend :parent section))
         (html (org-export-create-backend :parent 'html)))
    (should (my/org-export--latex-backend-p nested))
    (should (my/org-export--latex-backend-p 'latex))
    (should-not (my/org-export--latex-backend-p html))
    (should-not (my/org-export--latex-backend-p nil))
    (should (equal (my/org-latex-inline-code "\\texttt{f} " nil
                                             (list :back-end nested))
                   "\\CodeInline{f} "))
    (should (equal (my/org-latex-inline-code "\\texttt{f}" nil
                                             (list :back-end html))
                   "\\texttt{f}"))))

(ert-deftest my/export-verbatim-untouched ()
  "=verbatim= keeps the plain monospace rendering."
  (let ((out (my/test--latex-body "=v=")))
    (should (string-match-p (regexp-quote "\\texttt{v}") out))
    (should-not (string-match-p "CodeInline" out))))

(ert-deftest my/export-inline-src-shows-code ()
  "Inline source blocks export their code and are not evaluated."
  (let* ((org-confirm-babel-evaluate nil)
         (out (my/test--latex-body "Calcul src_emacs-lisp{(+ 1 2)} fin.")))
    (should (string-match-p "CodeInline" out))
    (should (string-match-p (regexp-quote "(+") out))
    (should-not (string-match-p "{3}" out))))

(ert-deftest my/export-inline-src-results-on-request ()
  "An explicit :exports results still evaluates the block."
  (let* ((org-confirm-babel-evaluate nil)
         (out (my/test--latex-body
               "Calcul src_emacs-lisp[:exports results]{(+ 1 2)} fin.")))
    (should (string-match-p "3" out))
    (should-not (string-match-p (regexp-quote "(+") out))))

(provide 'my-export-config-test)
;;; my-export-config-test.el ends here

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

(ert-deftest my/export-drawio-links-rewritten ()
  "Converted .drawio links point to the PDF and keep their form.
Regression: the file: prefix was dropped, turning [[file:x.drawio]]
into [[x.pdf]], which Org reads as an internal link."
  (let* ((dir (file-name-as-directory (make-temp-file "drawio-test-" t)))
         (bin (expand-file-name "bin/" dir))
         (stub (expand-file-name "drawio" bin))
         (default-directory dir)
         (exec-path (cons bin exec-path))
         (process-environment
          (cons (concat "PATH=" bin path-separator (getenv "PATH"))
                process-environment)))
    (unwind-protect
        (progn
          (make-directory bin)
          ;; Simulacre : drawio -x -f pdf --crop -o SORTIE ENTRÉE
          (with-temp-file stub
            (insert "#!/bin/sh\nwhile [ $# -gt 0 ]; do [ \"$1\" = -o ] && out=$2; shift; done\n"
                    "echo pdf > \"$out\"\n"))
          (set-file-modes stub #o755)
          (dolist (f '("a.drawio" "b.drawio"))
            (with-temp-file (expand-file-name f dir) (insert "<mxfile/>")))
          (with-temp-buffer
            (insert "[[file:a.drawio]]\n[[./b.drawio]]\n")
            (my/org-convert-drawio 'latex)
            (should (equal (buffer-string) "[[file:a.pdf]]\n[[./b.pdf]]\n")))
          (should (file-exists-p (expand-file-name "a.pdf" dir)))
          (should (file-exists-p (expand-file-name "b.pdf" dir))))
      (delete-directory dir t))))

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

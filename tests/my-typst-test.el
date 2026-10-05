;;; my-typst-test.el --- Tests for the Typst export backend -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Tests de lisp/my-export-typst.el (backend `my-typst', C-c C-e T).  Ils
;; requièrent `ox-typst' (paquet tiers, Org 9.7 ou plus) : sans lui, ils sont
;; ignorés, comme ceux de citeproc.  La compilation par le binaire `typst' est
;; couverte par le banc de bout en bout (tests/regression/run.sh).
;;
;; Usage, depuis la racine du dépôt, avec ox-typst dans le load-path :
;;   emacs -Q --batch -L lisp -L /chemin/ox-typst -l tests/my-typst-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'ox)

(defconst my/test--root
  (file-name-as-directory
   (expand-file-name ".." (file-name-directory
                           (or load-file-name buffer-file-name))))
  "Root of the repository.")

(let ((user-emacs-directory my/test--root))
  (require 'my-paths)
  (require 'my-export-config)
  (require 'ox-typst nil t)
  (require 'my-export-typst))

(defmacro my/test--needs-typst (&rest body)
  "Run BODY, or skip the test when ox-typst is not installed."
  (declare (indent 0))
  `(progn (skip-unless (featurep 'ox-typst)) ,@body))

(defun my/test--typst (org &optional backend)
  "Export the Org string ORG with BACKEND (default `my-typst'), as a string."
  (setq org-typst--file-paths nil)
  (let ((org-export-with-toc nil))
    (org-export-string-as org (or backend 'my-typst))))

(defun my/test--bib-dir ()
  "Return a temporary directory with refs.bib and a sibling refs.json."
  (let ((dir (file-name-as-directory (make-temp-file "typst-test-" t))))
    (with-temp-file (expand-file-name "refs.bib" dir)
      (insert "@book{a, title={A}, author={Martin, A.}, year={2019}}\n"))
    (with-temp-file (expand-file-name "refs.json" dir) (insert "[]"))
    dir))

;;;; Menu et backend

(ert-deftest my/typst-menu-key ()
  "C-c C-e T opens the Typst menu, once; ox-typst's own entry (y) is hidden."
  (my/test--needs-typst
    (let ((entry (org-export-backend-menu (org-export-get-backend 'my-typst))))
      (should (eq (car entry) ?T))
      (should (equal (mapcar #'car (nth 2 entry)) '(?F ?f ?p ?o ?d))))
    (should-not (org-export-backend-menu (org-export-get-backend 'typst)))
    (should (= 1 (cl-count ?T (delq nil (mapcar #'org-export-backend-menu
                                                 org-export-registered-backends))
                           :key #'car)))
    (should (org-export-derived-backend-p 'my-typst 'typst))))

(ert-deftest my/typst-defaults ()
  "French by default (#+LANGUAGE overrides) and the repository's page setup."
  (my/test--needs-typst
    (let ((out (my/test--typst "Texte.")))
      (should (string-match-p "#set text(lang: \"fr\")" out))
      (should (string-match-p "#set page(paper: \"a4\"" out))
      (should (string-match-p "#show raw.where(block: false)" out))
      (should (string-match-p "#set heading(numbering: \"1.1\")" out)))
    (should (string-match-p "#set text(lang: \"en\")"
                            (my/test--typst "#+LANGUAGE: en\nText.")))))

(ert-deftest my/typst-process ()
  "PDF/UA-1 is requested by default and dropped for drafts or when disabled."
  (my/test--needs-typst
    (should (equal (my/typst--process) "typst compile --pdf-standard ua-1 \"%s\""))
    (should (equal (my/typst--process t) "typst compile --no-pdf-tags \"%s\""))
    (let ((my/typst-pdf-standard nil))
      (should (equal (my/typst--process) "typst compile \"%s\"")))))

;;;; Titre, résumé, mots-clés

(ert-deftest my/typst-title-block ()
  "Title, subtitle, authors and date form a title block; no title, no block."
  (my/test--needs-typst
    (let ((out (my/test--typst
                "#+TITLE: Mon titre\n#+SUBTITLE: Sous-titre\n#+AUTHOR: A, B\n#+DATE: 2026-10-05\nTexte.")))
      (should (string-match-p "#title\\[Mon titre\\]" out))
      (should (string-match-p "text(size: 1.2em)\\[Sous\\\\u{2d}titre\\]" out))
      (should (string-match-p "A, B" out))
      (should (string-match-p "#set document(title: \"Mon titre\", .*author: \"A, B\"" out)))
    (should-not (string-match-p "#title" (my/test--typst "Texte.")))))

(ert-deftest my/typst-abstract-and-keywords ()
  "Abstract and keyword blocks carry their heading word, in the language."
  (my/test--needs-typst
    (let ((out (my/test--typst
                "#+begin_abstract\nRésumé.\n#+end_abstract\n#+begin_keyword\na, b\n#+end_keyword\n")))
      (should (string-match-p "#strong\\[Résumé\\]" out))
      (should (string-match-p "#strong\\[Mots-clés\\.\\] a, b" out)))
    (let ((out (my/test--typst
                "#+LANGUAGE: en\n#+begin_abstract\nText.\n#+end_abstract\n")))
      (should (string-match-p "#strong\\[Abstract\\]" out)))))

;;;; ORCID, texte alternatif

(ert-deftest my/typst-orcid ()
  "\\orcidlink and \\orcidlinkunauth become Typst calls, with their icons."
  (my/test--needs-typst
    (let ((out (my/test--typst
                (concat "#+TITLE: T\n#+AUTHOR: A\\orcidlink{0000-0002-1825-0097}, "
                        "B\\orcidlinkunauth{0000-0001-5109-3700}\nTexte.\n"))))
      (should (string-match-p "#orcid-link(false, \"0000-0002-1825-0097\")" out))
      (should (string-match-p "#orcid-link(true, \"0000-0001-5109-3700\")" out))
      (should (= 1 (cl-count-if (lambda (l) (string-prefix-p "#let orcid-link" l))
                                (split-string out "\n"))))
      (should (assoc "orcid-icon" org-typst--file-paths))
      (should (assoc "orcid-icon-unauth" org-typst--file-paths))
      (dolist (entry (list (cadr (assoc "orcid-icon" org-typst--file-paths))
                           (cadr (assoc "orcid-icon-unauth" org-typst--file-paths))))
        (should (file-exists-p entry))))
    ;; Sans ORCID : ni définition ni icône
    (let ((out (my/test--typst "#+TITLE: T\n#+AUTHOR: A\nTexte.\n")))
      (should-not (string-match-p "orcid" out))
      (should-not (assoc "orcid-icon" org-typst--file-paths)))))

(ert-deftest my/typst-orcid-in-source-block-untouched ()
  "ORCID macros inside a source block stay literal."
  (my/test--needs-typst
    (should (string-match-p "orcidlink"
                            (my/test--typst
                             "#+begin_src latex\n\\orcidlink{0000-0002-1825-0097}\n#+end_src\n")))))

(ert-deftest my/typst-alt-text ()
  "#+ALT_TEXT: gives the image that follows its alternative text."
  (my/test--needs-typst
    (let* ((dir (file-name-as-directory (make-temp-file "typst-img-" t)))
           (default-directory dir))
      (with-temp-file (expand-file-name "i.svg" dir)
        (insert "<svg xmlns=\"http://www.w3.org/2000/svg\"/>"))
      (let ((out (my/test--typst "#+ALT_TEXT: Un schéma\n#+CAPTION: Légende\n[[file:i.svg]]\n")))
        (should (string-match-p "#image(sys\\.inputs\\.file-[0-9]+, alt: \"Un schéma\")" out))
        (should-not (string-match-p "ALT_TEXT" out)))
      ;; Sans texte alternatif : aucun alt (Typst le refusera en PDF/UA-1)
      (should-not (string-match-p "alt:" (my/test--typst "[[file:i.svg]]\n"))))))

;;;; Bibliographie

(ert-deftest my/typst-bibliography-files ()
  "Typst reads the .bib: a CSL-JSON file stands for its sibling .bib."
  (my/test--needs-typst
    (let* ((dir (my/test--bib-dir))
           (bib (expand-file-name "refs.bib" dir))
           (json (expand-file-name "refs.json" dir)))
      (should (equal (my/typst--bibliography-files (list json)) (list bib)))
      (should (equal (my/typst--bibliography-files (list bib json)) (list bib)))
      ;; Ni .bib voisin ni my/bibtex-files : erreur claire
      (let ((my/bibtex-files nil)
            (lonely (expand-file-name "seul.json" dir)))
        (with-temp-file lonely (insert "[]"))
        (should-error (my/typst--bibliography-files (list lonely)) :type 'user-error)))))

(ert-deftest my/typst-bibliography-export ()
  "Citations use the .bib and the CSL style; the title follows biblatex's words."
  (my/test--needs-typst
    (let* ((dir (my/test--bib-dir))
           (org-cite-global-bibliography (list (expand-file-name "refs.json" dir)))
           (out (my/test--typst "Voir [cite:@a].\n\n#+print_bibliography:\n")))
      (should (string-match-p "#cite(label(\"a\"))" out))
      (should (string-match-p
               "#bibliography(sys\\.inputs\\.file-[0-9]+, title: \\[Références\\], style: sys\\.inputs\\.file-[0-9]+)"
               out))
      ;; Le style CSL et le .bib sont passés à Typst comme fichiers
      (should (cl-find my/csl-style-file org-typst--file-paths
                       :key #'cadr :test #'equal))
      (should (cl-find-if (lambda (e) (string-suffix-p "refs.bib" (cadr e)))
                          org-typst--file-paths))
      ;; Options du mot-clé
      (should (string-match-p "title: none"
                              (my/test--typst "[cite:@a]\n#+print_bibliography: :heading none\n")))
      (should (string-match-p "title: \\[Sources\\]"
                              (my/test--typst "[cite:@a]\n#+print_bibliography: :title Sources\n")))
      (should (string-match-p "set heading(level: 2)"
                              (my/test--typst "[cite:@a]\n#+print_bibliography: :heading subbibliography\n"))))))

(ert-deftest my/typst-citation-styles ()
  "Org's /t, /a… shorthands are understood by the Typst processor."
  (my/test--needs-typst
    (let ((org-cite-global-bibliography (list (expand-file-name "refs.bib" (my/test--bib-dir)))))
      (should (string-match-p "form: \"prose\"" (my/test--typst "[cite/t:@a]")))
      (should (string-match-p "form: \"author\"" (my/test--typst "[cite/a:@a]")))
      (should (string-match-p "form: \"year\"" (my/test--typst "[cite/na:@a]")))
      (should-not (string-match-p "form:" (my/test--typst "[cite:@a]"))))))

(ert-deftest my/typst-citations-processor ()
  "Typst citations go through `my-typst', with the repository's CSL style."
  (my/test--needs-typst
    (should (equal (cdr (assq 'typst org-cite-export-processors))
                   (list 'my-typst my/csl-style-file)))
    ;; Le processeur CSL des autres backends n'est pas remplacé
    (should (eq (cadr (assq t org-cite-export-processors))
                (if my/csl-available-p 'csl 'basic)))))

(ert-deftest my/typst-skips-csl-json-check ()
  "The CSL-JSON guard does not apply to Typst, which reads the .bib."
  (my/test--needs-typst
    (let ((my/csl-available-p t)
          (org-cite-global-bibliography
           (list (let ((f (make-temp-file "vide-" nil ".json"))) f))))
      (with-temp-buffer
        (org-mode)
        (insert "Voir [cite:@a].\n")
        (should-error (my/csl-check-bibliographies 'latex) :type 'user-error)
        (should-not (my/csl-check-bibliographies 'my-typst))))))

;;;; Diagrammes drawio

(ert-deftest my/typst-drawio-format ()
  "drawio diagrams become SVG for Typst, PDF everywhere else."
  (should (equal (my/org-drawio-format 'latex) "pdf"))
  (should (equal (my/org-drawio-format 'pdfua) "pdf"))
  (should (equal (my/org-drawio-format nil) "pdf"))
  (my/test--needs-typst
    (should (equal (my/org-drawio-format 'my-typst) "svg"))
    (should (equal (my/org-drawio-format 'typst) "svg"))))

(provide 'my-typst-test)
;;; my-typst-test.el ends here

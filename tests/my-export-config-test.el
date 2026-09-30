;;; my-export-config-test.el --- Tests for the shared export config -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Tests du backend d'export `pdfua' (lisp/my-export-config.el) et de
;; l'affichage de fin d'export (lisp/my-export-ui.el).  Aucun paquet
;; externe requis : sans engrave-faces, les blocs en ligne passent par le
;; repli verbatim ; sans citeproc, les bibliographies par section sont
;; vérifiées au niveau du filtre de pré-analyse.
;;
;; Usage, depuis la racine du dépôt :
;;   emacs -Q --batch -L lisp -l tests/my-export-config-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'ox-latex)

;; Pas d'écriture dans ~/.emacs.d réel, pas de nvm ni de wiki requis.
(defconst my/test--root
  (file-name-as-directory
   (expand-file-name ".." (file-name-directory
                           (or load-file-name buffer-file-name))))
  "Root of the repository.")

(let ((user-emacs-directory my/test--root))
  (require 'my-paths)
  (require 'my-export-config)
  (require 'my-export-ui))

(defun my/test--body (org &optional backend)
  "Export ORG, a string, to a LaTeX body with BACKEND (default `pdfua')."
  (let ((org-export-with-toc nil))
    (org-export-string-as org (or backend 'pdfua) t)))

;;;; Backend et classes

(ert-deftest my/export-classes-article-ua-book-ua ()
  "Both PDF/UA classes exist, and Org's own article class is untouched."
  (dolist (variant '("article" "book"))
    (let* ((class (assoc (concat variant "-ua") org-latex-classes))
           (preamble (expand-file-name (format "latex/preamble-%s-ua.tex" variant)
                                       my/test--root)))
      (should class)
      (should (string-match-p (regexp-quote preamble) (nth 1 class)))
      (should (string-match-p "pdfstandard=ua-2" (nth 1 class)))
      (should (file-exists-p preamble))))
  (should-not (string-match-p "preamble" (nth 1 (assoc "article" org-latex-classes)))))

(ert-deftest my/export-default-class-is-article-ua ()
  "A PDF/UA export without #+LATEX_CLASS uses article-ua."
  (let ((out (org-export-string-as "Texte." 'pdfua)))
    (should (string-match-p "preamble-article-ua\\.tex" out)))
  (let ((out (org-export-string-as "#+LATEX_CLASS: book-ua\nTexte." 'pdfua)))
    (should (string-match-p "preamble-book-ua\\.tex" out))))

(ert-deftest my/export-standard-latex-with-ua-class ()
  "C-c C-e l on a document declaring a PDF/UA class runs the PDF/UA chain.
Regression: only the `pdfua' backend (C-c C-e u) applied it, so the usual
C-c C-e l export lost margin notes, bibliography layout and inline code."
  (let ((out (org-export-string-as
              "#+LATEX_CLASS: article-ua\nVoir ~a b~ et [rmq:note]." 'latex))
        (case-fold-search nil))
    (should (string-match-p "preamble-article-ua\\.tex" out))
    (should (string-match-p (regexp-quote "\\CodeInline{a\\ b}") out))
    (should (string-match-p (regexp-quote "\\RMQ{note}") out))
    (should (string-match-p (regexp-quote "\\def\\uacodeinline{}") out))))

(ert-deftest my/export-pdfua-active-p ()
  "The chain applies to pdfua, and to latex with a PDF/UA class only."
  (should (my/pdfua-active-p 'pdfua '(:latex-class "article-ua")))
  (should (my/pdfua-active-p 'latex '(:latex-class "book-ua")))
  (should-not (my/pdfua-active-p 'latex '(:latex-class "article")))
  (should-not (my/pdfua-active-p 'html '(:latex-class "article-ua")))
  (should-not (my/pdfua-active-p nil '(:latex-class "article-ua")))
  (with-temp-buffer
    (org-mode)
    (insert "#+LATEX_CLASS: book-ua\nTexte.\n")
    (should (my/pdfua-active-p 'latex))
    (erase-buffer)
    (insert "Texte.\n")
    (should-not (my/pdfua-active-p 'latex))
    (should (my/pdfua-active-p 'pdfua))))

(ert-deftest my/export-standard-latex-untouched ()
  "The standard LaTeX backend keeps Org's rendering: no PDF/UA filter."
  (let ((out (my/test--body "Voir ~a b~ et [rmq:note]." 'latex))
        (case-fold-search nil))
    (should (string-match-p (regexp-quote "\\texttt{a b}") out))
    (should-not (string-match-p "CodeInline\\|RMQ" out))))

(ert-deftest my/export-pdf-process-safe ()
  "latexmk runs without -shell-escape, with -f, and the repository latexmkrc.
Regression: without -f, one LaTeX error stopped latexmk after the first
pass, leaving every cross-reference and the page total as ??."
  (let ((cmd (car org-latex-pdf-process)))
    (should-not (string-match-p "shell-escape" cmd))
    (should (string-match-p " -f " cmd))
    (should (string-match-p (regexp-quote my/latexmkrc-file) cmd))))

;;;; Code en ligne

(ert-deftest my/export-inline-code-markup ()
  "~code~ is wrapped in \\CodeInline, with explicit spaces."
  (let ((out (my/test--body "Voir ~a b~ ici.")))
    (should (string-match-p (regexp-quote "\\CodeInline{a\\ b} ici") out))
    (should-not (string-match-p "texttt" out))))

(ert-deftest my/export-inline-code-escapes ()
  "Special TeX characters stay escaped inside \\CodeInline."
  (let ((out (my/test--body "~50% & x_1~")))
    (should (string-match-p (regexp-quote "\\CodeInline{50\\%\\ \\&\\ x\\_1}")
                            out))))

(ert-deftest my/export-inline-code-in-title ()
  "Titles, exported through an anonymous backend, are covered too.
Regression: since Org 9.7 that backend's parent is itself a structure."
  (let ((out (my/test--body "* Titre ~f~\nTexte.")))
    (should (string-match-p (regexp-quote "\\section{Titre \\CodeInline{f}}")
                            out))))

(ert-deftest my/export-verbatim-untouched ()
  "=verbatim= keeps the plain monospace rendering."
  (let ((out (my/test--body "=v=")))
    (should (string-match-p (regexp-quote "\\texttt{v}") out))
    (should-not (string-match-p "CodeInline" out))))

(ert-deftest my/export-inline-src-shows-code ()
  "Inline source blocks export their code and are not evaluated."
  (let* ((org-confirm-babel-evaluate nil)
         (out (my/test--body "Calcul src_emacs-lisp{(+ 1 2)} fin.")))
    (should (string-match-p "CodeInline" out))
    (should (string-match-p (regexp-quote "(+") out))
    (should-not (string-match-p "{3}" out))))

(ert-deftest my/export-inline-src-results-on-request ()
  "An explicit :exports results still evaluates the block."
  (let* ((org-confirm-babel-evaluate nil)
         (out (my/test--body
               "Calcul src_emacs-lisp[:exports results]{(+ 1 2)} fin.")))
    (should (string-match-p "3" out))
    (should-not (string-match-p (regexp-quote "(+") out))))

;;;; Sortie finale

(ert-deftest my/export-lua-ul-only-with-inline-code ()
  "\\uacodeinline, which makes the preamble load lua-ul, is declared only
when the document contains inline code."
  (should (string-match-p "^\\\\def\\\\uacodeinline{}"
                          (org-export-string-as "Voir ~x~." 'pdfua)))
  (should-not (string-match-p "uacodeinline"
                              (org-export-string-as "Sans code." 'pdfua))))

(ert-deftest my/export-draft-drops-tagging ()
  "The draft profile removes PDF/UA tagging from \\DocumentMetadata."
  (let ((final (org-export-string-as "Texte." 'pdfua nil nil))
        (draft (org-export-string-as "Texte." 'pdfua nil '(:ua-draft t))))
    (should (string-match-p "testphase=phase-III" final))
    (should (string-match-p "pdfstandard=ua-2" final))
    (should-not (string-match-p "testphase\\|pdfstandard" draft))
    (should (string-match-p "\\\\DocumentMetadata{lang=fr,pdfversion=2.0}" draft))))

(ert-deftest my/export-graphics-width-kept ()
  "A width given in :options is not overridden by Org's default width.
Regression, present in the original configuration."
  (should (equal (my/pdfua--dedupe-graphics-width
                  "\\includegraphics[width=.8\\linewidth,alt={A, B},width=.9\\linewidth]{x}")
                 "\\includegraphics[width=.8\\linewidth,alt={A, B}]{x}"))
  (should (equal (my/pdfua--dedupe-graphics-width "\\includegraphics[width=\\largeurimpression]{y}")
                 "\\includegraphics[width=\\largeurimpression]{y}")))

(ert-deftest my/export-single-space-before-citation ()
  "A space followed by the style's non-breaking space collapses into one."
  (should (equal (my/pdfua-final-output "texte  [1] fin" 'pdfua nil)
                 "texte [1] fin")))

;;;; Bibliographies par section (CSL)

(defun my/test--run-bib-filter (org)
  "Run the per-section bibliography filter on ORG; return the new text."
  (with-temp-buffer
    (insert org)
    (my/pdfua-bibliographies-par-section 'pdfua)
    (buffer-string)))

(ert-deftest my/export-bibliographies-par-section ()
  "Each section's bibliography keeps only the keys cited in that section."
  (let* ((out (my/test--run-bib-filter
               (concat "* Un\nVoir [cite:@a;@b] et [cite/t:@c].\n"
                       "#+print_bibliography: :heading subbibliography\n"
                       "* Deux\nVoir [cite:@a].\n#+print_bibliography:\n")))
         (fns (let (acc (pos 0))
                (while (string-match ":filter \\([^ \n]+\\)" out pos)
                  (push (intern (match-string 1 out)) acc)
                  (setq pos (match-end 0)))
                (nreverse acc))))
    (should (= (length fns) 2))
    (should (funcall (nth 0 fns) '((id . "b"))))
    (should (funcall (nth 0 fns) '((id . "c"))))
    (should-not (funcall (nth 1 fns) '((id . "b"))))
    (should (funcall (nth 1 fns) '((id . "a"))))
    ;; Titres comme biblatex : \subsection* avec subbibliography, \section*
    ;; sans :heading ; environnement toujours
    (should (= 1 (cl-count-if (lambda (l) (string-match-p "^#\\+LATEX: \\\\subsection\\*{\\\\refname}$" l))
                              (split-string out "\n"))))
    (should (= 1 (cl-count-if (lambda (l) (string-match-p "^#\\+LATEX: \\\\section\\*{\\\\refname}$" l))
                              (split-string out "\n"))))
    (should (= 2 (cl-count-if (lambda (l) (string-match-p "begin{bibliographieua}" l))
                              (split-string out "\n"))))
    (should (= 2 (cl-count-if (lambda (l) (string-match-p "end{bibliographieua}" l))
                              (split-string out "\n"))))))

(ert-deftest my/export-bibliographies-other-backends-untouched ()
  "The per-section filter only acts for the PDF/UA backend."
  (with-temp-buffer
    (insert "* Un\n[cite:@a]\n#+print_bibliography:\n")
    (my/pdfua-bibliographies-par-section 'html)
    (should (equal (buffer-string) "* Un\n[cite:@a]\n#+print_bibliography:\n"))))

(ert-deftest my/export-bibliography-headings-like-biblatex ()
  "Bibliography titles follow biblatex's headings, :title included."
  (should (equal (my/pdfua--bib-heading "") "\\section*{\\refname}"))
  (should (equal (my/pdfua--bib-heading ":heading subbibliography")
                 "\\subsection*{\\refname}"))
  (should-not (my/pdfua--bib-heading ":heading none"))
  (should (equal (my/pdfua--bib-heading ":heading subbibintoc :title \"Sources\"")
                 "\\subsection*{Sources}\\addcontentsline{toc}{subsection}{Sources}"))
  (should (equal (my/pdfua--bib-heading ":heading bibnumbered") "\\section{\\refname}"))
  (should-error (my/pdfua--bib-heading ":heading inconnu") :type 'user-error))

(ert-deftest my/export-csl-configuration ()
  "Citations go through the versioned CSL style, from CSL-JSON.
Without citeproc, the basic processor keeps exports working."
  (should (equal org-cite-export-processors
                 (if my/csl-available-p
                     `((t csl ,my/csl-style-file))
                   '((t basic)))))
  (should (file-exists-p my/csl-style-file))
  (should (string-suffix-p ".json" (car org-cite-global-bibliography)))
  (should (file-exists-p (expand-file-name "locales/locales-fr-FR.xml" my/csl-dir))))

(defun my/test--json-file (content)
  "Return a temporary .json file holding CONTENT."
  (let ((f (make-temp-file "biblio-" nil ".json")))
    (with-temp-file f (insert content))
    f))

(ert-deftest my/export-csl-json-truncated ()
  "Empty or truncated CSL-JSON files are detected; valid ones pass.
Regression: an empty references.json failed deep in citeproc with
`json-end-of-file'."
  (let ((vide (my/test--json-file ""))
        (tronque (my/test--json-file "[{\"id\": \"a\", \"title\": \"x\"},\n{\"id\""))
        (autre (my/test--json-file "@article{a, title={x}}"))
        (valide (my/test--json-file
                 (concat "﻿\n[" (make-string 200 ?\s) "{\"id\": \"a\"}]\n"))))
    (should (my/csl--json-truncated-p vide))
    (should (my/csl--json-truncated-p tronque))
    (should (my/csl--json-truncated-p autre))
    (should-not (my/csl--json-truncated-p valide))
    (should-not (my/csl--json-truncated-p "/inexistant/references.json"))))

(ert-deftest my/export-csl-check-before-export ()
  "Exporting a document that cites from a truncated CSL-JSON fails clearly."
  (let ((my/csl-available-p t)
        (org-cite-global-bibliography (list (my/test--json-file ""))))
    (with-temp-buffer
      (org-mode)
      (insert "Texte [cite:@a].\n")
      (should-error (my/csl-check-bibliographies 'latex) :type 'user-error)
      ;; Sans citation : rien à vérifier
      (erase-buffer)
      (insert "Texte sans citation.\n")
      (should-not (my/csl-check-bibliographies 'latex)))))

;;;; Filtres de pré-analyse

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

(ert-deftest my/export-remarques-en-marge ()
  "[rmq:…] becomes \\RMQ outside blocks, and stays literal inside them."
  (let ((out (my/test--body
              (concat "Texte [rmq:note avec *gras*].\n"
                      "#+begin_src emacs-lisp\n;; [rmq:littéral]\n#+end_src\n"))))
    ;; Emphase en fin de remarque : rendue (défaut de la configuration
    ;; d'origine, où Org la laissait littérale devant « @@latex: »).
    (should (string-match-p (regexp-quote "\\RMQ{note avec \\textbf{gras} }") out))
    (should (string-match-p (regexp-quote ";; [rmq:littéral]") out))))

(ert-deftest my/export-items-flottant-emphase-finale ()
  "An emphasis closing a #+DESC: value is rendered too."
  (let ((out (my/test--body "#+DESC: très *important*\n#+CAPTION: T\n[[./x.png]]\n")))
    (should (string-match-p (regexp-quote "\\descfig{très \\textbf{important} }") out))))

(ert-deftest my/export-items-flottant ()
  "#+DESC/#+NOTE/#+SOURCE/#+ALT_TEXT fold into the caption and alt text."
  (let ((out (my/test--body
              (concat "#+DESC: Ce qui est présenté\n#+SOURCE: Origine\n"
                      "#+ALT_TEXT: Texte alternatif\n#+CAPTION: Titre\n"
                      "#+NAME: fig:x\n[[./x.png]]\n"))))
    (should (string-match-p (regexp-quote "\\descfig{Ce qui est présenté}") out))
    (should (string-match-p (regexp-quote "\\srcfig{Origine}") out))
    (should (string-match-p (regexp-quote "alt={Texte alternatif}") out))
    (should (string-match-p (regexp-quote "\\caption[Titre]") out))))

(ert-deftest my/export-ignore-headlines ()
  "Headlines tagged :ignore: vanish, their contents stay; consecutive ones too."
  (let ((out (my/test--body "* A :ignore:\nun\n* B :ignore:\ndeux\n* C\ntrois\n")))
    (should-not (string-match-p "section{A}\\|section{B}" out))
    (should (string-match-p "un" out))
    (should (string-match-p "deux" out))
    (should (string-match-p "section{C}" out))))

;;;; Affichage de fin d'export

;;;; Préambule

(ert-deftest my/export-preamble-nonbreaking-characters ()
  "The preamble typesets the CSL's non-breaking characters in any font.
Regression: with a font lacking U+00A0 or U+2011, they showed as a box."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "latex/preamble-common.tex" my/test--root))
    (dolist (c '("00a0" "202f" "2011"))
      (goto-char (point-min))
      (should (re-search-forward (concat "^\\\\newunicodechar{\\^\\^\\^\\^" c "}")
                                 nil t)))
    ;; Même pied de page sur les pages en style plain (titre)
    (goto-char (point-min))
    (should (search-forward "\\fancypagestyle{plain}" nil t))))

;;;; Modules LaTeX

(ert-deftest my/export-latex-modules-available ()
  "The tikz and styles-figures modules exist; dependencies come first."
  (should (member "tikz" (my/latex-modules-available)))
  (should (member "styles-figures" (my/latex-modules-available)))
  (should (equal (my/latex--module-requires "styles-figures") '("tikz")))
  (should (equal (my/latex-modules-resolve '("styles-figures")) '("tikz" "styles-figures")))
  (should (equal (my/latex-modules-resolve '("tikz" "styles-figures" "tikz"))
                 '("tikz" "styles-figures")))
  (should-error (my/latex-modules-resolve '("absent")) :type 'user-error))

(ert-deftest my/export-latex-modules-cycle ()
  "A dependency cycle is reported instead of looping."
  (let ((my/latex-modules-dir (file-name-as-directory (make-temp-file "modules-" t))))
    (with-temp-file (expand-file-name "a.tex" my/latex-modules-dir) (insert "% requires: b\n"))
    (with-temp-file (expand-file-name "b.tex" my/latex-modules-dir) (insert "% requires: a\n"))
    (should-error (my/latex-modules-resolve '("a")) :type 'user-error)))

(ert-deftest my/export-latex-modules-keyword ()
  "#+LATEX_MODULES: becomes \\input lines in the preamble, for any LaTeX export."
  (dolist (backend '(pdfua latex))
    (let ((out (org-export-string-as
                "#+LATEX_MODULES: styles-figures\nTexte." backend))
          (case-fold-search nil))
      (should (string-match-p
               (concat (regexp-quote "\\input{") ".*modules/tikz\\.tex}\n"
                       (regexp-quote "\\input{") ".*modules/styles-figures\\.tex}")
               out))
      ;; Dans le préambule, pas dans le corps
      (should (< (string-match "modules/tikz" out)
                 (string-match (regexp-quote "\\begin{document}") out))))))

(ert-deftest my/export-ui-follows-stack ()
  "The UI reacts to the three stages reported through the export stack."
  (let* ((pdf (expand-file-name "doc.pdf" temporary-file-directory))
         (my/export-pdf-file pdf)
         (my/export-window nil)
         (buf (generate-new-buffer " *test export*")))
    (unwind-protect
        (progn
          ;; Lancement : le suivi continue
          (let ((p (start-process "t" nil "sleep" "10")))
            (my/export-ui-on-stack buf nil p)
            (delete-process p))
          (should my/export-pdf-file)
          ;; Succès : le suivi s'arrête
          (my/export-ui-on-stack pdf 'pdfua)
          (should-not my/export-pdf-file)
          ;; Échec : le suivi s'arrête aussi
          (setq my/export-pdf-file pdf)
          (let ((p (start-process "f" nil "false")))
            (while (process-live-p p) (accept-process-output p 0.05))
            (my/export-ui-on-stack buf nil p))
          (should-not my/export-pdf-file))
      (kill-buffer buf))))

(ert-deftest my/export-ui-reports-latex-errors ()
  "A PDF compiled despite LaTeX errors (latexmk -f) is not a silent success."
  (let* ((dir (make-temp-file "ui-" t))
         (pdf (expand-file-name "doc.pdf" dir)))
    (should (= 0 (my/export-ui--latex-errors pdf)))          ; pas de journal
    (with-temp-file (expand-file-name "doc.log" dir)
      (insert "(./doc.tex\n! LaTeX Error: File `x.png' not found.\n"
              "l.5 \\includegraphics{x.png}\n! Undefined control sequence.\n"))
    (should (= 2 (my/export-ui--latex-errors pdf)))
    (let ((my/export-pdf-file pdf) (my/export-window nil) msg)
      (cl-letf (((symbol-function 'message)
                 (lambda (fmt &rest args) (setq msg (apply #'format fmt args)))))
        (my/export-ui-on-stack pdf 'latex))
      (should (string-match-p "AVEC 2 erreur" msg)))))

(provide 'my-export-config-test)
;;; my-export-config-test.el ends here

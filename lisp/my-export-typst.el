;;; my-export-typst.el --- Typst export backend (C-c C-e T) -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Export Org → Typst, par le menu C-c C-e T :
;;
;;   T f   fichier .typ
;;   T p   PDF                       T o   PDF, puis ouverture
;;   T d   PDF brouillon (sans PDF/UA ni balises)
;;   T F   tampon .typ
;;
;; S'appuie sur `ox-typst' (paquet tiers, GPL) et l'enrichit, dans un backend
;; dérivé `my-typst', de ce que ta chaîne LaTeX (my-export-config.el) offre :
;;
;;   - réglages par défaut : A4, marges, polices Luciole/Iosevka avec repli,
;;     numérotation « page / total », code en ligne sur fond grisé, liens
;;     gris ; langue française par défaut ;
;;   - PDF/UA-1 (`my/typst-pdf-standard') : Typst l'exige des images un texte
;;     alternatif, donné par #+ALT_TEXT: comme pour LaTeX ;
;;   - bibliographie : le .bib synchronisé par Zotero (Typst ne lit pas le
;;     CSL-JSON) et ton style CSL, donc les mêmes références et les mêmes
;;     espaces insécables que le PDF LaTeX ;
;;   - bloc de titre (titre, sous-titre, auteurs, date), blocs abstract et
;;     keyword, \orcidlink{…} et \orcidlinkunauth{…} ;
;;   - diagrammes drawio convertis en SVG (Typst refuse les PDF en PDF/UA).
;;
;; Non repris de la chaîne LaTeX : remarques en marge [rmq:…], éléments de
;; flottant #+DESC:/#+NOTE:/#+SOURCE:, bibliographies par section (Typst n'en
;; connaît qu'une).  Ce module n'a d'effet que si `ox-typst' est installé.

;;; Code:

(require 'cl-lib)
(require 'ox)
(require 'oc)
(require 'my-paths)
(require 'my-export-config)
(require 'ox-typst nil t)

(declare-function org-typst-compile "ox-typst" (typst-file))
(declare-function org-typst-export-citation "ox-typst" (citation style _ info))
(declare-function org-typst-link "ox-typst" (link contents info))
(declare-function org-typst-special-block "ox-typst" (special-block contents info))
(declare-function org-typst-template "ox-typst" (contents info))
(declare-function org-typst--as-typst-path "ox-typst" (file-path))
(declare-function org-typst--as-string "ox-typst" (string &optional no-trim))
(declare-function org-element-parent-element "org-element-ast" (node))
(defvar org-typst--file-paths)
(defvar org-typst-process)
(defvar org-typst-heading-numbering)
(defvar org-typst-export-buffer-name)
(defvar org-typst-export-buffer-major-mode)

;;;; RÉGLAGES

(defgroup my-typst nil
  "Typst export of Org documents."
  :group 'org-export)

(defcustom my/typst-pdf-standard "ua-1"
  "PDF standard requested from Typst (`--pdf-standard'), or nil for none.
\"ua-1\" produces a tagged, accessible PDF/UA-1 file; Typst then rejects
images without alternative text and PDF images.  Needs Typst 0.14 or later."
  :type '(choice (const :tag "Aucun" nil) (string :tag "Standard"))
  :group 'my-typst)

(defconst my/typst-default-header
  (string-join
   '("#set page(paper: \"a4\", margin: (x: 2.4cm, y: 3.2cm), numbering: \"1 / 1\")"
     "#set text(font: (\"Luciole\", \"Libertinus Serif\"), size: 11pt)"
     "#set par(justify: true)"
     "#show raw: set text(font: (\"Iosevka SS05\", \"Iosevka\", \"DejaVu Sans Mono\"))"
     "#show math.equation: set text(font: (\"Luciole Math\", \"New Computer Modern Math\"))"
     "#show link: set text(fill: rgb(\"#505050\"))"
     "#show link: underline"
     "#show raw.where(block: false): it => box(fill: luma(235), inset: (x: 2pt), outset: (y: 3pt), radius: 2pt, it)"
     "#show raw.where(block: true): it => block(fill: luma(247), inset: 8pt, radius: 2pt, width: 100%, align(start, it))")
   "\n")
  "Typst preamble of exports, replaced by a #+TYPST_HEADER: keyword.")

(defconst my/typst-words
  '(("fr" (abstract . "Résumé") (keywords . "Mots-clés") (references . "Références"))
    ("en" (abstract . "Abstract") (keywords . "Keywords") (references . "References")))
  "Words the export adds, by language: (LANGUAGE (WORD . TEXT)…).")

(defun my/typst--word (word info)
  "Return the text of WORD (a symbol) in the language of INFO."
  (let ((language (or (plist-get info :language) "fr")))
    (alist-get word (or (cdr (assoc language my/typst-words))
                        (cdr (assoc "en" my/typst-words))))))

(defun my/typst--process (&optional draft)
  "Return the `org-typst-process' format string.
DRAFT drops the PDF standard and the tagging, for a faster, untagged PDF."
  (concat "typst compile"
          (cond (draft " --no-pdf-tags")
                (my/typst-pdf-standard (format " --pdf-standard %s" my/typst-pdf-standard)))
          " \"%s\""))

(defun my/typst--backend-p (backend)
  "Non-nil if BACKEND, an export backend name, is Typst or derived from it."
  (and backend (symbolp backend) (org-export-derived-backend-p backend 'typst)))

;;;; PRÉ-ANALYSE : ALT_TEXT ET ORCID

(defun my/typst-prepare-buffer (backend)
  "Adapt the Org buffer for a Typst export through BACKEND.
#+ALT_TEXT: becomes #+ATTR_TYPST: :alt (alternative text of the image that
follows); \\orcidlink{ID} and \\orcidlinkunauth{ID} become Typst calls."
  (when (my/typst--backend-p backend)
    (let ((regions (my/org-regions-de-bloc))
          (case-fold-search t))
      (save-excursion
        ;; Du dernier au premier : les remplacements ne décalent pas les
        ;; positions à traiter.
        (dolist (re '("^\\([ \t]*\\)#\\+alt_text:[ \t]*\\(.*\\)$"
                      "\\\\orcidlink\\(unauth\\)?{\\([0-9X-]+\\)}"))
          (goto-char (point-max))
          (while (re-search-backward re nil t)
            (unless (my/org-dans-un-bloc-p (point) regions)
              (if (string-prefix-p "^" re)
                  (replace-match (concat "\\1#+ATTR_TYPST: :alt \\2") t)
                (replace-match
                 (format "@@typst:#orcid-link(%s, \"%s\")@@"
                         (if (match-string 1) "true" "false")
                         (match-string 2))
                 t t)))))))))

(add-hook 'org-export-before-parsing-functions #'my/typst-prepare-buffer)

;;;; TRANSCODEURS

(defun my/typst-link (link contents info)
  "Export LINK like `org-typst-link', with the alt text of an image.
The alt text comes from #+ALT_TEXT: (see `my/typst-prepare-buffer')."
  (let ((out (org-typst-link link contents info))
        (alt (org-export-read-attribute
              :attr_typst (org-element-parent-element link) :alt)))
    (if (and out alt (string-match "#image(sys\\.inputs\\.file-[0-9]+" out))
        (replace-match (concat (match-string 0 out) ", alt: "
                               (org-typst--as-string alt))
                       t t out)
      out)))

(defun my/typst-special-block (block contents info)
  "Export special BLOCK; abstract and keyword blocks get a heading word."
  (pcase (downcase (org-element-property :type block))
    ("abstract"
     (format "#block(width: 100%%, inset: (x: 1.2cm, y: 0pt))[#align(center)[#strong[%s]]\n%s]\n"
             (my/typst--word 'abstract info) (org-trim contents)))
    ((or "keyword" "keywords")
     (format "#strong[%s.] %s\n"
             (my/typst--word 'keywords info) (org-trim contents)))
    (_ (org-typst-special-block block contents info))))

(defconst my/typst-assets-dir (expand-file-name "assets/" user-emacs-directory)
  "Directory of the ORCID icons.")

(defconst my/typst-orcid-helpers
  "#let orcid-link(unauth, id) = link(\"https://orcid.org/\" + id, box(baseline: 15%, image(if unauth { sys.inputs.orcid-icon-unauth } else { sys.inputs.orcid-icon }, height: 0.9em, alt: \"ORCID iD \" + id)))\n"
  "Typst definition of the ORCID link, using the icons passed as inputs.")

(defun my/typst--title-block (info)
  "Return the Typst title block (title, subtitle, authors, date) of INFO."
  (let ((title (plist-get info :title))
        (subtitle (plist-get info :subtitle))
        (author (and (plist-get info :with-author) (plist-get info :author)))
        (date (plist-get info :date)))
    (when title
      (concat
       "#align(center)[\n"
       (format "#title[%s]\n" (org-export-data title info))
       (when subtitle
         (format "#v(0.2em)\n#text(size: 1.2em)[%s]\n" (org-export-data subtitle info)))
       (when author
         (format "#v(0.8em)\n%s\n" (org-export-data author info)))
       (when date
         (format "#v(0.4em)\n%s\n" (org-export-data date info)))
       "]\n#v(1.2em)\n"))))

(defun my/typst--author-text (info)
  "Return the plain text of the authors of INFO, without ORCID markup."
  (mapconcat (lambda (object) (if (stringp object) object ""))
             (plist-get info :author) ""))

(defun my/typst-template (contents info)
  "Typst document of CONTENTS and INFO: `org-typst-template' plus a title block.
The table of contents moves after the title block, and the PDF metadata lists
every author (`org-typst-template' keeps the first one).  A buffer without
file is exported too (`org-typst-template' needs an input file name)."
  (let* ((title-block (my/typst--title-block info))
         (toc (plist-get info :with-toc))
         (body (concat title-block (when toc "#outline()\n") contents)))
    (when (string-match-p "#orcid-link(" body)
      (dolist (icon '(("orcid-icon" . "ORCID-iD-icon-BW-16x16.png")
                      ("orcid-icon-unauth" . "ORCID-iD-icon-unauth-BW-16x16.png")))
        (push (list (car icon) (expand-file-name (cdr icon) my/typst-assets-dir))
              org-typst--file-paths))
      (setq body (concat my/typst-orcid-helpers body)))
    (let ((out (org-typst-template
                body
                (let ((info (plist-put (copy-sequence info) :with-toc nil)))
                  ;; Date en texte libre (#+DATE: 2026-10-05, \today) : le
                  ;; gabarit d'ox-typst n'attend qu'un horodatage Org.
                  (unless (and (plist-get info :date)
                               (eq (org-element-type (car (plist-get info :date)))
                                   'timestamp))
                    (setq info (plist-put info :date nil)))
                  ;; Tampon sans fichier : ox-typst a besoin d'un nom d'entrée.
                  (if (plist-get info :input-file) info
                    (plist-put info :input-file
                               (expand-file-name "tampon.org" default-directory))))))
          (authors (and (plist-get info :with-author) (my/typst--author-text info))))
      (if (and authors (org-string-nw-p authors))
          (replace-regexp-in-string
           "\\(#set document([^\n]*author: \\)\"[^\"]*\""
           (lambda (match)
             (concat (substring match 0 (match-end 1)) (org-typst--as-string authors)))
           out t)
        out))))

;;;; BIBLIOGRAPHIE : .bib ET STYLE CSL

(defun my/typst--bibliography-files (files)
  "Return, from FILES, the bibliographies Typst reads (.bib, .yml).
A CSL-JSON file stands for its sibling .bib; with none, `my/bibtex-files'."
  (let (out)
    (dolist (f files)
      (cond
       ((string-match-p "\\.\\(?:bib\\|bibtex\\|ya?ml\\)\\'" f) (push f out))
       ((string-match-p "\\.json\\'" f)
        (let ((bib (concat (file-name-sans-extension f) ".bib")))
          (when (file-exists-p bib) (push bib out))))))
    (or (delete-dups (nreverse out))
        (cl-remove-if-not #'file-exists-p my/bibtex-files)
        (user-error "Typst ne lit pas le CSL-JSON : ni .bib voisin ni `my/bibtex-files'"))))

(defun my/typst--style-argument (style)
  "Return the Typst expression for the bibliography STYLE, or nil.
A CSL file is passed as an input (so that Typst can read it); anything else
is a built-in style name such as \"ieee\"."
  (cond ((null style) nil)
        ((file-exists-p style) (org-typst--as-typst-path style))
        (t (org-typst--as-string style))))

(defun my/typst-export-bibliography (_keys files style properties _backend info)
  "Export the bibliography of FILES in Typst, with STYLE and PROPERTIES.
INFO is the export plist.  :heading none removes the title, :heading sub…
makes it a level 2 heading, :title replaces the default \"References\"."
  (let* ((heading (and (string-match "\\`\\([^ ]+\\)" (or (plist-get properties :heading) ""))
                       (match-string 1 (plist-get properties :heading))))
         (title (cond ((equal heading "none") "none")
                      ((plist-get properties :title)
                       (format "[%s]" (plist-get properties :title)))
                      (t (format "[%s]" (my/typst--word 'references info)))))
         (paths (mapcar #'org-typst--as-typst-path
                        (my/typst--bibliography-files files)))
         (source (if (cdr paths) (format "(%s)" (string-join paths ", ")) (car paths)))
         (call (format "#bibliography(%s, title: %s%s)" source title
                       (if-let* ((s (my/typst--style-argument style)))
                           (format ", style: %s" s) ""))))
    (if (and heading (string-prefix-p "sub" heading))
        (format "#[#show bibliography: set heading(level: 2)\n%s]" call)
      call)))

(defconst my/typst-cite-styles
  '(("t" . "text") ("a" . "author") ("na" . "noauthor") ("n" . "nocite"))
  "Org citation style shorthands (/t, /a…) and the names `ox-typst' expects.")

(defun my/typst-export-citation (citation style bibliography info)
  "Export CITATION in Typst; STYLE shorthands (/t…) are expanded first.
BIBLIOGRAPHY and INFO are as in `org-typst-export-citation'."
  (let ((long (cdr (assoc (car style) my/typst-cite-styles))))
    (org-typst-export-citation citation (if long (cons long (cdr style)) style)
                               bibliography info)))

(defun my/typst--setup-citations ()
  "Route Typst citations to `my-typst' (the .bib file and the CSL style)."
  (org-cite-register-processor 'my-typst
    :export-bibliography #'my/typst-export-bibliography
    :export-citation #'my/typst-export-citation)
  (setf (alist-get 'typst org-cite-export-processors)
        (list 'my-typst my/csl-style-file)))

;;;; COMMANDES

(defun my/typst--major-mode ()
  "Major mode of the Typst buffer export, or nil."
  (when org-typst-export-buffer-major-mode
    (if (fboundp 'major-mode-remap)
        (major-mode-remap org-typst-export-buffer-major-mode)
      org-typst-export-buffer-major-mode)))

;;;###autoload
(defun my/typst-export-as-typst
    (&optional async subtreep visible-only body-only ext-plist)
  "Export the Org buffer to a Typst buffer.
ASYNC, SUBTREEP, VISIBLE-ONLY, BODY-ONLY and EXT-PLIST are as in
`org-export-to-buffer'."
  (interactive)
  (setq org-typst--file-paths nil)
  (org-export-to-buffer 'my-typst org-typst-export-buffer-name
    async subtreep visible-only body-only ext-plist (my/typst--major-mode)))

;;;###autoload
(defun my/typst-export-to-typst
    (&optional async subtreep visible-only body-only ext-plist)
  "Export the Org buffer to a Typst file.
ASYNC, SUBTREEP, VISIBLE-ONLY, BODY-ONLY and EXT-PLIST are as in
`org-export-to-file'."
  (interactive)
  (setq org-typst--file-paths nil)
  (org-export-to-file 'my-typst (org-export-output-file-name ".typ" subtreep)
    async subtreep visible-only body-only ext-plist))

(defun my/typst-compile (typst-file &optional draft)
  "Compile TYPST-FILE to PDF with `my/typst--process'; DRAFT drops PDF/UA.
Return the PDF file name."
  (let ((org-typst-process (my/typst--process draft)))
    (org-typst-compile typst-file)))

(defun my/typst-compile-draft (typst-file)
  "Compile TYPST-FILE to an untagged draft PDF."
  (my/typst-compile typst-file t))

;;;###autoload
(defun my/typst-export-to-pdf
    (&optional async subtreep visible-only body-only ext-plist)
  "Export the Org buffer to a PDF through Typst; return the PDF file name.
ASYNC, SUBTREEP, VISIBLE-ONLY, BODY-ONLY and EXT-PLIST are as in
`org-export-to-file'."
  (interactive)
  (setq org-typst--file-paths nil)
  (org-export-to-file 'my-typst (org-export-output-file-name ".typ" subtreep)
    async subtreep visible-only body-only ext-plist #'my/typst-compile))

;;;###autoload
(defun my/typst-export-draft-to-pdf
    (&optional async subtreep visible-only body-only ext-plist)
  "Export to a draft PDF, without PDF/UA nor tagging (no alt text required).
ASYNC, SUBTREEP, VISIBLE-ONLY, BODY-ONLY and EXT-PLIST are as in
`my/typst-export-to-pdf'."
  (interactive)
  (setq org-typst--file-paths nil)
  (org-export-to-file 'my-typst (org-export-output-file-name ".typ" subtreep)
    async subtreep visible-only body-only ext-plist #'my/typst-compile-draft))

;;;; BACKEND

(defun my/typst-setup ()
  "Define the `my-typst' backend, hide ox-typst's own menu entry (key y)."
  (setopt org-typst-heading-numbering "1.1")
  (org-export-define-derived-backend 'my-typst 'typst
    :menu-entry
    '(?T "Export Typst"
         ((?F "Tampon .typ" my/typst-export-as-typst)
          (?f "Fichier .typ" my/typst-export-to-typst)
          (?p "PDF" my/typst-export-to-pdf)
          (?o "PDF et ouvrir"
              (lambda (a s v b)
                (if a (my/typst-export-to-pdf t s v b)
                  (org-open-file (my/typst-export-to-pdf nil s v b)))))
          (?d "PDF brouillon (sans PDF/UA ni balises)" my/typst-export-draft-to-pdf)))
    :translate-alist '((link . my/typst-link)
                       (special-block . my/typst-special-block)
                       (template . my/typst-template))
    :options-alist '((:language "LANGUAGE" nil "fr" t)
                     (:subtitle "SUBTITLE" nil nil parse)
                     (:typst-header "TYPST_HEADER" nil my/typst-default-header newline)))
  ;; Une seule entrée « Typst » dans le menu : la nôtre (T), pas celle d'ox-typst.
  (setf (org-export-backend-menu (org-export-get-backend 'typst)) nil)
  (my/typst--setup-citations))

(if (featurep 'ox-typst)
    (my/typst-setup)
  (message "ATTENTION : ox-typst absent — export Typst (C-c C-e T) indisponible"))

(provide 'my-export-typst)
;;; my-export-typst.el ends here

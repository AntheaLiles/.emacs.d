;;; my-export-config.el --- Shared Org export configuration -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Source unique de vérité pour l'export Org → PDF/UA-2 (LuaLaTeX).
;; Chargé par init.el (via with-eval-after-load 'ox-latex) et par
;; my-export-async.el (directement).
;;
;; Définit le backend `pdfua', dérivé de `latex' (menu C-c C-e u), et ses
;; deux classes :
;;   article-ua  recto seul, sections enchaînées (classe par défaut) ;
;;   book-ua     recto verso, chaque section sur une page impaire.
;; Les filtres propres à la chaîne (remarques en marge, éléments de
;; flottant, code en ligne, bibliographies par section) ne s'appliquent
;; qu'à ce backend.  Citations : processeur CSL, style versionné dans csl/.
;;
;; Prérequis :
;;   - org, ox-latex chargés
;;   - variables de my-paths.el (bibliographies, répertoires CSL)

;;; Code:

(require 'cl-lib)
(require 'ox-latex)
(require 'oc)
(require 'my-paths)

;;;; FICHIERS DU DÉPÔT
;; Dérivés de `user-emacs-directory' : aucun chemin ~/.emacs.d en dur.
(defconst my/latex-dir (expand-file-name "latex/" user-emacs-directory)
  "Directory holding the LaTeX preambles and latexmk configuration.")

(defconst my/latexmkrc-file (expand-file-name "latexmkrc" my/latex-dir)
  "Configuration file passed to latexmk with -r.")

(defconst my/csl-dir (expand-file-name "csl/" user-emacs-directory)
  "Directory holding the versioned CSL style and fallback locales.")

(defconst my/csl-style-file
  (expand-file-name "iso-ieee-localised-collapsed.csl" my/csl-dir)
  "CSL style used for citations and bibliographies.")

;;;; PIPELINE LUALATEX
;; Ni -shell-escape (aucun paquet du préambule ne l'exige ; il permettrait à
;; un document d'exécuter des commandes), ni -f (un PDF produit malgré des
;; erreurs passerait pour un succès).
(setopt org-latex-compiler "lualatex"
        org-latex-pdf-process
        (list (concat "latexmk -lualatex -interaction=nonstopmode"
                      " -output-directory=%o -r "
                      (shell-quote-argument my/latexmkrc-file)
                      " %f"))
        org-latex-prefer-user-labels t)

;;;; BACKEND ENGRAVED
;; Repli sur verbatim si engrave-faces est absent (processus asynchrone lancé
;; avant l'installation du paquet, par exemple) : sinon l'export échoue.
(if (locate-library "engrave-faces-latex")
    (setopt org-latex-src-block-backend 'engraved)
  (message "ATTENTION : engrave-faces-latex absent — rendu verbatim des blocs")
  (setopt org-latex-src-block-backend 'verbatim))
(setopt org-latex-engraved-options
        '(("commandchars" . "\\\\\\{\\}")
          ("fontsize" . "\\small")))

;;;; CODE EN LIGNE
;; ~code~ et src_LANG{code} sont composés par la macro \CodeInline du
;; préambule : monospace sur fond grisé (lua-ul, sécable en fin de ligne).
;;
;;   ~code~              monospace sur fond grisé, sans coloration ;
;;   src_LANG{code}      idem, coloré selon LANG par engrave-faces
;;                       (ex. src_emacs-lisp{(setq x 1)}, src_python{x = 1}) ;
;;   =verbatim=          inchangé : monospace simple, sans fond.
;;
;; ox-latex produit \texttt{…} pour ~code~ et \Verb[…]{…} pour les blocs en
;; ligne.  Le contenu d'engrave-faces a déjà tous ses caractères spéciaux
;; échappés : c'est du LaTeX ordinaire, que l'on peut passer en argument à
;; \CodeInline sans les contraintes du verbatim.  Seules les espaces sont
;; rendues explicites (\ ), pour ne pas être fusionnées.  Filtre installé
;; par le backend `pdfua' (voir plus bas).

(defconst my/org-latex-inline-code-regexp
  (concat "\\`\\(?:\\\\texttt\\|\\\\Verb\\(?:\\[[^]]*\\]\\)?\\)"
          "{\\(\\(?:.\\|\n\\)*\\)}\\([ \t\n]*\\)\\'")
  "Match ox-latex output for inline code: \\texttt{…} or \\Verb[…]{…}.
Group 1 is the code, group 2 the trailing blanks added by the exporter.")

(defun my/org-latex-inline-code (text _backend _info)
  "Rewrap inline code TEXT in \\CodeInline.
Installed on `code' and `inline-src-block' objects by the `pdfua'
backend, titles included (they are exported through an anonymous
backend that inherits the same filters)."
  (if (string-match my/org-latex-inline-code-regexp text)
      (let ((code (match-string 1 text))
            (blanks (match-string 2 text)))
        (concat "\\CodeInline{"
                (replace-regexp-in-string " " "\\ " code t t)
                "}" blanks))
    text))

;; Un bloc en ligne est, par défaut, ÉVALUÉ à l'export et remplacé par son
;; résultat (:exports results).  Or la confirmation Babel est coupée pendant
;; l'export (voir BABEL) : src_sh{rm …} s'exécuterait sans demander.  Par
;; défaut, on exporte donc le CODE ; pour un résultat, l'écrire
;; explicitement : src_python[:exports results]{1 + 1}.
(with-eval-after-load 'ob-core
  (setf (alist-get :exports org-babel-default-inline-header-args) "code"))

;;;; OPTIONS ORG PAR DÉFAUT
;; org-export-with-toc nil : intentionnel.
;; La ToC est placée manuellement dans chaque document via #+TOC: headlines N
;; avec mise en forme personnalisée (multicols, taille, etc.)
(setopt org-export-with-sub-superscripts '{}
        org-export-with-special-strings t
        org-export-with-fixed-width t
        org-export-with-timestamps t
        org-export-with-toc nil
        org-export-with-tags nil
        org-export-headline-levels 5)

;;;; CLASSES LATEX
;; La classe `article' d'Org n'est plus écrasée : les deux classes PDF/UA
;; portent leur propre nom.  \emacsdir sert au préambule pour trouver ses
;; fichiers compagnons (preamble-common.tex, icône ORCID).
(defun my/pdfua-class-header (variant)
  "Return the LaTeX class header of the VARIANT preamble (\"article\" or \"book\")."
  (concat "\\DocumentMetadata{lang=fr,pdfversion=2.0,pdfstandard=ua-2,
                   testphase=phase-III}
\\documentclass[a4paper,11pt]{article}
\\newcommand{\\emacsdir}{" user-emacs-directory "}
\\input{" (expand-file-name (format "preamble-%s-ua.tex" variant) my/latex-dir) "}
[NO-DEFAULT-PACKAGES]
[PACKAGES]
[EXTRA]"))

(dolist (variant '("article" "book"))
  (setf (alist-get (concat variant "-ua") org-latex-classes nil nil #'equal)
        (list (my/pdfua-class-header variant)
              '("\\section{%s}" . "\\section*{%s}")
              '("\\subsection{%s}" . "\\subsection*{%s}")
              '("\\subsubsection{%s}" . "\\subsubsection*{%s}")
              '("\\paragraph{%s}" . "\\paragraph*{%s}")
              '("\\subparagraph{%s}" . "\\subparagraph*{%s}"))))

;;;; CITATIONS (CSL)
;; Bibliographie Org en CSL-JSON (export Better CSL JSON de Zotero) ; la .bib
;; reste synchronisée pour AUCTeX et RefTeX.  Locales : le répertoire de
;; my-paths.el s'il existe, sinon la locale française versionnée dans csl/.
;; Sans citeproc (export lancé avant son installation par Elpaca), le
;; processeur csl ferait échouer TOUT export, même sans citation : repli sur
;; le processeur basic d'Org, avec un avertissement.
(defconst my/csl-available-p (and (locate-library "citeproc") t)
  "Non-nil when citeproc-el, required by the CSL processor, is installed.")

(unless my/csl-available-p
  (message "ATTENTION : citeproc absent — citations exportées par le processeur basic"))

(setopt org-cite-global-bibliography my/bibliography-files
        org-cite-export-processors (if my/csl-available-p
                                       `((t csl ,my/csl-style-file))
                                     '((t basic)))
        org-cite-csl-locales-dir
        (if (file-directory-p my/csl-locales-dir)
            my/csl-locales-dir
          (expand-file-name "locales/" my/csl-dir)))

;;;; BABEL
;; Par défaut, demander confirmation avant d'exécuter un bloc babel.
;; Pendant l'export, désactiver la confirmation automatiquement
;; via un hook (voir ci-dessous).
;; Cela évite :
;;   1. L'exécution silencieuse de code à l'ouverture d'un fichier tiers
;;   2. Le ralentissement à l'ouverture (blocs exécutés prématurément)
(setopt org-confirm-babel-evaluate t)

(defun my/org-babel-confirm-off-for-export (_backend)
  "Disable babel confirmation during export.
_BACKEND is the export backend (unused but required by the hook)."
  (setq-local org-confirm-babel-evaluate nil))

(add-hook 'org-export-before-processing-functions
          #'my/org-babel-confirm-off-for-export)

;;;; TITRES :ignore:
;; Définition unique, partagée par Emacs et par le processus d'export
;; asynchrone (autrefois dupliquée dans init.el et my-export-async.el,
;; la copie d'init.el supprimant en avançant et sautant des titres).

(defun my/org-export-ignore-headlines (_backend)
  "Remove headlines tagged :ignore: but keep their contents.
Positions are collected first, then deleted from the end of the buffer
backwards, so that earlier deletions never shift later positions."
  (org-with-wide-buffer
   (let (positions)
     (org-map-entries
      (lambda ()
        (when (member "ignore" (org-get-tags nil t))
          (push (point) positions))))
     (dolist (p (sort positions #'>))
       (goto-char p)
       (delete-region (line-beginning-position) (line-beginning-position 2))))))

(add-hook 'org-export-before-processing-functions
          #'my/org-export-ignore-headlines)

;;;; OUTILLAGE COMMUN AUX FILTRES DE PRÉ-ANALYSE
;;
;; Les filtres qui suivent réécrivent le tampon avant qu'Org ne l'analyse.
;; Deux d'entre eux doivent épargner le contenu des blocs (#+BEGIN_SRC,
;; #+BEGIN_EXPORT, #+BEGIN_EXAMPLE…), où le texte est littéral et ne doit
;; jamais être transformé.

(defun my/org--espace-apres-emphase (char)
  "Return \" \" if CHAR closes an Org emphasis, else the empty string.
Org only closes an emphasis before a space or a punctuation mark, not
before the @@ of an export snippet: \"*gras*@@latex:}@@\" would stay
literal.  A space is harmless at the end of a LaTeX macro argument."
  (if (and char (memq char '(?* ?/ ?_ ?= ?~ ?+))) " " ""))

(defun my/org-regions-de-bloc ()
  "Rend la liste des régions (DÉBUT . FIN) couvertes par un bloc Org.
Un bloc va de la ligne #+BEGIN_… à la ligne #+END_… correspondante,
bornes comprises.  Les blocs imbriqués sont traités par leur bloc
englobant, ce qui suffit à l'usage qui en est fait ici : savoir si une
position donnée est littérale ou non."
  (save-excursion
    (goto-char (point-min))
    (let ((regions '()) (debut nil) (profondeur 0)
          (case-fold-search t))
      (while (re-search-forward "^[ \t]*#\\+\\(BEGIN\\|END\\)_[A-Za-z]" nil t)
        (if (string-equal (upcase (match-string 1)) "BEGIN")
            (progn
              (when (zerop profondeur)
                (setq debut (line-beginning-position)))
              (setq profondeur (1+ profondeur)))
          (setq profondeur (max 0 (1- profondeur)))
          (when (and (zerop profondeur) debut)
            (push (cons debut (line-end-position)) regions)
            (setq debut nil))))
      ;; Bloc ouvert sans #+END_ : on protège jusqu'à la fin du tampon.
      (when debut (push (cons debut (point-max)) regions))
      (nreverse regions))))

(defun my/org-dans-un-bloc-p (position regions)
  "Non-nil si POSITION tombe dans l'une des REGIONS de bloc."
  (seq-some (lambda (r) (and (>= position (car r)) (<= position (cdr r))))
            regions))

(defun my/org-fin-de-crochet (debut)
  "Rend la position suivant le crochet fermant ouvert juste avant DEBUT.
DEBUT est la position du premier caractère du contenu.  Le comptage est
équilibré, de sorte qu'un crochet à l'intérieur du contenu ne referme
rien.  Rend nil si le crochet n'est jamais refermé."
  (let ((i debut) (profondeur 1) (fin (point-max)))
    (while (and (< i fin) (> profondeur 0))
      (pcase (char-after i)
        (?\[ (setq profondeur (1+ profondeur)))
        (?\] (setq profondeur (1- profondeur))))
      (setq i (1+ i)))
    (and (zerop profondeur) i)))

;;;; HOOKS D'EXPORT

;;;;; Remarques en marge : [rmq:texte] → \RMQ{texte}
;;
;; La macro \RMQ du préambule pose la remarque dans la zone d'annotation et
;; la balise <Aside> pour PDF/UA.  On l'enveloppe dans des extraits d'export
;; @@latex:…@@ plutôt que d'écrire \RMQ{…} en clair : ainsi le contenu de la
;; remarque reste du texte Org, et l'emphase, les citations ou les renvois
;; qu'il porte continuent d'être analysés normalement.
;;
;; Le balayage part de la fin du tampon, pour que les remplacements ne
;; déplacent pas les positions restant à traiter.

(defun my/org-remarques-en-marge (backend)
  "Convertit les [rmq:texte] en remarques marginales pour l'export PDF/UA.
BACKEND est le backend d'export."
  (when (org-export-derived-backend-p backend 'pdfua)
    (let ((regions (my/org-regions-de-bloc))
          (occurrences '())
          (case-fold-search t))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "\\[rmq:" nil t)
          (let ((ouverture (match-beginning 0))
                (contenu (match-end 0)))
            (unless (my/org-dans-un-bloc-p ouverture regions)
              (let ((fermeture (my/org-fin-de-crochet contenu)))
                (if fermeture
                    (push (list ouverture contenu fermeture) occurrences)
                  (message "ATTENTION : [rmq: non refermé à la position %d"
                           ouverture)))))))
      ;; De la fin vers le début
      (dolist (o occurrences)
        (pcase-let ((`(,ouverture ,contenu ,fermeture) o))
          (save-excursion
            (goto-char (1- fermeture))       ; le ] fermant
            (delete-char 1)
            (insert (my/org--espace-apres-emphase (char-before))
                    "@@latex:}@@")
            (goto-char ouverture)
            (delete-region ouverture contenu)
            (insert "@@latex:\\RMQ{@@")))))))

(add-hook 'org-export-before-parsing-functions #'my/org-remarques-en-marge)

;;;;; Items de flottant : #+DESC:, #+NOTE:, #+SOURCE:, #+ALT_TEXT:
;;
;; LES QUATRE MOTS-CLÉS PERSONNELS OUVRENT LA PILE, et ce n'est pas une
;; préférence de présentation. Org n'attache à un élément que les mots-clés
;; affiliés qui le précèdent SANS INTERRUPTION ; ceux-ci n'en sont pas. Placés
;; après #+CAPTION:, ils coupent la chaîne et la figure perd sa légende, son
;; numéro et son étiquette — c'est ce qui est arrivé aux douze figures le
;; 8 septembre. Placés en tête, ils ne coupent rien, et le document se compose
;; correctement même si ce filtre n'a pas tourné : sans les items, mais avec
;; ses légendes. Une source qui dépend d'un outil doit se dégrader ainsi.
;;
;;   #+DESC: Ce que la figure présente, pour dispenser le corps du texte
;;   #+NOTE: Comment lire le graphique lorsque sa forme n'est pas courante
;;   #+SOURCE: Fait avec mermaid.js v11, 2026
;;   #+ALT_TEXT: Description destinée à la synthèse vocale
;;   #+CAPTION: Cycle de vie d'un acteur virtuel
;;   #+NAME: fig:acteur-cycle-de-vie
;;   #+ATTR_LATEX: :placement [htbp] :options width=.8\largeurimpression
;;   [[../../meta/virtual-actor-lca.drawio]]
;;
;; L'ordre des quatre premiers entre eux est libre. Un contrôle
;; (controles/source.py) refuse toute autre disposition.
;;
;; Aucun de ces quatre mots-clés n'est un mot-clé affilié d'Org.  Laissés en
;; place, ils rompraient la pile du flottant, et #+CAPTION: comme #+NAME:
;; cesseraient de s'y attacher — le flottant perdrait sa légende, son numéro et
;; son étiquette, et tout \ref vers lui remonterait au titre de section le plus
;; proche.  C'est exactement le défaut qu'avait la table 3.1.  On les retire
;; donc avant l'analyse, et l'on replie leur contenu là où Org l'attend :
;;
;;   DESC, NOTE, SOURCE → la légende, sous la forme des macros \descfig,
;;     \notefig et \srcfig que le préambule relit pour composer la grille ;
;;   ALT_TEXT → l'attribut alt de #+ATTR_LATEX:, seul endroit d'où graphicx
;;     le porte jusqu'au balisage PDF/UA.  La ligne #+ATTR_LATEX: est créée si
;;     elle manque, et l'attribut s'ajoute à un :options déjà présent.
;;
;; La légende reçoit au passage une forme courte, afin que la liste des figures
;; et celle des tableaux portent le seul titre et non les items.
;;
;; Deux caractères sont à éviter dans un #+ALT_TEXT: — l'accolade fermante, qui
;; refermerait alt={…} trop tôt, et un deux-points collé à un mot, qu'Org
;; prendrait pour le début d'un autre attribut.

(defconst my/org-items-flottants-regexp
  "^[ \t]*#\\+\\(DESC\\|NOTE\\|SOURCE\\|ALT_TEXT\\):[ \t]*\\(.*?\\)[ \t]*$"
  "Reconnaît une ligne d'item de flottant et capture son mot-clé et sa valeur.")

(defconst my/org-items-flottants-macros
  '(("DESC" . "descfig") ("NOTE" . "notefig") ("SOURCE" . "srcfig"))
  "Macro LaTeX du préambule associée à chaque mot-clé d'item de légende.")

(defun my/org-attr-latex-avec-alt (ligne alt)
  "Rend LIGNE, un #+ATTR_LATEX:, augmentée de l'attribut alt valant ALT."
  (if (string-match ":options[ \t]+" ligne)
      (replace-regexp-in-string
       ":options[ \t]+\\([^\n]*\\)"
       (lambda (m) (format ":options %s,alt={%s}"
                           (match-string 1 m) alt))
       ligne t t)
    (concat ligne (format " :options alt={%s}" alt))))

(defun my/org-items-flottants (backend)
  "Replie les items de flottant là où Org les attend.
BACKEND est le backend d'export."
  (when (org-export-derived-backend-p backend 'pdfua)
    (save-excursion
      (goto-char (point-min))
      (let ((case-fold-search t))
        (while (re-search-forward "^[ \t]*#\\+" nil t)
          (beginning-of-line)
          (let ((debut (point)) (items '()) (caption nil) (court nil))
            ;; Parcourir la pile de mots-clés contiguë, en s'arrêtant net sur
            ;; une ligne #+BEGIN_… qui ouvre un bloc.
            (while (and (looking-at "^[ \t]*#\\+")
                        (not (looking-at "^[ \t]*#\\+BEGIN_")))
              (cond
               ((looking-at my/org-items-flottants-regexp)
                (push (cons (upcase (match-string 1)) (match-string 2)) items))
               ((looking-at "^[ \t]*#\\+CAPTION\\(\\[\\(.*\\)\\]\\)?:[ \t]*\\(.*?\\)[ \t]*$")
                (setq caption (match-string 3)
                      court (match-string 2))))
              (forward-line 1))
            (let ((fin (point))
                  (alt (cdr (assoc "ALT_TEXT" items))))
              (cond
               ;; Aucune ligne consommée — la pile s'ouvrait sur #+BEGIN_.
               ;; Avancer d'une ligne, faute de quoi la recherche repartirait
               ;; de la même position et l'export tournerait sans fin.
               ((= fin debut) (forward-line 1))
               ((not (or alt (and items caption))) (goto-char fin))
               (t
                (let* ((lignes (split-string
                                (buffer-substring-no-properties debut fin)
                                "\n" t))
                       (gardees
                        (seq-remove (lambda (l) (string-match-p
                                                 my/org-items-flottants-regexp l))
                                    lignes))
                       ;; Le contenu de l'item reste du texte Org : on n'écrit
                       ;; en LaTeX que l'ouverture et la fermeture de la macro.
                       (suffixe
                        (mapconcat
                         (lambda (paire)
                           (let ((v (cdr (assoc (car paire) items))))
                             (if (and v (not (string-empty-p v)))
                                 (format "@@latex:\\%s{@@%s%s@@latex:}@@"
                                         (cdr paire) v
                                         (my/org--espace-apres-emphase
                                          (aref v (1- (length v)))))
                               "")))
                         my/org-items-flottants-macros ""))
                       (neuve (and caption
                                   (format "#+CAPTION[%s]: %s%s"
                                           (or court caption) caption suffixe))))
                  ;; La légende, si elle existe et qu'un item la vise
                  (when (and neuve (not (string-empty-p suffixe)))
                    (setq gardees
                          (mapcar (lambda (l)
                                    (if (string-match-p "^[ \t]*#\\+CAPTION" l)
                                        neuve l))
                                  gardees)))
                  ;; Le texte de remplacement, dans #+ATTR_LATEX: — la
                  ;; première ligne seulement, une pile pouvant en porter
                  ;; plusieurs et l'attribut ne devant être écrit qu'une fois.
                  (when (and alt (not (string-empty-p alt)))
                    (let ((pose nil))
                      (setq gardees
                            (mapcar (lambda (l)
                                      (if (and (not pose)
                                               (string-match-p
                                                "^[ \t]*#\\+ATTR_LATEX:" l))
                                          (progn (setq pose t)
                                                 (my/org-attr-latex-avec-alt l alt))
                                        l))
                                    gardees))
                      (unless pose
                        (setq gardees
                              (append gardees
                                      (list (format "#+ATTR_LATEX: :options alt={%s}"
                                                    alt)))))))
                  (delete-region debut fin)
                  (goto-char debut)
                  (insert (mapconcat #'identity gardees "\n") "\n")))))))))))

(add-hook 'org-export-before-parsing-functions #'my/org-items-flottants)

;;;;; Blocs de tableau
(defun my/org-unwrap-table-blocks (_backend)
  "Supprime les blocs #+BEGIN_TABLE / #+END_TABLE avant l'export."
  (save-excursion
    (goto-char (point-min))
    (let ((case-fold-search t))
      (while (re-search-forward "^[ \t]*#\\+BEGIN_TABLE[ \t]*\n" nil t)
        (unless (org-in-src-block-p)
          (replace-match "")))
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*#\\+END_TABLE[ \t]*\n" nil t)
        (unless (org-in-src-block-p)
          (replace-match ""))))))

(add-hook 'org-export-before-parsing-functions #'my/org-unwrap-table-blocks)

;;;;; Diagrammes drawio
(defun my/org-convert-drawio (_backend)
  "Convert .drawio links to .pdf before export."
  (when (executable-find "drawio")
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "\\[\\[\\(file:\\)?\\([^]]*\\.drawio\\)\\]\\]" nil t)
        ;; Positions relevées tout de suite : les appels qui suivent
        ;; (processus externe, messages) peuvent écraser les données de match.
        ;; Le préfixe file: est conservé dans le lien réécrit : sans lui,
        ;; [[img/x.pdf]] serait lu par Org comme un lien interne.
        (let* ((link-beg (match-beginning 0))
               (link-end (match-end 0))
               (prefix (or (match-string 1) ""))
               (drawio-file (match-string 2))
               (drawio-path (expand-file-name drawio-file))
               (pdf-path (concat (file-name-sans-extension drawio-path) ".pdf"))
               (pdf-link (concat (file-name-sans-extension drawio-file) ".pdf")))
          (when (and (file-exists-p drawio-path)
                     (or (not (file-exists-p pdf-path))
                         (time-less-p
                          (file-attribute-modification-time
                           (file-attributes pdf-path))
                          (file-attribute-modification-time
                           (file-attributes drawio-path)))))
            (message "Converting %s to PDF..." drawio-file)
            (let ((code (call-process "timeout" nil "*drawio*" nil "60"
                                      "drawio" "-x" "-f" "pdf" "--crop"
                                      "-o" pdf-path drawio-path)))
              (unless (eq code 0)
                (message "ATTENTION : conversion de %s échouée ou expirée (code %s)"
                         drawio-file code))))
          (goto-char link-beg)
          (delete-region link-beg link-end)
          (insert "[[" prefix pdf-link "]]"))))))

(add-hook 'org-export-before-parsing-functions #'my/org-convert-drawio)

;;;; BIBLIOGRAPHIES PAR SECTION (CSL)
;; biblatex ouvrait une refsection à chaque \section.  Le processeur CSL d'Org
;; ne connaît que des sous-bibliographies filtrées (:filter PRÉDICAT).  Avant
;; l'analyse, on relève les clés citées dans chaque section de premier niveau
;; qui contient un #+print_bibliography:, on fabrique un prédicat qui ne
;; retient que ces clés, et on l'ajoute au mot-clé.  Avec :heading, un titre
;; « Références » (\refname de babel) précède la liste, composée dans
;; l'environnement bibliographieua du préambule.
;;
;; Le prédicat reçoit les variables CSL de l'entrée : son identifiant (`id')
;; n'y figure que pour une bibliographie CSL-JSON.  citeproc-el n'en pose pas
;; sur les entrées converties depuis BibTeX : d'où le CSL-JSON côté Org.
;; Numérotation : continue sur tout le document (propre à CSL).

(defvar my/pdfua--section-counter 0
  "Counter used to name the per-section bibliography predicates.")

(defun my/pdfua--cited-keys (beg end)
  "Return the citation keys cited between BEG and END."
  (let (keys)
    (save-excursion
      (goto-char beg)
      (while (re-search-forward "\\[cite[^]:]*:\\([^]]*\\)\\]" end t)
        (let ((body (match-string 1)) (pos 0))
          (while (string-match "@\\([^];[:space:]]+\\)" body pos)
            (cl-pushnew (match-string 1 body) keys :test #'equal)
            (setq pos (match-end 0))))))
    (nreverse keys)))

(defun my/pdfua-bibliographies-par-section (backend)
  "Restrict each section's #+print_bibliography: to the keys cited there.
Only for the PDF/UA BACKEND."
  (when (org-export-derived-backend-p backend 'pdfua)
    (setq my/pdfua--section-counter 0)
    (save-excursion
      (goto-char (point-min))
      (let ((case-fold-search t))
        (while (re-search-forward "^\\* " nil t)
          (let* ((beg (line-beginning-position))
                 ;; Marqueur : la borne suit les insertions.
                 (end (copy-marker
                       (save-excursion
                         (if (re-search-forward "^\\* " nil t)
                             (line-beginning-position)
                           (point-max)))))
                 (keys (my/pdfua--cited-keys beg end)))
            (save-excursion
              (goto-char beg)
              (while (re-search-forward
                      "^\\([ \t]*\\)#\\+print_bibliography:\\(.*\\)$" end t)
                (let* ((indent (match-string 1))
                       (props (match-string 2))
                       (fn (intern (format "my/pdfua--bibliographie-%d"
                                           (cl-incf my/pdfua--section-counter))))
                       (ks keys))
                  (defalias fn (lambda (vars) (member (alist-get 'id vars) ks))
                    "Per-section bibliography predicate, generated at export.")
                  (end-of-line)
                  (insert (format " :filter %s" fn))
                  (forward-line 0)
                  (when (string-match-p ":heading" props)
                    (insert indent "#+LATEX: \\subsection*{\\refname}\n"))
                  ;; Environnement du préambule : police et point d'accroche
                  ;; (cslbibliography n'existe qu'à partir d'Org 9.8).
                  (insert indent "#+LATEX: \\begin{bibliographieua}\n")
                  ;; Repartir après le mot-clé, sans quoi la recherche
                  ;; suivante le retrouverait indéfiniment.
                  (end-of-line)
                  (insert "\n" indent "#+LATEX: \\end{bibliographieua}"))))
            (set-marker end nil)))))))

(add-hook 'org-export-before-parsing-functions
          #'my/pdfua-bibliographies-par-section)

;;;; SORTIE FINALE : BROUILLON ET CODE EN LIGNE
(defun my/pdfua--dedupe-graphics-width (output)
  "Keep only the first width= key of each \\includegraphics in OUTPUT.
With #+ATTR_LATEX: :options width=…, Org still appends its default
width after the user's one, and the last key wins in graphicx."
  (replace-regexp-in-string
   "\\\\includegraphics\\[\\([^]]*\\)\\]"
   (lambda (m)
     ;; `replace-regexp-in-string' remplace avec les données de
     ;; correspondance en cours : `split-string' ne doit pas les écraser.
     (save-match-data
       (let* ((seen nil)
              (kept (seq-remove
                     (lambda (o)
                       (and (string-match-p "\\`[ \t]*width[ \t]*=" o)
                            (prog1 seen (setq seen t))))
                     (split-string (match-string 1 m) ","))))
         (concat "\\includegraphics[" (string-join kept ",") "]"))))
   output t t))

(defun my/pdfua-final-output (output _backend info)
  "Adjust the LaTeX OUTPUT of a PDF/UA export according to INFO.
Declare \\uacodeinline when the document uses inline code, so that the
preamble loads lua-ul only then; in draft mode (:ua-draft), drop PDF/UA
tagging from \\DocumentMetadata to compile faster."
  (when (string-match-p "\\\\CodeInline{" output)
    (setq output (replace-regexp-in-string
                  "^\\\\documentclass.*$" "\\&\n\\\\def\\\\uacodeinline{}"
                  output nil nil nil)))
  (setq output (my/pdfua--dedupe-graphics-width output))
  ;; Le style CSL précède l'appel d'une espace insécable (« texte [1] ») ;
  ;; écrit « texte [cite:@clé] » dans Org, cela ferait un double blanc.
  (setq output (replace-regexp-in-string "[ \t]+ " " " output t t))
  (when (plist-get info :ua-draft)
    (setq output (replace-regexp-in-string
                  ",[ \t\n]*\\(?:pdfstandard=ua-2\\|testphase=phase-III\\)" ""
                  output t t)))
  output)

;;;; BACKEND PDF/UA
;; Backend dérivé de `latex' : les filtres propres à cette chaîne ne touchent
;; ni l'export LaTeX standard ni Beamer.  Menu : C-c C-e u.

(org-export-define-derived-backend 'pdfua 'latex
  :menu-entry
  '(?u "Export PDF/UA (LuaLaTeX)"
       ((?l "Fichier .tex" my/pdfua-export-to-latex)
        (?p "PDF" my/pdfua-export-to-pdf)
        (?o "PDF et ouvrir"
            (lambda (a s v b)
              (if a (my/pdfua-export-to-pdf t s v b)
                (org-open-file (my/pdfua-export-to-pdf nil s v b)))))
        (?d "PDF brouillon (sans balisage)" my/pdfua-export-draft-to-pdf)))
  :options-alist
  '((:latex-class "LATEX_CLASS" nil "article-ua" t)
    (:ua-draft nil "ua-draft" nil))
  :filters-alist
  '((:filter-code . my/org-latex-inline-code)
    (:filter-inline-src-block . my/org-latex-inline-code)
    (:filter-final-output . my/pdfua-final-output)))

;;;###autoload
(defun my/pdfua-export-to-latex
    (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to a PDF/UA LaTeX file.
ASYNC, SUBTREEP, VISIBLE-ONLY, BODY-ONLY and EXT-PLIST are as in
`org-latex-export-to-latex'."
  (interactive)
  (org-export-to-file 'pdfua (org-export-output-file-name ".tex" subtreep)
    async subtreep visible-only body-only ext-plist))

;;;###autoload
(defun my/pdfua-export-to-pdf
    (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to a tagged PDF/UA-2 file through LuaLaTeX.
ASYNC, SUBTREEP, VISIBLE-ONLY, BODY-ONLY and EXT-PLIST are as in
`org-latex-export-to-pdf'.  Return the PDF file name."
  (interactive)
  (org-export-to-file 'pdfua (org-export-output-file-name ".tex" subtreep)
    async subtreep visible-only body-only ext-plist
    #'org-latex-compile))

;;;###autoload
(defun my/pdfua-export-draft-to-pdf
    (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to an untagged draft PDF, faster to compile.
ASYNC, SUBTREEP, VISIBLE-ONLY, BODY-ONLY and EXT-PLIST are as in
`my/pdfua-export-to-pdf'."
  (interactive)
  (my/pdfua-export-to-pdf async subtreep visible-only body-only
                          (plist-put (copy-sequence ext-plist) :ua-draft t)))

(provide 'my-export-config)
;;; my-export-config.el ends here 


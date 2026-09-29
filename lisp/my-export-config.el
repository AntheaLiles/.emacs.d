;;; my-export-config.el --- Shared Org export configuration -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Source unique de vérité pour l'export Org → PDF.
;; Chargé par init.el (via with-eval-after-load 'ox-latex)
;; et par my-export-async.el (directement).
;;
;; Prérequis :
;;   - org, ox-latex chargés
;;   - Variable `my/bibliography-files' définie via my-paths.el

;;; Code:

;;;; FICHIERS LATEX DU DÉPÔT
;; Dérivés de `user-emacs-directory' : aucun chemin ~/.emacs.d en dur.
(defconst my/latex-dir (expand-file-name "latex/" user-emacs-directory)
  "Directory holding the LaTeX preamble and latexmk configuration.")

(defconst my/latex-preamble-file
  (expand-file-name "preamble-article.tex" my/latex-dir)
  "LaTeX preamble inserted by the \"article\" export class.")

(defconst my/latexmkrc-file (expand-file-name "latexmkrc" my/latex-dir)
  "Configuration file passed to latexmk with -r.")

;;;; PIPELINE LUALATEX
(setopt org-latex-compiler "lualatex"
        org-latex-pdf-process
        (list (concat "latexmk -lualatex -shell-escape -interaction=nonstopmode"
                      " -f -output-directory=%o -r "
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
;; rendues explicites (\ ), pour ne pas être fusionnées.

(defconst my/org-latex-inline-code-regexp
  (concat "\\`\\(?:\\\\texttt\\|\\\\Verb\\(?:\\[[^]]*\\]\\)?\\)"
          "{\\(\\(?:.\\|\n\\)*\\)}\\([ \t\n]*\\)\\'")
  "Match ox-latex output for inline code: \\texttt{…} or \\Verb[…]{…}.
Group 1 is the code, group 2 the trailing blanks added by the exporter.")

(defun my/org-export--latex-backend-p (backend)
  "Non-nil if BACKEND, a backend structure or name, derives from `latex'.
Unlike `org-export-derived-backend-p', follow parents given as backend
structures, not only as names: since Org 9.7, section titles are exported
through `org-latex--section-no-footnote-backend', an anonymous backend
whose parent is itself an anonymous structure."
  (let ((b backend) found)
    (while (and b (not found))
      (when (symbolp b) (setq b (org-export-get-backend b)))
      (when b
        (if (eq (org-export-backend-name b) 'latex)
            (setq found t)
          (setq b (org-export-backend-parent b)))))
    found))

(defun my/org-latex-inline-code (text _backend info)
  "Rewrap inline code TEXT in \\CodeInline for LaTeX exports.
Used as a filter on `code' and `inline-src-block' objects.  The backend
is read from INFO: in titles, the name passed as second argument is nil."
  (if (and (my/org-export--latex-backend-p (plist-get info :back-end))
           (string-match my/org-latex-inline-code-regexp text))
      (let ((code (match-string 1 text))
            (blanks (match-string 2 text)))
        (concat "\\CodeInline{"
                (replace-regexp-in-string " " "\\ " code t t)
                "}" blanks))
    text))

(add-to-list 'org-export-filter-code-functions #'my/org-latex-inline-code)
(add-to-list 'org-export-filter-inline-src-block-functions
             #'my/org-latex-inline-code)

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
(add-to-list 'org-latex-classes
             `("article"
               ,(concat "\\DocumentMetadata{lang=fr,pdfversion=2.0,pdfstandard=ua-2,
                                   testphase=phase-III}
                \\documentclass[a4paper,11pt]{article}
                \\newcommand{\\emacsdir}{" user-emacs-directory "}
                \\input{" my/latex-preamble-file "}
               [NO-DEFAULT-PACKAGES]
               [PACKAGES]
               [EXTRA]")
               ("\\section{%s}" . "\\section*{%s}")
               ("\\subsection{%s}" . "\\subsection*{%s}")
               ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
               ("\\paragraph{%s}" . "\\paragraph*{%s}")
               ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

;;;; CITATIONS
(setopt org-cite-global-bibliography my/bibliography-files
        org-cite-export-processors '((latex biblatex) (t csl)))

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
  "Convertit les [rmq:texte] en remarques marginales pour les exports LaTeX.
BACKEND est le backend d'export."
  (when (org-export-derived-backend-p backend 'latex)
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
            (insert "@@latex:}@@")
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
  (when (org-export-derived-backend-p backend 'latex)
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
                                 (format "@@latex:\\%s{@@%s@@latex:}@@"
                                         (cdr paire) v)
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
              "\\[\\[\\(?:file:\\)?\\([^]]*\\.drawio\\)\\]\\]" nil t)
        ;; Positions relevées tout de suite : les appels qui suivent
        ;; (processus externe, messages) peuvent écraser les données de match.
        (let* ((link-beg (match-beginning 0))
               (link-end (match-end 0))
               (drawio-file (match-string 1))
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
          (insert "[[" pdf-link "]]"))))))

(add-hook 'org-export-before-parsing-functions #'my/org-convert-drawio)

(provide 'my-export-config)
;;; my-export-config.el ends here 


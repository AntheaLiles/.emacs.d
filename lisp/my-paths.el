;;; my-paths.el --- Centralized paths -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Source unique de vérité pour tous les chemins du projet.
;; Chargé en premier par init.el et par my-export-async.el.
;; Aucun autre fichier ne doit définir ces chemins en dur.

;;; Code:

;;;; CHEMINS PRINCIPAUX
(defvar my/wiki-path (expand-file-name "~/wiki")
  "Répertoire racine du wiki et des travaux de recherche.")

(defvar my/resources-path (expand-file-name "00.resources" my/wiki-path)
  "Répertoire des ressources partagées du wiki (bibliographie, CSL, notes).")

(defvar my/bibliography-files (list (expand-file-name "references.json" my/resources-path))
  "Bibliographies CSL-JSON (export Better CSL JSON de Zotero) : Org-cite et Citar.
Le CSL-JSON porte l'identifiant de chaque entrée, dont dépendent les
bibliographies par section de l'export PDF/UA.")

(defvar my/bibtex-files (list (expand-file-name "references.bib" my/resources-path))
  "Bibliographies BibTeX, gardées synchronisées pour AUCTeX et RefTeX.")

(defvar my/zotero-storage '("/mnt/c/Users/CPIERRE/Documents/My Library/storage")
  "Répertoire de stockage Zotero pour les PDF des références.")

(defvar my/glossary-file (expand-file-name "glossary.org" my/resources-path)
  "Fichier glossaire Org pour org-glossary.")

(defvar my/notes-path (expand-file-name "notes" my/resources-path)
  "Répertoire des notes de lecture (org-noter, citar).")

(defvar my/zotero-styles-dir (expand-file-name "csl" my/resources-path)
  "Répertoire des styles CSL installés via Zotero.")

(defvar my/csl-locales-dir (expand-file-name "csl-locales" my/resources-path)
  "Répertoire des locales CSL (clone de citation-style-language/locales).")

;;;; PATH ELAN (Lean 4)
;; elan installe lean et lake dans ~/.elan/bin et ne modifie que le profil du
;; shell : un Emacs lancé hors d'un terminal (menu WSLg, raccourci) ne le voit
;; pas, et lean4-mode ne trouve alors pas « lake serve ».
(let ((elan-bin (expand-file-name ".elan/bin" "~")))
  (when (and (file-directory-p elan-bin) (not (member elan-bin exec-path)))
    (add-to-list 'exec-path elan-bin)
    (setenv "PATH" (concat elan-bin path-separator (getenv "PATH")))))

;;;; PATH NODE.JS (nvm)
;; Ajoute uniquement la version Node la plus récente au PATH.
;; Tri par numéro de version et non alphabétique : sinon v9.x passerait
;; après v18.x et serait retenue à tort.
(let ((nvm-dir (expand-file-name ".nvm/versions/node" "~")))
  (when (file-directory-p nvm-dir)
    (when-let* ((versions
                 (sort (directory-files nvm-dir t "\\`v[0-9]")
                       (lambda (a b)
                         (version< (substring (file-name-nondirectory a) 1)
                                   (substring (file-name-nondirectory b) 1)))))
                (bin (expand-file-name "bin" (car (last versions))))
                ((file-directory-p bin)))
      (add-to-list 'exec-path bin)
      (setenv "PATH" (concat bin path-separator (getenv "PATH"))))))

;;;; TREE-SITTER GRAMMAIRES
(when (fboundp 'treesit-available-p)
  (add-to-list 'treesit-extra-load-path
               (expand-file-name "tree-sitter" user-emacs-directory)))

(provide 'my-paths)
;;; my-paths.el ends here

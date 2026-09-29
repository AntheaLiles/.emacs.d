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
  "Répertoire racine du wiki et des travaux de recherche.")

(defvar my/bibliography-files (list (expand-file-name "references.bib" my/resources-path))
  "Fichiers bibliographiques pour Org-cite et Citar.")

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

;;;; PATH NODE.JS (nvm)
;; Ajoute uniquement la version Node la plus récente au PATH
;; (les versions sont triées alphabétiquement, la dernière = plus récente)
(let ((nvm-dir (expand-file-name ".nvm/versions/node" "~")))
  (when (file-directory-p nvm-dir)
    (let ((versions (directory-files nvm-dir t "^v[0-9]")))
      (when versions
        (let ((bin (expand-file-name "bin" (car (last versions)))))
          (when (file-directory-p bin)
            (add-to-list 'exec-path bin)
            (setenv "PATH" (concat bin ":" (getenv "PATH")))))))))

;;;; TREE-SITTER GRAMMAIRES
(when (fboundp 'treesit-available-p)
  (add-to-list 'treesit-extra-load-path
               (expand-file-name "tree-sitter" user-emacs-directory)))

(provide 'my-paths)
;;; my-paths.el ends here

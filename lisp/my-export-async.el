;;; my-export-async.el --- Init for async Org export -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Chargé par le processus Emacs en arrière-plan lors de l'export
;; asynchrone (C-c C-e l o / C-c C-e l p).
;; Le processus async ne charge PAS init.el.
;;
;; Les chemins proviennent de my-paths.el (source unique de vérité).

;;; Code:

;;;; LOAD PATH — paquets Elpaca
(let ((builds-dir (expand-file-name "elpaca/builds/" user-emacs-directory)))
  (when (file-directory-p builds-dir)
    (dolist (dir (directory-files builds-dir t "^[^.]"))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

;;;; LOAD PATH — modules maison
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;;;; CHEMINS
(require 'my-paths)

;;;; DÉPENDANCES
(require 'org)
(require 'ox-latex)

;;;; CONFIGURATION D'EXPORT PARTAGÉE
;; Inclut le filtre des titres :ignore:, les autres filtres de pré-analyse
;; et le choix du rendu des blocs source (engraved, ou verbatim en repli).
(require 'my-export-config)

;;;; ORG-GLOSSARY (optionnel — ne crash pas si absent)
(require 'org-glossary nil t)

(provide 'my-export-async)
;;; my-export-async.el ends here

;;; my-formatting.el --- Format on save -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Nettoyage et formatage automatique à la sauvegarde.
;;
;; Précaution : les actions ne s'exécutent que lors d'une sauvegarde
;; explicite (C-x C-s / M-x save-buffer), PAS lors des sauvegardes
;; automatiques de `auto-save-visited-mode' (toutes les 2s).
;; Cela évite que les espaces en fin de ligne disparaissent
;; pendant la frappe, et que eglot-format bloque l'interface.

;;; Code:

;;;; TRAILING WHITESPACE
;; Sauvegarde manuelle uniquement
(defun my/cleanup-on-save ()
  "Delete trailing whitespace on explicit save only.
Skips cleanup during `auto-save-visited-mode' automatic saves."
  (when (eq this-command 'save-buffer)
    (delete-trailing-whitespace)))

(add-hook 'before-save-hook #'my/cleanup-on-save)

;;;; EGLOT FORMAT
;; Sauvegarde manuelle uniquement
(defun my/eglot-format-on-save ()
  "Format buffer via Eglot on manual save, if Eglot is active."
  (when (and (eq this-command 'save-buffer)
             (bound-and-true-p eglot--managed-mode))
    (eglot-format-buffer)))

(add-hook 'before-save-hook #'my/eglot-format-on-save)

(provide 'my-formatting)
;;; my-formatting.el ends here

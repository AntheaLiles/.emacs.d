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

;;;; LOAD PATH
(let ((builds-dir (expand-file-name "elpaca/builds/" user-emacs-directory)))
  (when (file-directory-p builds-dir)
    (dolist (dir (directory-files builds-dir t "^[^.]"))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

;;;; LOAD PATH
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;;;; CHEMINS
(require 'my-paths)

;;;; DÉPENDANCES
(require 'org)
(require 'ox-latex)

(unless (require 'engrave-faces-latex nil t)
  (message "ATTENTION : engrave-faces-latex absent — bascule sur le rendu verbatim")
  (with-eval-after-load 'ox-latex
    (setopt org-latex-src-block-backend 'verbatim)))

;;;; FILTRE :IGNORE: CUSTOM (remplace ox-extra — T-02)
(with-eval-after-load 'ox
  (defun my/org-export-ignore-headlines (_backend)
  "Remove headlines tagged :ignore: but keep their contents.
Les positions sont RELEVÉES d'abord, puis supprimées en ordre décroissant :
supprimer de la fin vers le début est ce qui évite le décalage."
  (org-with-wide-buffer
   (let (positions)
     (org-map-entries
      (lambda ()
        (when (member "ignore" (org-get-tags nil t))
          (push (point) positions))))
     (dolist (p (sort positions #'>))
       (goto-char p)
       (delete-region (line-beginning-position) (line-beginning-position 2))))))
  (add-hook 'org-export-before-processing-hook
            #'my/org-export-ignore-headlines))

;;;; CONFIGURATION D'EXPORT PARTAGÉE
(require 'my-export-config)

;;;; ORG-GLOSSARY (optionnel — ne crash pas si absent)
(require 'org-glossary nil t)

(provide 'my-export-async)
;;; my-export-async.el ends here

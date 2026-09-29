;;; my-citar-noter.el --- Citar ↔ org-noter bridge -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Pont entre citar et org-noter :
;;   - `my/citar-open-pdf-with-noter' ouvre le document attaché à une
;;     référence et lance org-noter dessus (C-c n P, voir init.el) ;
;;   - la gestion des notes reste confiée à la source de notes par défaut
;;     de citar (`citar-notes-paths').

;;; Code:

(declare-function citar-get-files "citar" (&optional citekey-or-citekeys))
(declare-function citar-select-ref "citar" (&key filter))
(declare-function citar-has-files "citar" ())
(declare-function org-noter "org-noter" (&optional arg))

(defconst my/citar-noter-extensions '("pdf" "epub" "djvu")
  "File extensions that `org-noter' can annotate.")

(defun my/citar-noter--documents (key)
  "Return the files attached to KEY that `org-noter' can open."
  ;; `citar-get-files' rend une table de hachage clé → liste de fichiers.
  (seq-filter (lambda (f)
                (member (downcase (or (file-name-extension f) ""))
                        my/citar-noter-extensions))
              (gethash key (citar-get-files key))))

(defun my/citar-open-pdf-with-noter (key)
  "Open the document attached to citation KEY and start `org-noter' on it.
Interactively, prompt for KEY among references that have files."
  (interactive
   (progn (require 'citar)
          ;; Prédicat indexé de citar : rapide même sur une grosse .bib.
          (list (citar-select-ref :filter (citar-has-files)))))
  (require 'citar)
  (let* ((files (my/citar-noter--documents key))
         (file (if (cdr files)
                   (completing-read "Document : " files nil t)
                 (car files))))
    (unless file
      (user-error "No PDF, EPUB or DjVu attached to citation key: %s" key))
    (find-file file)
    (org-noter)))

(provide 'my-citar-noter)
;;; my-citar-noter.el ends here

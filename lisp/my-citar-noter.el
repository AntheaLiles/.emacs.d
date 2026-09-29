;;; my-citar-noter.el --- Citar ↔ org-noter bridge -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Deux fonctions distinctes :
;;   - my/citar-open-pdf-with-noter : ouvre le PDF et lance org-noter
;;   - la gestion des notes reste confiée à citar (citar-notes-paths)
;;; Code:

(declare-function citar-get-files "citar")
(declare-function org-noter "org-noter")

(defun my/citar-open-pdf-with-noter (key &optional _entry)
  "Open the PDF attached to KEY and start `org-noter' on it.
Interactively, prompt for a citation KEY."
  (interactive (list (citar-select-ref)))
  (if-let* ((files (citar-get-files key))
            (file  (if (cdr files)
                       (completing-read "Open file: " files nil t)
                     (car files))))
      (progn (find-file file) (org-noter))
    (user-error "No attached file for citation key: %s" key)))

(provide 'my-citar-noter)
;;; my-citar-noter.el ends here

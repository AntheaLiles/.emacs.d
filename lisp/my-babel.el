;;; my-babel.el --- Org Babel languages -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Langages Babel, déclarés à un seul endroit pour les deux processus qui
;; exécutent des blocs : la session interactive (init.el) et le processus
;; d'export asynchrone (my-export-async.el), qui ne lit pas init.el.
;;
;; Org ne charge PAS ob-LANG à la demande : un langage absent de
;; `org-babel-load-languages' fait échouer C-c C-c (« No org-babel-execute
;; function »), et à l'export un bloc :exports results disparaissait sans
;; erreur.

;;; Code:

(require 'org)

(defconst my/org-babel-languages
  '(emacs-lisp python R shell calc lua)
  "Babel languages always loaded.")

(defconst my/org-babel-optional-languages
  '(mermaid)
  "Babel languages loaded only when their ob- library is installed.")

(defun my/org-babel-setup ()
  "Load every language of `my/org-babel-languages' and the available optional ones."
  (let ((langs (append my/org-babel-languages
                       (seq-filter (lambda (l) (locate-library (format "ob-%s" l)))
                                   my/org-babel-optional-languages))))
    (org-babel-do-load-languages
     'org-babel-load-languages
     (mapcar (lambda (l) (cons l t)) langs))))

(my/org-babel-setup)

(provide 'my-babel)
;;; my-babel.el ends here

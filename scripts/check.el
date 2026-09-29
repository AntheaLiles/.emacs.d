;;; check.el --- Static checks for this configuration -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Vérifications statiques, sans installer aucun paquet :
;;   1. équilibre des parenthèses de tous les fichiers Emacs Lisp ;
;;   2. compilation à octets des modules de lisp/ et perf/, dans un
;;      répertoire temporaire (aucun .elc n'est écrit dans le dépôt).
;;
;; Seules les ERREURS font échouer le script : les avertissements
;; (paquets absents en CI, fonctions d'Emacs 31…) sont affichés mais
;; tolérés.  init.el et early-init.el ne sont pas compilés : ils
;; dépendent d'Elpaca et ne sont jamais compilés en usage réel
;; (user-lisp ne compile que lisp/).
;;
;; Usage, depuis la racine du dépôt :
;;   emacs -Q --batch -l scripts/check.el

;;; Code:

(require 'cl-lib)
(require 'bytecomp)

(defvar my/check-root
  (file-name-as-directory
   (expand-file-name ".." (file-name-directory
                           (or load-file-name buffer-file-name))))
  "Root of the repository.")

(defvar my/check-failures nil
  "List of (FILE . MESSAGE) failures.")

(defun my/check--files (&rest dirs)
  "Return the .el files directly under DIRS, relative to the repository root."
  (cl-loop for dir in dirs
           for abs = (expand-file-name dir my/check-root)
           when (file-directory-p abs)
           append (directory-files abs t "\\`[^.#].*\\.el\\'")))

(defun my/check-parens (file)
  "Signal a failure if FILE has unbalanced parentheses."
  (with-temp-buffer
    (insert-file-contents file)
    (emacs-lisp-mode)
    (condition-case err
        (check-parens)
      (error
       (push (cons file (format "parenthèses : %s" (error-message-string err)))
             my/check-failures)))))

(defun my/check-compile (file outdir)
  "Byte-compile FILE into OUTDIR; record a failure on error."
  (let ((byte-compile-dest-file-function
         (lambda (src)
           (expand-file-name (concat (file-name-base src) ".elc") outdir)))
        (byte-compile-error-on-warn nil))
    (condition-case err
        (unless (byte-compile-file file)
          (push (cons file "compilation : échec (voir ci-dessus)")
                my/check-failures))
      (error
       (push (cons file (format "compilation : %s" (error-message-string err)))
             my/check-failures)))))

(let* ((all (append (list (expand-file-name "early-init.el" my/check-root)
                          (expand-file-name "init.el" my/check-root))
                    (my/check--files "lisp" "perf" "scripts" "tests")))
       (modules (my/check--files "lisp" "perf"))
       (outdir (make-temp-file "emacs-d-check-" t))
       ;; Aucune écriture dans le dépôt, ni dans ~/.emacs.d réel.
       (user-emacs-directory (file-name-as-directory outdir))
       (load-path (cons (expand-file-name "lisp" my/check-root) load-path)))
  (unwind-protect
      (progn
        (message "== Parenthèses (%d fichiers)" (length all))
        (mapc #'my/check-parens all)
        (message "== Compilation à octets (%d modules)" (length modules))
        (dolist (f modules)
          (message "-- %s" (file-relative-name f my/check-root))
          (my/check-compile f outdir)))
    (delete-directory outdir t)))

(if (null my/check-failures)
    (progn (message "== OK") (kill-emacs 0))
  (dolist (f (nreverse my/check-failures))
    (message "ÉCHEC %s — %s" (file-relative-name (car f) my/check-root) (cdr f)))
  (kill-emacs 1))

;;; check.el ends here

;;; my-config-test.el --- Tests for the configuration modules -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Tests des modules de lisp/ hors export : déplacement de lignes
;; (my-editing), repliement (my-folding), langages Babel (my-babel),
;; vérificateur de dépendances (my-deps), garde d'Eglot (init.el).
;; Les tests qui dépendent d'Emacs 31 sont ignorés sur une version
;; antérieure ; la CI les exécute sous 31.1.
;;
;; Usage, depuis la racine du dépôt :
;;   emacs -Q --batch -L lisp -l tests/my-config-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)

(defconst my/test--root
  (file-name-as-directory
   (expand-file-name ".." (file-name-directory
                           (or load-file-name buffer-file-name))))
  "Root of the repository.")

(let ((user-emacs-directory my/test--root)
      ;; my-editing crée ses répertoires backups/ et auto-save/ : ailleurs
      (temporary-file-directory (make-temp-file "cfg-test-" t)))
  (let ((user-emacs-directory (file-name-as-directory temporary-file-directory)))
    (require 'my-editing))
  (require 'my-paths)
  (require 'my-folding)
  (require 'my-deps))

;;;; Déplacement de lignes (remplace move-text)

(defmacro my/test--with-lines (text &rest body)
  "Run BODY in a buffer holding TEXT, point after the first `|' (removed)."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,text)
     (goto-char (point-min))
     (search-forward "|")
     (delete-char -1)
     ,@body))

(ert-deftest my/move-line-down-and-up ()
  "The current line moves, and point stays on it at the same column."
  (my/test--with-lines "un\nd|eux\ntrois\n"
    (my/move-lines-down 1)
    (should (equal (buffer-string) "un\ntrois\ndeux\n"))
    (should (equal (thing-at-point 'line t) "deux\n"))
    (should (= (current-column) 1))
    (my/move-lines-up 2)
    (should (equal (buffer-string) "deux\nun\ntrois\n"))))

(ert-deftest my/move-line-at-edges ()
  "Moving past the first or last line is a no-op."
  (my/test--with-lines "|un\ndeux\n"
    (my/move-lines-up 1)
    (should (equal (buffer-string) "un\ndeux\n")))
  (my/test--with-lines "un\n|deux\n"
    (my/move-lines-down 1)
    (should (equal (buffer-string) "un\ndeux\n"))))

(ert-deftest my/move-last-line-without-newline ()
  "The last line, without final newline, moves up cleanly."
  (my/test--with-lines "un\ndeux\ntr|ois"
    (my/move-lines-up 1)
    (should (equal (buffer-string) "un\ntrois\ndeux\n"))))

(ert-deftest my/move-region-lines ()
  "All the lines spanned by the region move, and the region stays active."
  (with-temp-buffer
    (transient-mark-mode 1)
    (insert "a\nb\nc\nd\n")
    (goto-char (point-min))
    (forward-line 1)                    ; début de « b »
    (set-mark (point))
    (forward-line 1) (end-of-line)      ; fin de « c »
    (activate-mark)
    (my/move-lines-down 1)
    (should (equal (buffer-string) "a\nd\nb\nc\n"))
    (should (region-active-p))
    (should (equal (buffer-substring (region-beginning) (region-end)) "b\nc"))))

;;;; Repliement

(ert-deftest my/folding-latex-environments ()
  "\\begin/\\end pairs are matched, nested ones and comments included."
  (with-temp-buffer
    (latex-mode)
    (insert "\\begin{a}\n% \\end{a} dans un commentaire\n\\begin{b}\nx\n\\end{b}\n\\end{a}\nsuite")
    (goto-char (point-min))
    (my/folding-latex-forward-environment)
    (should (looking-back (regexp-quote "\\end{a}") nil))
    (goto-char (point-min))
    (search-forward "\\begin{b}")
    (goto-char (match-beginning 0))
    (my/folding-latex-forward-environment)
    (should (looking-back (regexp-quote "\\end{b}") nil))))

(ert-deftest my/folding-latex-unbalanced ()
  "An unterminated environment signals `scan-error'."
  (with-temp-buffer
    (latex-mode)
    (insert "\\begin{a}\nx\n")
    (goto-char (point-min))
    (should-error (my/folding-latex-forward-environment) :type 'scan-error)))

(ert-deftest my/folding-latex-headings ()
  "LaTeX sectioning commands and %%% comments are outline headings."
  (with-temp-buffer
    (latex-mode)
    (my/outline-setup-latex)
    (insert "%%% 01. Préambule\n\\section{Titre}\ntexte\n")
    (goto-char (point-min))
    (should (outline-on-heading-p))
    (should (= (funcall outline-level) 3))
    (forward-line 1)
    (should (outline-on-heading-p))
    (should (= (funcall outline-level) 3))
    (forward-line 1)
    (should-not (outline-on-heading-p))))

(ert-deftest my/folding-tab-indents-inside-code ()
  "TAB keeps indenting on a line that opens a block (Emacs 31).
Regression: TAB folded any line opening a block, i.e. nearly every
Lisp line, instead of indenting it."
  (skip-unless (boundp 'hs-cycle-filter))
  (with-temp-buffer
    (emacs-lisp-mode)
    (my/folding-mode 1)
    (insert "(defun f ()\n(let ((x 1))\nx))\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (eq (key-binding (kbd "TAB")) #'indent-for-tab-command))
    (should-not hs-cycle-filter)))

(ert-deftest my/folding-tab-cycles-headings ()
  "TAB on an Emacs Lisp section heading cycles it (native outline)."
  (skip-unless (boundp 'hs-cycle-filter))
  (with-temp-buffer
    (emacs-lisp-mode)
    (insert ";;;; Section\n(setq a 1)\n(setq b 2)\n")
    (my/folding-mode 1)
    (goto-char (point-min))
    (should (outline-on-heading-p))
    (should (memq (key-binding (kbd "TAB"))
                  '(outline-cycle outline-toggle-children)))))

;;;; Babel

(ert-deftest my/babel-languages-loaded ()
  "Python, R and shell blocks can run (their executors are defined)."
  (require 'my-babel)
  (dolist (lang '("python" "R" "shell" "emacs-lisp" "calc"))
    (should (fboundp (intern (concat "org-babel-execute:" lang))))))

(ert-deftest my/babel-shared-with-async-export ()
  "The async export init file loads the same Babel languages."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "lisp/my-export-async.el" my/test--root))
    (should (search-forward "(require 'my-babel)" nil t))))

;;;; Dépendances

(ert-deftest my/deps-report-lists-missing ()
  "A missing required executable and file are reported; present ones are not."
  (let ((my/deps-binaries '(("Absent" "sans-doute-inexistant-42" t "u" "i")
                            ("Emacs" "emacs" t "u" "i"))))
    (cl-letf (((symbol-function 'my/deps-files)
               (lambda () '(("Fichier absent" "/inexistant/x" t)
                            ("Racine" "/" t))))
              ((symbol-function 'my/deps--latex-packages) (lambda () nil))
              ((symbol-function 'my/deps--fonts) (lambda () nil)))
      (let ((r (my/deps-run)))
        (should (equal (mapcar #'car (plist-get r :required-binaries)) '("Absent")))
        (should (equal (mapcar #'car (plist-get r :required-files)) '("Fichier absent")))))))

(ert-deftest my/deps-preamble-extraction ()
  "Packages and fonts are read from the common preamble, comments excluded."
  (let* ((user-emacs-directory my/test--root)
         (pkgs (my/deps--latex-packages))
         (fonts (my/deps--fonts)))
    (should (member "fontspec" pkgs))
    (should (member "hyperref" pkgs))
    (should-not (member "biblatex" pkgs))
    (should (member "Luciole-Regular.ttf" fonts))
    (should (member "Luciole-Bold-Italic.ttf" fonts))))

(ert-deftest my/deps-no-biber ()
  "biber is no longer a dependency: bibliographies go through CSL."
  (should-not (assoc "Biber" my/deps-binaries)))

;;;; Configuration (init.el, early-init.el)

(defun my/test--file-forms (file)
  "Return the top-level forms of FILE, relative to the repository."
  (with-temp-buffer
    (insert-file-contents (expand-file-name file my/test--root))
    (let (forms)
      (condition-case nil
          (while t (push (read (current-buffer)) forms))
        (end-of-file nil))
      (nreverse forms))))

(defun my/test--use-package-names (forms)
  "Return the names of the `use-package' declarations among FORMS."
  (delq nil (mapcar (lambda (f) (and (eq (car-safe f) 'use-package) (cadr f)))
                    forms)))

(ert-deftest my/init-removed-packages ()
  "Packages replaced by built-ins are no longer declared."
  (let ((names (my/test--use-package-names (my/test--file-forms "init.el"))))
    (dolist (p '(compile-angel gcmh move-text doom-themes mood-line diredfl))
      (should-not (memq p names)))
    (dolist (p '(nerd-icons marginalia corfu cape lean4-mode))
      (should (memq p names)))))

(ert-deftest my/init-eglot-guard ()
  "Eglot starts only in file buffers, never in Org source edit buffers."
  (let* ((forms (my/test--file-forms "init.el"))
         (eglot (cl-find-if (lambda (f) (and (eq (car-safe f) 'use-package)
                                             (eq (cadr f) 'eglot)))
                            forms)))
    (should eglot)
    ;; Pas d'accroche générique à prog-mode
    (should-not (string-match-p "(prog-mode \\. my/eglot" (prin1-to-string eglot)))
    ;; La garde est définie dans :init : l'évaluer suffit à la tester
    (eval (car (cdr (memq :init eglot))) t)
    (let (started)
      (cl-letf (((symbol-function 'eglot-ensure) (lambda () (setq started t))))
        (with-temp-buffer (my/eglot-ensure-maybe))
        (should-not started)
        (with-temp-buffer
          (setq buffer-file-name "/tmp/x.lean")
          (setq-local org-src-mode t)
          (my/eglot-ensure-maybe)
          (should-not started)
          (setq-local org-src-mode nil)
          (my/eglot-ensure-maybe)
          (should started))))))

(ert-deftest my/early-init-perf-opt-in ()
  "The performance collector is loaded only on demand."
  (let ((text (with-temp-buffer
                (insert-file-contents (expand-file-name "early-init.el" my/test--root))
                (buffer-string))))
    (should (string-match-p "(when my/perf-enabled" text))
    (should-not (string-match-p "inhibit-redisplay t" text))
    (should (string-match-p "user-lisp-directory" text))))

(provide 'my-config-test)
;;; my-config-test.el ends here

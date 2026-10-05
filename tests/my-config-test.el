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
;; Avant tout `let' sur ses variables : sans quoi elles seraient liées
;; lexicalement, ce qu'Emacs 31 refuse au chargement de bytecomp.
(require 'bytecomp)

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
  (require 'my-deps)
  (require 'my-formatting)
  (require 'my-lean))

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

;;;; Sauvegarde automatique

(ert-deftest my/auto-save-visited-every-file ()
  "Visited files are saved every 2 s, whatever their location.
Regression: a 30 s interval and a predicate excluding /mnt/ (Windows
drives under WSL) left Org files unsaved, and Emacs asked to save them."
  (should (bound-and-true-p auto-save-visited-mode))
  (should (= auto-save-visited-interval 2))
  (should-not auto-save-visited-predicate))

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
Lisp line, instead of indenting it.  The line is indented: in Emacs
Lisp, a \"(\" in column 0 starts an outline heading."
  (skip-unless (boundp 'hs-cycle-filter))
  (with-temp-buffer
    (emacs-lisp-mode)
    (my/folding-mode 1)
    (insert "(defun f ()\n  (let ((x 1))\n    x))\n")
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
    (should (member "tikz" pkgs))                ; module latex/modules/tikz.tex
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

(ert-deftest my/startup-no-compilation-before-init ()
  "lisp/ is compiled after init, not before (Elpaca not yet active).
Regression: compiling the modules before init.el ran their `require's,
loaded Org before Elpaca, and `citar-org' could not be loaded."
  (let ((text (with-temp-buffer
                (insert-file-contents (expand-file-name "early-init.el" my/test--root))
                (buffer-string))))
    (should (string-match-p "user-lisp-auto-scrape nil" text))
    (should (string-match-p "(setq load-prefer-newer t)" text)))
  (let ((forms (my/test--file-forms "init.el")))
    (should (cl-find-if (lambda (f) (equal (seq-take f 2) '(defun my/user-lisp-compile)))
                        forms))
    (should (cl-find-if (lambda (f) (and (equal (seq-take f 2) '(add-hook 'elpaca-after-init-hook))
                                         (string-match-p "my/user-lisp-compile"
                                                         (prin1-to-string f))))
                        forms))
    ;; citar-org attend citar : indépendant du moment où Org est chargé
    (let ((citar-org (cl-find-if (lambda (f) (and (eq (car-safe f) 'use-package)
                                                  (eq (cadr f) 'citar-org)))
                                 forms)))
      (should (equal (cadr (memq :after citar-org)) '(:all citar (:any org oc)))))))

(ert-deftest my/export-async-init-never-compiled ()
  "The async export init file is never byte-compiled in the session.
Compiling it would run its `require's (Org, ox-latex…) in the session."
  (let ((byte-compile-dest-file-function (lambda (_) (make-temp-file "x" nil ".elc"))))
    (should (eq (byte-compile-file (expand-file-name "lisp/my-export-async.el" my/test--root))
                'no-byte-compile))))

(ert-deftest my/elpaca-dev-build-and-compat ()
  "Development builds get a core date; Emacs 31 uses its built-in compat."
  (let ((text (with-temp-buffer
                (insert-file-contents (expand-file-name "init.el" my/test--root))
                (buffer-string))))
    (should (string-match-p "(defvar elpaca-core-date" text))
    (should (string-match-p "elpaca-ignored-dependencies 'compat" text))
    ;; Avant l'amorçage d'Elpaca
    (should (< (string-match "elpaca-core-date" text)
               (string-match "elpaca-installer-version" text)))))

;;;; Lean 4 et Lake

(ert-deftest my/lake-error-regexp ()
  "Lake's \"error: FILE:L:C:\" lines are parsed, warnings told from errors."
  (should (memq 'lake compilation-error-regexp-alist))
  (let ((re (cadr (assq 'lake compilation-error-regexp-alist-alist))))
    (dolist (case '(("error: src/Mini/Basic.lean:8:20: Type mismatch" "src/Mini/Basic.lean" "8" "20" error)
                    ("warning: src/Mini/Basic.lean:10:8: declaration uses `sorry`" "src/Mini/Basic.lean" "10" "8" warning)
                    ("info: src/K7pl/Arith.lean:3:0: note" "src/K7pl/Arith.lean" "3" "0" info)))
      (should (string-match re (car case)))
      (should (equal (match-string 4 (car case)) (nth 1 case)))
      (should (equal (match-string 5 (car case)) (nth 2 case)))
      (should (equal (match-string 6 (car case)) (nth 3 case)))
      (should (eq (cond ((match-string 2 (car case)) 'warning)
                        ((match-string 3 (car case)) 'info)
                        (t 'error))
                  (nth 4 case))))
    ;; Lignes sans position, ou sorties de make : pas d'erreur factice
    (should-not (string-match re "error: build failed"))
    (should-not (string-match re "✖ [2/4] Building Mini.Basic (909ms)"))))

(ert-deftest my/lake-root-and-command ()
  "Lake runs at the project root, from any subdirectory, never in .lake/."
  (let* ((root (file-name-as-directory (make-temp-file "lake-" t)))
         (sub (expand-file-name "src/Mini/" root))
         (dep (expand-file-name ".lake/packages/dep/Dep/" root)))
    (make-directory sub t)
    (make-directory dep t)
    (with-temp-file (expand-file-name "lakefile.lean" root) (insert "import Lake"))
    (with-temp-file (expand-file-name ".lake/packages/dep/lakefile.toml" root) (insert ""))
    (should (equal (my/lake-root (expand-file-name "Basic.lean" sub)) root))
    (should (equal (my/lake-root (expand-file-name "Dep.lean" dep)) root))
    (should-not (my/lake-root (file-name-as-directory (make-temp-file "hors-lake-" t))))
    (let (seen)
      (cl-letf (((symbol-function 'compile)
                 (lambda (command &rest _) (setq seen (cons command default-directory)))))
        (with-temp-buffer
          (setq buffer-file-name (expand-file-name "Basic.lean" sub))
          (my/lake "test")
          (should (equal seen (cons "lake test" root)))))
      (with-temp-buffer
        (setq default-directory (file-name-as-directory (make-temp-file "hors-lake-" t)))
        (should-error (my/lake "build") :type 'user-error)))))

(ert-deftest my/lean-setup-buffer ()
  "Lean buffers get 100-column lines and \"lake build\" as compile command."
  (with-temp-buffer
    (my/lean-setup)
    (should (= fill-column 100))
    (should (equal compile-command "lake build"))))

(ert-deftest my/eglot-format-on-save-guarded ()
  "Format on save only when the server can; a failure never blocks the save.
Regression: Lean's server cannot format, `eglot-format-buffer' signalled
\"Server can't format\", and C-x C-s failed in every .lean file."
  (let (calls capable fails
        ;; ERT l'active ; en usage normal, with-demoted-errors capture l'erreur
        (debug-on-error nil))
    (cl-letf (((symbol-function 'eglot-server-capable) (lambda (&rest _) capable))
              ((symbol-function 'eglot-format-buffer)
               (lambda () (push t calls) (when fails (error "Server can't format!")))))
      (with-temp-buffer
        (setq-local eglot--managed-mode t)
        (let ((this-command 'save-buffer))
          (setq capable nil)
          (my/eglot-format-on-save)
          (should-not calls)                       ; serveur sans formatage
          (setq capable t)
          (my/eglot-format-on-save)
          (should (= (length calls) 1))            ; serveur qui formate
          (setq fails t)
          (my/eglot-format-on-save)                ; ne signale rien
          (should (= (length calls) 2)))
        ;; Sauvegarde automatique : jamais de formatage
        (let ((this-command 'auto-save-visited-mode))
          (my/eglot-format-on-save)
          (should (= (length calls) 2)))))))

(ert-deftest my/init-eglot-lean-and-servers ()
  "Lean starts its own Eglot; others only when their server is installed."
  (let* ((forms (my/test--file-forms "init.el"))
         (find (lambda (name)
                 (cl-find-if (lambda (f) (and (eq (car-safe f) 'use-package)
                                              (eq (cadr f) name)))
                             forms)))
         (eglot (funcall find 'eglot))
         (lean (funcall find 'lean4-mode)))
    ;; Pas de :hook sur lean4-mode côté Eglot (lean4-mode appelle eglot-ensure)
    (should-not (memq :hook eglot))
    (should-not (string-match-p "lean4-mode" (prin1-to-string (cdr (memq :init eglot)))))
    (should (string-match-p "executable-find" (prin1-to-string (cdr (memq :init eglot)))))
    (should (equal (cadr (memq :hook lean)) '(lean4-mode . my/lean-setup)))))

(ert-deftest my/paths-elan-in-exec-path ()
  "~/.elan/bin joins `exec-path' and PATH, so that \"lake serve\" is found."
  (let* ((home (file-name-as-directory (make-temp-file "home-" t)))
         (elan (expand-file-name ".elan/bin" home))
         (process-environment (cons (concat "HOME=" home) process-environment))
         (exec-path exec-path))
    (make-directory elan t)
    (setenv "PATH" "/usr/bin")
    (load (expand-file-name "lisp/my-paths.el" my/test--root) nil t t)
    (should (member elan exec-path))
    (should (string-prefix-p elan (getenv "PATH")))
    ;; Idempotent
    (let ((before (getenv "PATH")))
      (load (expand-file-name "lisp/my-paths.el" my/test--root) nil t t)
      (should (equal (getenv "PATH") before)))))

(provide 'my-config-test)
;;; my-config-test.el ends here

;;; my-deps.el --- Async dependency checker -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Vérification non-bloquante des dépendances système avec cache intelligent.
;;
;; Fonctionnement :
;;   1. Hash BLAKE3 des fichiers de config → comparaison avec le cache
;;   2. Si identique → afficher le rapport persisté (ou rien si tout OK)
;;   3. Si différent → vérification async en processus batch
;;   4. Le rapport est persisté sur disque pour les redémarrages suivants
;;
;; Commandes :
;;   M-x my/deps-check        — vérification synchrone (ignore le cache)
;;   M-x my/deps-check-async  — vérification async (respecte le cache)
;;   M-x my/deps-clear-cache  — invalider le cache
;;
;; Dépendance externe : b3sum (BLAKE3)
;;   $ cargo install b3sum   ou   $ sudo apt install b3sum

;;; Code:

(require 'cl-lib)
(require 'my-paths)

;;;; DÉCLARATION DES DÉPENDANCES

;; Format : (NOM EXÉCUTABLE REQUIS USAGE COMMANDE-INSTALL)
;; Les fonctions d'extraction dynamique complètent
;; cette liste statique au moment de la vérification.

(defvar my/deps-binaries
  '(;; Essentiels
    ("Git"       "git"       t   "magit, diff-hl, project.el"
     "sudo apt install git")
    ("hunspell"  "hunspell"  t   "flyspell — correction orthographique"
     "sudo apt install hunspell hunspell-fr hunspell-en-us")
    ("b3sum"     "b3sum"     t   "BLAKE3 hash — cache dépendances"
     "cargo install b3sum")
    ;; Pipeline LaTeX
    ("LuaLaTeX"  "lualatex"  t   "Export Org → PDF"
     "sudo apt install texlive-full")
    ("latexmk"   "latexmk"   t   "Compilation LaTeX multi-passes"
     "sudo apt install latexmk")
    ("Biber"     "biber"     t   "Bibliographie biblatex"
     "sudo apt install biber")
    ;; Recherche
    ("ripgrep"   "rg"        nil "consult-ripgrep, howm-search"
     "sudo apt install ripgrep")
    ("fd"        "fdfind"    nil "consult-find"
     "sudo apt install fd-find")
    ;; Optionnels
    ("emacs-lsp-booster" "emacs-lsp-booster" nil "Eglot JSON x3-10"
     "cargo install emacs-lsp-booster")
    ("drawio"    "drawio"    nil "Conversion .drawio → .pdf"
     "snap install drawio"))
  "Static binary dependencies. (NAME EXEC REQUIRED USAGE INSTALL).")

(defvar my/deps-files
  `(;; Requis
    ("Préambule LaTeX"  ,(expand-file-name "latex/preamble-article.tex"
                                            user-emacs-directory) t)
    ("Config latexmk"   ,(expand-file-name "latex/latexmkrc"
                                            user-emacs-directory) t)
    ("Config export"    ,(expand-file-name "lisp/my-export-config.el"
                                            user-emacs-directory) t)
    ("Init async"       ,(expand-file-name "lisp/my-export-async.el"
                                            user-emacs-directory) t)
    ("Export UI"        ,(expand-file-name "lisp/my-export-ui.el"
                                            user-emacs-directory) t)
    ;; Optionnels
    ("ORCID icon"       ,(expand-file-name "assets/ORCID-iD-icon-BW-16x16.png"
                                            user-emacs-directory) nil)
    ("Bibliographie"    ,(expand-file-name "~/wiki/00.resources/references.bib")
     nil)
    ("Glossaire"        ,my/glossary-file nil))
  "File dependencies. (DESC PATH REQUIRED).")

;;;; CACHE (BLAKE3)
(defvar my/deps--cache-dir
  (expand-file-name "deps-cache/" user-emacs-directory)
  "Cache directory for dependency checks.")

(defvar my/deps--hash-file
  (expand-file-name "config-hash" my/deps--cache-dir))

(defvar my/deps--result-file
  (expand-file-name "check-result.el" my/deps--cache-dir))

(defvar my/deps--process nil
  "Async dependency check process.")

(defun my/deps--ensure-cache-dir ()
  "Create cache directory if needed."
  (unless (file-directory-p my/deps--cache-dir)
    (make-directory my/deps--cache-dir t)))

(defun my/deps--config-files ()
  "Files whose changes should trigger a re-check."
  (nconc
   (list (expand-file-name "init.el" user-emacs-directory)
         (expand-file-name "early-init.el" user-emacs-directory)
         (expand-file-name "latex/preamble-article.tex" user-emacs-directory))
   (when-let* ((d (expand-file-name "lisp" user-emacs-directory))
               ((file-directory-p d)))
     (directory-files d t "\\.el\\'"))))

(defun my/deps--compute-hash ()
  "Compute BLAKE3 hash of all config files via b3sum.
Falls back to MD5 if b3sum is unavailable."
  (let ((files (cl-remove-if-not #'file-exists-p (my/deps--config-files))))
    (if (executable-find "b3sum")
        ;; Un seul appel b3sum avec tous les fichiers
        (with-temp-buffer
          (apply #'call-process "b3sum" nil t nil "--no-names" files)
          (md5 (buffer-string)))
      ;; Fallback : MD5 sur les métadonnées
      (md5 (mapconcat
            (lambda (f)
              (let ((a (file-attributes f)))
                (format "%s:%s:%s"
                        (file-name-nondirectory f)
                        (float-time (file-attribute-modification-time a))
                        (file-attribute-size a))))
            files "\n")))))

(defun my/deps--cache-valid-p ()
  "Return t if cached hash matches current config."
  (when-let* ((cached (and (file-exists-p my/deps--hash-file)
                           (with-temp-buffer
                             (insert-file-contents my/deps--hash-file)
                             (string-trim (buffer-string))))))
    (string= cached (my/deps--compute-hash))))

(defun my/deps--write-cache (hash results)
  "Write HASH and RESULTS to cache."
  (my/deps--ensure-cache-dir)
  (with-temp-file my/deps--hash-file (insert hash))
  (with-temp-file my/deps--result-file
    (let ((print-length nil) (print-level nil))
      (prin1 results (current-buffer)))))

(defun my/deps--read-cached-results ()
  "Read cached results from disk. Returns nil if no cache."
  (when (file-exists-p my/deps--result-file)
    (with-temp-buffer
      (insert-file-contents my/deps--result-file)
      (read (current-buffer)))))

(defun my/deps-clear-cache ()
  "Clear the dependency check cache."
  (interactive)
  (dolist (f (list my/deps--hash-file my/deps--result-file))
    (when (file-exists-p f) (delete-file f)))
  (message "Dependency cache cleared."))

;;;; EXTRACTION DYNAMIQUE
(defun my/deps--extract-lsp-servers ()
  "Extract LSP server binaries from `eglot-server-programs'."
  (when (boundp 'eglot-server-programs)
    (cl-loop for (mode . cmd) in eglot-server-programs
             for exec = (pcase cmd
                          ((pred stringp) cmd)
                          (`(,(pred stringp) . ,_) (car cmd))
                          (_ nil))
             when (and exec (not (equal exec "eglot-lsp-server")))
             collect (list (format "LSP: %s" exec) exec nil
                           (format "LSP pour %s" mode)
                           (format "Installer %s" exec)))))

(defun my/deps--extract-latex-packages ()
  "Extract \\usepackage names from preamble-article.tex."
  (let ((preamble (expand-file-name "latex/preamble-article.tex"
                                     user-emacs-directory)))
    (when (file-exists-p preamble)
      (with-temp-buffer
        (insert-file-contents preamble)
        (cl-loop while (re-search-forward
                        "\\\\usepackage\\(?:\\[[^]]*\\]\\)?{\\([^}]+\\)}"
                        nil t)
                 nconc (mapcar #'string-trim
                               (split-string (match-string 1) ",")))))))

(defun my/deps--extract-fonts ()
  "Extract font dependencies from preamble + Emacs config."
  (let ((preamble (expand-file-name "latex/preamble-article.tex"
                                     user-emacs-directory)))
    (nconc
     (when (file-exists-p preamble)
       (with-temp-buffer
         (insert-file-contents preamble)
         (cl-loop while (re-search-forward
                         "\\\\set\\(?:main\\|mono\\|math\\)font{\\([^}]+\\)}"
                         nil t)
                  collect (match-string 1))))
     (list "JetBrainsMonoNL NFP"))))

;;;; VÉRIFICATION
(defun my/deps--check-binaries (deps)
  "Check list of binary DEPS. Return (MISSING-REQ MISSING-OPT)."
  (cl-loop for (name exec req usage install) in deps
           unless (executable-find exec)
           if req collect (list name usage install) into required
           else collect (list name usage install) into optional
           finally return (list required optional)))

(defun my/deps--check-latex-packages (packages)
  "Check PACKAGES via kpsewhich. Returns list of missing."
  (when (executable-find "kpsewhich")
    (cl-remove-if
     (lambda (pkg)
       (= 0 (call-process "kpsewhich" nil nil nil (concat pkg ".sty"))))
     packages)))

(defun my/deps--check-fonts (fonts)
  "Check FONTS availability. Returns list of missing."
  (cl-remove-if
   (lambda (font)
     (if (string-match "\\.\\(otf\\|ttf\\)$" font)
         ;; Fichier — kpsewhich ou répertoires système
         (or (= 0 (call-process "kpsewhich" nil nil nil font))
             (cl-some (lambda (d) (file-exists-p (expand-file-name font d)))
                      '("~/.local/share/fonts/"
                        "/usr/share/fonts/"
                        "/usr/local/share/fonts/")))
       ;; Famille — fc-list stdout
       (not (string-empty-p
             (string-trim
              (with-temp-buffer
                (call-process "fc-list" nil t nil (concat ":family=" font))
                (buffer-string)))))))
   fonts))

(defun my/deps--check-files (deps)
  "Check file DEPS. Returns (MISSING-REQ MISSING-OPT)."
  (cl-loop for (desc path req) in deps
           unless (file-exists-p path)
           if req collect (list desc path) into required
           else collect (list desc path) into optional
           finally return (list required optional)))

(defun my/deps--run-all-checks ()
  "Run all dependency checks. Returns a plist of results."
  (let* ((all-bins (append my/deps-binaries (my/deps--extract-lsp-servers)))
         (bin-res  (my/deps--check-binaries all-bins))
         (file-res (my/deps--check-files my/deps-files)))
    (list :missing-req-bin   (car bin-res)
          :missing-opt-bin   (cadr bin-res)
          :missing-latex     (my/deps--check-latex-packages
                              (my/deps--extract-latex-packages))
          :missing-fonts     (my/deps--check-fonts
                              (delete-dups (my/deps--extract-fonts)))
          :missing-req-files (car file-res)
          :missing-opt-files (cadr file-res)
          :timestamp         (float-time)
          :emacs-version     emacs-version)))

;;;; ASYNC
(defun my/deps--start-async ()
  "Start async Emacs --batch process for dependency checking."
  (when (and my/deps--process (process-live-p my/deps--process))
    (kill-process my/deps--process))
  (my/deps--ensure-cache-dir)
  (when (file-exists-p my/deps--result-file)
    (delete-file my/deps--result-file))
  (setq my/deps--process
        (start-process
         "deps-check" " *deps-check*"
         (expand-file-name invocation-name invocation-directory)
         "-Q" "--batch" "--eval"
         (format "(progn
                    (setq user-emacs-directory %S)
                    (add-to-list 'load-path %S)
                    (require 'my-paths)
                    (require 'my-deps)
                    (let ((r (my/deps--run-all-checks)))
                      (with-temp-file %S
                        (let ((print-length nil) (print-level nil))
                          (prin1 r (current-buffer))))))"
                 user-emacs-directory
                 (expand-file-name "lisp" user-emacs-directory)
                 my/deps--result-file)))
  (set-process-sentinel my/deps--process #'my/deps--sentinel))

(defun my/deps--sentinel (_proc event)
  "Handle async PROC completion. EVENT describes the outcome."
  (setq my/deps--process nil)
  (pcase (string-trim event)
    ("finished" (my/deps--handle-results))
    (e (message "Dependency check failed: %s" e))))

(defun my/deps--handle-results ()
  "Process results from async check."
  (if (not (file-exists-p my/deps--result-file))
      (message "Dependency check produced no results")
    (let ((results (with-temp-buffer
                     (insert-file-contents my/deps--result-file)
                     (read (current-buffer)))))
      ;; Toujours persister le résultat + hash (même si deps manquantes)
      ;; pour pouvoir afficher le rapport persisté au prochain boot
      (my/deps--write-cache (my/deps--compute-hash) results)
      (if (my/deps--results-ok-p results)
          (message "All dependencies satisfied.")
        (my/deps--display-report results)))))

;;;; PRÉDICATS
(defun my/deps--results-ok-p (results)
  "Return t if RESULTS indicate no missing dependencies."
  (cl-loop for key in '(:missing-req-bin :missing-opt-bin :missing-latex
                         :missing-fonts :missing-req-files :missing-opt-files)
           never (plist-get results key)))

(defun my/deps--results-has-required-p (results)
  "Return t if RESULTS contain missing required dependencies."
  (or (plist-get results :missing-req-bin)
      (plist-get results :missing-req-files)))

;;;; AFFICHAGE
(defun my/deps--format-section (title face items formatter)
  "Format a report section with TITLE, FACE, ITEMS using FORMATTER."
  (when items
    (concat (propertize (concat title "\n\n") 'face face)
            (mapconcat formatter items "")
            "\n")))

(defun my/deps--format-binary (dep)
  "Format a binary DEP (NAME USAGE INSTALL) for display."
  (format "  x %s\n    %s\n    $ %s\n\n"
          (propertize (nth 0 dep) 'face 'error)
          (nth 1 dep)
          (propertize (nth 2 dep) 'face 'font-lock-string-face)))

(defun my/deps--format-optional-binary (dep)
  "Format an optional binary DEP for display."
  (format "  o %s\n    %s\n    $ %s\n\n"
          (propertize (nth 0 dep) 'face 'warning)
          (nth 1 dep)
          (propertize (nth 2 dep) 'face 'font-lock-string-face)))

(defun my/deps--format-file (dep)
  "Format a file DEP (DESC PATH) for display."
  (format "  x %s\n    %s\n\n"
          (propertize (nth 0 dep) 'face 'error)
          (nth 1 dep)))

(defun my/deps--display-report (results)
  "Display dependency check RESULTS in a dedicated buffer."
  (let ((buf (get-buffer-create "*Missing Dependencies*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert
         (or (my/deps--format-section
              "REQUIRED — Binaries" 'error
              (plist-get results :missing-req-bin)
              #'my/deps--format-binary) "")
         (or (my/deps--format-section
              "REQUIRED — Files" 'error
              (plist-get results :missing-req-files)
              #'my/deps--format-file) "")
         (or (my/deps--format-section
              "OPTIONAL — Binaries" 'warning
              (plist-get results :missing-opt-bin)
              #'my/deps--format-optional-binary) "")
         (or (my/deps--format-section
              "OPTIONAL — LaTeX" 'warning
              (plist-get results :missing-latex)
              (lambda (p) (format "  o %s\n" p))) "")
         (or (my/deps--format-section
              "OPTIONAL — Fonts" 'warning
              (plist-get results :missing-fonts)
              (lambda (f) (format "  o %s\n" f))) "")
         (or (my/deps--format-section
              "OPTIONAL — Files" 'warning
              (plist-get results :missing-opt-files)
              (lambda (d) (format "  o %s → %s\n"
                                  (nth 0 d) (nth 1 d)))) "")
         ;; Footer
         (propertize (make-string 50 ?-) 'face 'font-lock-comment-face)
         "\n"
         "  q : close | M-x my/deps-check : recheck\n"
         (format "  Checked: %s | Emacs %s\n"
                 (format-time-string "%Y-%m-%d %H:%M:%S"
                                     (plist-get results :timestamp))
                 (plist-get results :emacs-version))))
      (special-mode)
      (goto-char (point-min)))
    ;; Requis manquant → remplacer scratch
    (if (my/deps--results-has-required-p results)
        (progn
          (when (get-buffer "*scratch*")
            (kill-buffer "*scratch*"))
          (switch-to-buffer buf))
      (message "Optional deps missing. See M-x my/deps-check"))))

;;;; COMMANDES
(defun my/deps-check ()
  "Check all dependencies synchronously. Ignores the cache."
  (interactive)
  (let ((results (my/deps--run-all-checks)))
    (my/deps--write-cache (my/deps--compute-hash) results)
    (if (my/deps--results-ok-p results)
        (message "All dependencies satisfied.")
      (my/deps--display-report results))))

(defun my/deps-check-async ()
  "Check dependencies asynchronously, respecting the cache."
  (interactive)
  (if (my/deps--cache-valid-p)
      ;; Cache valide → afficher le rapport persisté si des deps manquent
      (let ((cached (my/deps--read-cached-results)))
        (if (or (null cached) (my/deps--results-ok-p cached))
            (message "Dependencies OK (cached)")
          (my/deps--display-report cached)))
    (message "Checking dependencies...")
    (my/deps--start-async)))

;;;; AUTO-CHECK AU DÉMARRAGE
(defun my/schedule-dep-check ()
  "Schedule dependency check 3s after startup."
  (run-with-idle-timer 3 nil #'my/deps-check-async))

(provide 'my-deps)
;;; my-deps.el ends here

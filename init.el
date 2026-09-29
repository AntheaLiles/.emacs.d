;;; init.el --- Main configuration -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Scientific Research Emacs Configuration
;; Emacs 31.1 — Vanilla, optimisé en Org-mode et LaTeX.
;;; Code:

;;;; ALWAYS DEFER PACKAGES
(setq use-package-always-defer t)

;;;; DEBUG & BENCHMARKS
;; Décommenter pour diagnostiquer les temps de chargement par package :
;; (setq use-package-compute-statistics t)
;; Puis consulter le rapport avec : M-x use-package-report

;;;; BOOTSTRAP ELPACA
(with-eval-after-load 'warnings
  (add-to-list 'warning-suppress-types '(elpaca)))
(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))
(elpaca elpaca-use-package (elpaca-use-package-mode))

;;;; CUSTOM FILE
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

;;;; MODULES COMPILABLES
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'my-paths)
(require 'my-performance)
(require 'my-editing)
(require 'my-windows)
(require 'my-appearance)
(require 'my-folding)
(require 'my-formatting)
(require 'my-export-ui)

;;;; COMPILATION AOT
(use-package compile-angel
  :ensure t
  :demand t
  :config
  (setq compile-angel-verbose nil)
  (push "/init.el" compile-angel-excluded-files)
  (push "/early-init.el" compile-angel-excluded-files)
  (push "/custom.el" compile-angel-excluded-files)
  (push "/lisp/my-export-async.el" compile-angel-excluded-files)
  (compile-angel-on-load-mode 1))

;;;; GARBAGE COLLECTOR
(use-package gcmh
  :ensure t
  :demand t
  :custom
  (gcmh-idle-delay 'auto)
  (gcmh-auto-idle-delay-factor 10)
  (gcmh-high-cons-threshold (* 128 1024 1024))
  :config
  (gcmh-mode 1))

;;;; AIDES DE REDACTION
(use-package move-text
  :ensure t
  :bind (("M-<up>"   . move-text-up)
         ("M-<down>" . move-text-down)))

(use-package multiple-cursors
  :ensure t
  :bind (("C-S-c C-S-c"   . mc/edit-lines)
         ("C-S-<mouse-1>" . mc/add-cursor-on-click)))

;;;; THÈME ET MODELINE
(use-package doom-themes
  :ensure t
  :demand t
  :config
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'doom-tomorrow-night t)
  (doom-themes-visual-bell-config)
  (doom-themes-org-config))

(use-package nerd-icons
  :ensure t)

(use-package mood-line
  :ensure t
  :hook (elpaca-after-init . mood-line-mode)
  :custom
  (mood-line-glyph-alist mood-line-glyphs-unicode))

;;;; REPLIEMENT DE CODE
(use-package outline
  :ensure nil
  :hook ((prog-mode . outline-minor-mode)
         (LaTeX-mode . outline-minor-mode)
         (markdown-ts-mode . outline-minor-mode))
  :custom
  (outline-minor-mode-cycle t)      ; TAB cycle quand le point est sur un header
  (outline-minor-mode-highlight 'append)
  (outline-blank-line t))

(use-package hideshow
  :ensure nil
  :hook (prog-mode . hs-minor-mode)
  :custom
  (hs-hide-comments-when-hiding-all nil))

;;;; BUILT-INS
(use-package which-key
  :ensure nil
  :hook (elpaca-after-init . which-key-mode)
  :custom
  (which-key-idle-delay 0.5)
  (which-key-idle-secondary-delay 0.05))

(use-package so-long
  :ensure nil
  :hook (elpaca-after-init . global-so-long-mode))

(use-package savehist
  :ensure nil
  :hook (elpaca-after-init . savehist-mode)
  :custom
  (savehist-additional-variables '(search-ring regexp-search-ring kill-ring)))

(use-package recentf
  :ensure nil
  :hook (elpaca-after-init . recentf-mode)
  :custom
  (recentf-max-saved-items 200)
  (recentf-max-menu-items 15)
  (recentf-exclude '("^/tmp/" "^/ssh:" "^/sudo:"
                     "\\.git/" "COMMIT_EDITMSG"
                     "\\.\\(?:gz\\|gif\\|svg\\|png\\|jpe?g\\)$"
                     "eln-cache" "elpaca")))

(use-package winner
  :ensure nil
  :hook (elpaca-after-init . winner-mode))

(use-package autorevert
  :ensure nil
  :hook (elpaca-after-init . global-auto-revert-mode)
  :custom
  (auto-revert-use-notify t)
  (auto-revert-avoid-polling t)
  (global-auto-revert-non-file-buffers t)
  (auto-revert-verbose nil))

(use-package ibuffer
  :ensure nil
  :bind ("C-x C-b" . ibuffer))

(use-package calc              ; Pour futures configurations
  :ensure nil
  :config)

;;;; COMPLÉTION MINIBUFFER
(use-package emacs             ; Minibuffer enhancements
  :ensure nil
  :config
  ;; Permettre l'ouverture d'un minibuffer dans un minibuffer
  ;; Nécessaire pour embark-act pendant une complétion consult
  (setopt enable-recursive-minibuffers t)
  ;; Masquer les commandes non pertinentes dans M-x
  (setopt read-extended-command-predicate
          #'command-completion-default-include-p))

(use-package vertico
  :ensure t
  :hook (elpaca-after-init . vertico-mode)
  :custom
  (vertico-scroll-margin 0)
  (vertico-count 20)
  (vertico-cycle t))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :ensure t
  :hook (elpaca-after-init . marginalia-mode))

(use-package consult
  :ensure t
  :bind (("C-x b"   . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("M-y"     . consult-yank-pop)
         ("C-s"     . consult-line)
         ("C-c s r" . consult-ripgrep)
         ("C-c s f" . consult-find)
         ("C-c s l" . consult-line)
         ("C-c s o" . consult-outline)
         ("C-c s i" . consult-imenu)
         ("M-g g"   . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("C-c f r" . consult-recent-file)))

(use-package embark
  :ensure t
  :bind (("C-."   . embark-act)
         ("C-;"   . embark-dwim)
         ("C-h B" . embark-bindings)))

(use-package embark-consult
  :ensure t
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-at-point-mode))

(use-package corfu
  :ensure t
  :hook ((elpaca-after-init . global-corfu-mode)
         (minibuffer-setup . my/corfu-enable-in-minibuffer))
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  (corfu-scroll-margin 5)
  :config
  (defun my/corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer when completion is available."
    (when (local-variable-p 'completion-at-point-functions)
      (setq-local corfu-auto nil)
      (corfu-mode 1))))

(use-package cape
  :ensure t
  :init
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  :hook (org-mode . my/cape-org-setup)
  :custom
  (cape-dabbrev-min-length 3)
  :config
  (defun my/cape-org-setup ()
    "Add cape-elisp-block completion in Org buffers."
    (add-hook 'completion-at-point-functions #'cape-elisp-block nil t)))

;;;; DÉVELOPPEMENT
(use-package eglot
  :ensure nil
  :hook (prog-mode . my/eglot-ensure-maybe)
  :bind (:map eglot-mode-map
              ("C-c l r" . eglot-rename)
              ("C-c l a" . eglot-code-actions)
              ("C-c l f" . eglot-format)
              ("C-c l d" . eldoc)
              ("C-c l h" . eglot-inlay-hints-mode))
  :custom
  (eglot-events-buffer-config '(:size 0))
  (eglot-autoshutdown t)
  (eglot-send-changes-idle-time 0.5)
  (eglot-extend-to-xref t)
  (eglot-ignored-server-capabilities
   '(:inlayHintProvider
     :documentOnTypeFormattingProvider
     :colorProvider
     :foldingRangeProvider))
  :config
  (defun my/eglot-ensure-maybe ()
    "Enable eglot unless in a mode without LSP support."
    (unless (derived-mode-p 'emacs-lisp-mode 'lisp-mode 'ebnf-mode)
      (eglot-ensure)))
  (add-to-list 'eglot-server-programs
               '(web-mode . ("typescript-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs
               '(yaml-ts-mode . ("yaml-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs
               '((bash-ts-mode) . ("bash-language-server" "start")))
  (add-to-list 'eglot-server-programs
               '(perl-ts-mode . ("perlnavigator" "--stdio")))
  (add-to-list 'eglot-server-programs
               '(lean-ts-mode . ("lean" "--server"))))

(use-package eglot-booster
  :ensure (:host github :repo "jdtsmith/eglot-booster")
  :after eglot
  :if (executable-find "emacs-lsp-booster")
  :config (eglot-booster-mode))

(use-package treesit
  :ensure nil
  :demand t
  :custom
  (treesit-auto-install-grammar 'ask)   ; 'always pour ne plus être interrogé
  (treesit-enabled-modes t))            ; ou une liste explicite de modes

(use-package magit
  :ensure t
  :demand t
  :bind ("C-x g" . magit-status)
  :commands (magit-status magit-dispatch magit-file-dispatch)
  :custom  (magit-diff-refine-hunk t))  ; diff au niveau du mot (plus précis)

(use-package ediff             ; Split horizontal, même frame
  :ensure nil
  :custom
  (ediff-split-window-function #'split-window-horizontally)
  (ediff-window-setup-function #'ediff-setup-windows-plain))
(use-package diff-hl
  :ensure t
  :hook ((elpaca-after-init  . global-diff-hl-mode)
         (magit-pre-refresh  . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh)))

(use-package project
  :ensure nil
  :bind-keymap ("C-c p" . project-prefix-map)
  :custom
  (project-switch-commands
   '((project-find-file "Find file" ?f)
     (project-find-regexp "Find regexp" ?g)
     (project-find-dir "Find directory" ?d)
     (project-dired "Dired" ?D)
     (consult-ripgrep "Ripgrep" ?r)
     (magit-project-status "Magit" ?m)))
  :config
  (dolist (dir '("~/Projects/" "~/wiki/" "~/Mirrors/" "~/.emacs.d/"))
    (when (file-directory-p dir)
      (project-remember-projects-under dir nil))))

(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode)
  :bind (:map flymake-mode-map
              ("M-n"     . flymake-goto-next-error)
              ("M-p"     . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)
              ("C-c ! L" . flymake-show-project-diagnostics)))

(use-package yasnippet
  :ensure t
  :hook ((prog-mode org-mode) . yas-minor-mode)
  :custom
  (yas-snippet-dirs (list (expand-file-name "snippets" user-emacs-directory))))

;;;; DOCUMENT WRITING
(use-package emacs             ; prettify-symbols-mode
  :ensure nil
  :config
  (setq prettify-symbols-unprettify-at-point 'right-edge))

;;;;; MARKDOWN MODE
(use-package markdown-ts-mode
  :ensure nil                       ; intégré à Emacs 31 (expérimental, opt-in)
  :mode ("\\.md\\'" . markdown-ts-mode))
  ;; NOTE: vérifier `C-h v markdown-ts-fontify-code-blocks-natively`
  ;;       — variable non confirmée sur le mode natif.

;;;;; ORG MODE
(use-package emacs ; configuration Org-Mode
  :ensure nil
  :hook ((org-mode          . prettify-symbols-mode)
         (org-mode          . visual-line-mode)))
(use-package ob-mermaid
  :ensure t)                        ; PAS de :after org (course au load-path)

(use-package org
  :ensure nil
  :custom
  (org-export-in-background t)
  (org-export-async-init-file
   (expand-file-name "lisp/my-export-async.el" user-emacs-directory))
  (org-directory my/wiki-path)
  (org-ellipsis " ⧾")
  (org-hide-emphasis-markers t)
  (org-startup-indented t)
  (org-startup-folded t)
  (org-indent-indentation-per-level 2)
  (org-support-shift-select t)
  (org-src-fontify-natively t)
  (org-src-tab-acts-natively t)
  (org-src-preserve-indentation t)
  (org-edit-src-content-indentation 0)
  (org-cite-insert-processor 'citar)
  (org-cite-follow-processor 'citar)
  (org-cite-activate-processor 'citar)
  (org-list-allow-alphabetical t)
  (org-M-RET-may-split-line '((default . nil)))
  (org-blank-before-new-entry '((heading . t) (plain-list-item . auto)))
  (org-insert-heading-respect-content t)
  (org-image-actual-width '(640))
  (org-adapt-indentation nil)
  (org-cycle-separator-lines 1)
  (org-startup-with-inline-images t)
  (org-cite-global-bibliography my/bibliography-files)
  (org-cite-export-processors '((latex biblatex)
                                (t     csl "expand-file-name.csl")))
  (org-cite-csl-styles-dir  my/zotero-styles-dir)
  (org-cite-csl-locales-dir my/csl-locales-dir)
  (org-cite-csl-bibtex-titles-to-sentence-case t)

  ;; --- Prévisualisation LaTeX : API mainline ---
  (org-startup-with-latex-preview nil)     ; t = preview auto à l'ouverture
  (org-preview-latex-default-process 'xelatex)
  (org-format-latex-options
   '(:foreground default :background default :scale 1.4
     :html-foreground "Black" :html-background "Transparent"
     :html-scale 1.0 :matchers ("begin" "$1" "$" "$$" "\\(" "\\[")))
  :config
  (dolist (pair '(("lean"       . lean-ts)
                  ("ebnf"       . ebnf)
                  ("typescript" . typescript-ts)
                  ("ocaml"      . neocaml)))
    (add-to-list 'org-src-lang-modes pair))

  (with-eval-after-load 'ob-core
    (dolist (lang '(calc mermaid))
      (when (locate-library (format "ob-%s" lang))
        (add-to-list 'org-babel-load-languages (cons lang t))))
    (org-babel-do-load-languages 'org-babel-load-languages
                                 org-babel-load-languages))
  (defun my/org-export-ignore-headlines (_backend)
    "Remove headlines tagged :ignore: but keep their contents."
    (org-map-entries
     (lambda ()
       (when (member "ignore" (org-get-tags nil t))
         (delete-region (point) (line-beginning-position 2))))
     nil nil 'reversed))

  (with-eval-after-load 'ox
    (add-hook 'org-export-before-processing-functions
              #'my/org-export-ignore-headlines))

  (with-eval-after-load 'ox-latex
    (setq org-latex-src-block-backend 'engraved)
    (require 'my-export-config)))

(use-package org-appear
  :ensure t
  :hook (org-mode . org-appear-mode)
  :custom
  (org-appear-autoemphasis t)
  (org-appear-autosubmarkers t)
  (org-appear-autolinks t)
  (org-appear-autoentities t)
  (org-appear-inside-latex t)
  (org-appear-delay 0.2))

(use-package org-glossary
  :ensure (:host github :repo "tecosaur/org-glossary")
  :hook (org-mode . org-glossary-mode)
  :custom
  (org-glossary-global-terms (list my/glossary-file)))

(use-package olivetti
  :ensure t
  :hook (org-mode . olivetti-mode)
  :custom
  (olivetti-body-width 90)
  (olivetti-minimum-body-width 90)
  (olivetti-style 'fancy))

(use-package citar
  :ensure t
  :after nerd-icons
  :bind (:map org-mode-map ("C-c b" . org-cite-insert))
  :hook ((LaTeX-mode org-mode) . citar-capf-setup)
  :config
  (require 'nerd-icons)
  (setopt citar-bibliography my/bibliography-files
          citar-library-paths my/zotero-storage
          citar-notes-paths   (list my/notes-path))
  (setq citar-indicators
        (list (citar-indicator-create
               :symbol (nerd-icons-faicon "nf-fa-file_o"
                                          :face 'nerd-icons-green :v-adjust -0.1)
               :function #'citar-has-files :padding "  " :tag "has:files")
              (citar-indicator-create
               :symbol (nerd-icons-codicon "nf-cod-note"
                                           :face 'nerd-icons-blue :v-adjust -0.3)
               :function #'citar-has-notes :padding "  " :tag "has:notes")
              (citar-indicator-create
               :symbol (nerd-icons-faicon "nf-fa-circle_o"
                                          :face 'nerd-icons-orange)
               :function #'citar-is-cited :padding "  " :tag "is:cited")))
  (run-with-idle-timer
   5 nil (lambda () (ignore-errors (citar-get-entries)))))

(use-package citar-embark :ensure t :after citar :config (citar-embark-mode))
(use-package citar-org :ensure nil :after (:any org oc) :demand t)
(use-package citeproc :ensure t)

(use-package howm
  :ensure (:host github :repo "kaorahi/howm")
  :bind (("C-c n c" . howm-create)
         ("C-c n l" . howm-list-all)
         ("C-c n s" . howm-search)
         ("C-c n g" . howm-search-grep)
         ("C-c n t" . howm-list-todo)
         ("C-c n r" . howm-list-recent))
  :custom
  (howm-directory my/wiki-path)
  (howm-file-name-format "%Y/%Y-%m-%d-%H%M%S.org")
  (howm-keyword-file (expand-file-name ".howm-keys" my/wiki-path))
  (howm-history-file (expand-file-name ".howm-history" my/wiki-path))
  (howm-view-use-grep t)
  (howm-view-grep-command "rg")
  (howm-view-grep-option "-nH --no-heading --color=never")
  (howm-view-grep-extended-option nil)
  (howm-view-grep-file-stdin-option nil)
  (howm-view-title-header "#+TITLE: ")
  (howm-template "#+TITLE: %title%\n#+DATE: %date\n\n%cursor")
  :config
  (add-to-list 'auto-mode-alist '("\\.howm$" . org-mode))
  (dolist (map (list howm-menu-mode-map
                     riffle-summary-mode-map
                     howm-view-contents-mode-map))
    (when (keymapp map)
      (define-key map "\C-h" nil)))
  (advice-add 'howm-list-recent :after
              (lambda (&rest _) (howm-view-sort-by-mtime)))
  (advice-add 'howm-list-all :after
              (lambda (&rest _) (howm-view-sort-by-date t)))
  (add-hook 'howm-mode-hook
          (lambda ()
            (add-hook 'after-save-hook #'howm-mode-set-buffer-name nil t))))

(use-package engrave-faces :ensure t)

;;;;; LATEX MODE
(use-package emacs ; configuration LaTeX
  :ensure nil
  :hook ((LaTeX-mode        . prettify-symbols-mode)
         (LaTeX-mode        . visual-line-mode)
         (LaTeX-mode        . flyspell-mode)))

(use-package tex
  :ensure (auctex
           :pre-build (("./autogen.sh")
                       ("./configure" "--without-texmf-dir" "--with-lispdir=.")
                       ("make"))
           :build (:not elpaca--compile-info)
           :files ("*.el" "doc/*.info*" "etc" "images" "latex" "style"))
           ;; PAS de :version — AUCTeX-version n'existe qu'après un `make` réussi
  :mode ("\\.tex\\'" . LaTeX-mode)
  :hook ((LaTeX-mode . LaTeX-math-mode)
         (LaTeX-mode . turn-on-reftex)
         (LaTeX-mode . TeX-source-correlate-mode)
         (LaTeX-mode . olivetti-mode))
  :custom
  (TeX-auto-save t)
  (TeX-parse-self t)
  (TeX-master nil)
  (TeX-save-query nil)
  (TeX-auto-local ".auctex-auto")
  (TeX-style-local ".auctex-style")
  (TeX-engine 'luatex)
  (TeX-PDF-mode t)
  (TeX-command-default "LatexMk")
  (TeX-show-compilation nil)
  (TeX-error-overview-open-after-TeX-run t)
  (TeX-source-correlate-method 'synctex)
  (TeX-source-correlate-start-server t)
  (TeX-view-program-selection '((output-pdf "PDF Tools")
                                (output-dvi "PDF Tools")))
  (TeX-electric-sub-and-superscript t)
  (TeX-electric-math '("\\(" . "\\)"))
  (LaTeX-electric-left-right-brace t)
  (TeX-insert-macro-default-style 'mandatory-args-only)
  (LaTeX-fill-break-at-separators nil)
  (TeX-quote-after-quote nil)
  (TeX-fold-auto t)
  (LaTeX-syntactic-comments t)

  :config
  (add-hook 'TeX-after-compilation-finished-functions
            #'TeX-revert-document-buffer)

  ;; latexmk sans paquet tiers (cohérent avec TeX-engine 'luatex)
  (add-to-list 'TeX-command-list
               '("LatexMk"
                 "latexmk -pdflua -interaction=nonstopmode -synctex=1 %t"
                 TeX-run-TeX nil (LaTeX-mode)
                 :help "Compiler avec latexmk (LuaLaTeX)")))

(use-package reftex
  :ensure nil
  :after tex
  :custom
  (reftex-plug-into-AUCTeX '(nil nil t t t)) ; cite:nil, ref/label/index:t
  (reftex-default-bibliography my/bibliography-files)
  (reftex-label-alist '(AMSTeX))
  (reftex-toc-split-windows-fraction 0.3)
  (reftex-enable-partial-scans t)
  (reftex-save-parse-info t)
  (reftex-use-multiple-selection-buffers t))

(use-package cdlatex
  :ensure t
  :hook ((LaTeX-mode . turn-on-cdlatex)
         (org-mode   . turn-on-org-cdlatex))
  :custom
  (cdlatex-simplify-sub-super-scripts nil)
  (cdlatex-takeover-parenthesis nil))

;;;;; PDF
(use-package pdf-tools
  :ensure t
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :custom
  (pdf-view-display-size 'fit-page)
  (pdf-view-use-scaling t)
  (pdf-annot-activate-created-annotations t)
  :config
  (pdf-tools-install :no-query)
  (add-hook 'pdf-view-mode-hook
            (lambda ()
              (auto-revert-mode 1)
              (pixel-scroll-precision-mode -1))))

(use-package org-noter
  :ensure t
  :after org
  :bind ("C-c n p" . org-noter)
  :custom
  (org-noter-notes-search-path (list my/notes-path))
  (org-noter-auto-save-last-location t)
  (org-noter-highlight-selected-text t)
  (org-noter-always-create-frame nil)
  (org-noter-default-notes-file-names '("annotations.org"))
  (org-noter-doc-split-fraction '(0.6 . 0.4))
  :config
  (require 'my-citar-noter)
  (with-eval-after-load 'citar
    (citar-register-notes-source
     'noter-notes
     (list :name "Org-noter"
           :category 'file
           :open #'my/citar-open-noter))
    (setq citar-notes-source 'noter-notes)))

;;;; FILE MANAGEMENT
(use-package emacs             ; File utilities
  :ensure nil
  :bind (("C-x R" . rename-visited-file)   ; Emacs 29+ built-in
         ("C-c f d" . my/delete-file-and-buffer)
         ("C-c f c" . my/copy-file-name)
         ("M-o"     . other-window))        ; Plus rapide que C-x o
  :config
  (define-key minibuffer-local-filename-completion-map ; Navigation fichier dans le minibuffer
              (kbd "<backtab>") #'backward-kill-sexp)
  (defun my/delete-file-and-buffer ()
    "Kill the current buffer and delete its file from disk."
    (interactive)
    (let ((filename (buffer-file-name)))
      (cond
       ((not filename)
        (message "Buffer '%s' is not visiting a file" (buffer-name)))
       ((not (file-exists-p filename))
        (kill-buffer))
       ((yes-or-no-p (format "Delete %s? " filename))
        (delete-file filename delete-by-moving-to-trash)
        (kill-buffer)
        (message "Deleted %s" filename)))))
  (defun my/copy-file-name ()
    "Copy the current buffer's file path to the kill ring.
If in a project, copy the path relative to the project root."
    (interactive)
    (if-let* ((filename (buffer-file-name)))
        (let* ((project (project-current))
               (relative (if project
                             (file-relative-name filename
                                                 (project-root project))
                           filename)))
          (kill-new relative)
          (message "Copied: %s" relative))
      (message "Buffer '%s' is not visiting a file" (buffer-name)))))

(use-package dired             ; Intentionnel : C-x d ouvre find-file, dired via C-x C-d
  :ensure nil
  :commands (dired dired-jump)
  :bind (("C-x d" . find-file)
         :map dired-mode-map
         (")" . dired-hide-details-mode))
  :custom
  (dired-listing-switches "-alh --group-directories-first")
  (dired-dwim-target t)
  (dired-recursive-copies 'always)
  (dired-recursive-deletes 'always)
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-create-destination-dirs 'always)
  (delete-by-moving-to-trash t))

(use-package diredfl
  :ensure t
  :hook (dired-mode . diredfl-mode))

(use-package dired-subtree
  :ensure (:host github :repo "Fuco1/dired-hacks" :files ("dired-subtree.el"))
  :after dired
  :bind (:map dired-mode-map
              ("TAB"   . dired-subtree-toggle)
              ("<tab>" . dired-subtree-toggle)))

;;;; TRAMP
(use-package tramp
  :ensure nil
  :custom
  (tramp-default-method "ssh")
  (tramp-verbose 1)
  (tramp-persistency-file-name
   (expand-file-name "tramp-connection-history" user-emacs-directory))
  (remote-file-name-inhibit-cache nil)
  (tramp-auto-save-directory
   (expand-file-name "tramp-autosave/" user-emacs-directory))
  (tramp-connection-timeout 10)
  (tramp-use-scp-direct-remote-copying t)
  :config
  (setq vc-ignore-dir-regexp
        (format "%s\\|%s"
                vc-ignore-dir-regexp
                tramp-file-name-regexp))
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path))

;;;; DÉMARRAGE
(add-hook 'elpaca-after-init-hook
          (lambda ()
            ;; 1. Charger custom.el
            (when (file-exists-p custom-file)
              (load custom-file :no-error :no-message))
            ;; 2. Message de bienvenue
            (message "Emacs ready in %.2f seconds with %d packages"
                     (float-time (time-subtract after-init-time
                                                before-init-time))
                     (length (elpaca--queued)))
            ;; 3. Vérification des dépendances (async avec cache BLAKE3)
            ;(require 'my-deps)
            ;(my/schedule-dep-check)
            ))

(provide 'init)
;;; init.el ends here

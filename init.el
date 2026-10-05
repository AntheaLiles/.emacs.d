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
;; Version de développement d'Emacs (31.1.50…) : Elpaca ne connaît que les
;; dates des versions publiées et avertit.  On lui donne la date de
;; compilation d'Emacs, ce qu'il ferait lui-même à défaut.
(when (and (> (length (version-to-list emacs-version)) 2) emacs-build-time)
  (defvar elpaca-core-date
    (list (string-to-number (format-time-string "%Y%m%d" emacs-build-time)))))
;; compat : depuis Emacs 30, une version minimale est intégrée à Emacs, et
;; sous Emacs 31 le paquet compat d'ELPA n'apporte rien (tout ce qu'il
;; rétro-porte existe déjà).  Utiliser celle d'Emacs évite le conflit
;; signalé par « compat loaded before Elpaca activation ».
(when (>= emacs-major-version 31)
  (with-eval-after-load 'elpaca
    (add-to-list 'elpaca-ignored-dependencies 'compat)))
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

;;;; MODULES MAISON
;; lisp/ est le répertoire `user-lisp-directory' (early-init.el) : Emacs 31
;; l'ajoute au load-path et en charge les autoloads avant init.el.
;; La ligne suivante ne sert qu'à un Emacs antérieur.
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; Compilation et autoloads de lisp/ APRÈS l'initialisation, une fois les
;; paquets d'Elpaca activés (voir early-init.el) : ne recompile que les
;; fichiers modifiés depuis la dernière fois.
(defun my/user-lisp-compile ()
  "Byte-compile and scrape the autoloads of `user-lisp-directory', if needed."
  (when (fboundp 'prepare-user-lisp)
    (prepare-user-lisp)))
(add-hook 'elpaca-after-init-hook
          (lambda () (run-with-idle-timer 2 nil #'my/user-lisp-compile)))

(require 'my-paths)
(require 'my-performance)
(require 'my-editing)
(require 'my-windows)
(require 'my-appearance)
(require 'my-folding)
(require 'my-formatting)
(require 'my-export-ui)

;;;; AIDES DE REDACTION
;; Déplacement de lignes : M-<up> / M-<down> (lisp/my-editing.el).

(use-package multiple-cursors
  :ensure t
  :bind (("C-S-c C-S-c"   . mc/edit-lines)
         ("C-S-<mouse-1>" . mc/add-cursor-on-click)))

;;;; THÈME ET MODELINE
;; Thème : modus-vivendi, intégré à Emacs (contraste WCAG AAA) ; réglages dans
;; lisp/my-appearance.el.  Mode line native (Emacs 31), idem.

(use-package nerd-icons
  :ensure t)

;;;; REPLIEMENT DE CODE
;; Entièrement géré par lisp/my-folding.el (outline + hideshow, TAB à la Org),
;; chargé plus haut : aucun hook ni réglage ici, pour éviter qu'outline soit
;; activé avant que my-folding n'ait posé l'`outline-regexp' du mode.

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
  ;; Sans kill-ring : un mot de passe copié finissait dans ~/.emacs.d/history.
  (savehist-additional-variables '(search-ring regexp-search-ring)))

(use-package recentf
  :ensure nil
  :hook (elpaca-after-init . recentf-mode)
  :custom
  (recentf-max-saved-items 200)
  (recentf-max-menu-items 15)
  (recentf-autosave-interval 300)        ; Emacs 31 : rien de perdu au plantage
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

;; Complétion par les mots du buffer : `dabbrev-capf', natif (Emacs 29),
;; remplace cape-dabbrev.  cape ne sert plus qu'aux fichiers et aux blocs
;; Emacs Lisp d'Org.
(use-package dabbrev
  :ensure nil
  :init
  (add-hook 'completion-at-point-functions #'dabbrev-capf))

(use-package cape
  :ensure t
  :init
  (add-hook 'completion-at-point-functions #'cape-file)
  :hook (org-mode . my/cape-org-setup)
  :config
  (defun my/cape-org-setup ()
    "Add cape-elisp-block completion in Org buffers."
    (add-hook 'completion-at-point-functions #'cape-elisp-block nil t)))

;;;; DÉVELOPPEMENT
;; Eglot démarre seulement pour les langages dont le serveur est déclaré
;; (ci-dessous, ou par lean4-mode), jamais dans un buffer sans fichier ni
;; dans un buffer d'édition de bloc Org (C-c ').
(use-package eglot
  :ensure nil
  :hook ((lean4-mode bash-ts-mode yaml-ts-mode typescript-ts-mode perl-ts-mode)
         . my/eglot-ensure-maybe)
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
  :init
  (defun my/eglot-ensure-maybe ()
    "Start Eglot in a file-visiting buffer, outside Org source edit buffers."
    (when (and buffer-file-name
               (not (bound-and-true-p org-src-mode)))
      (eglot-ensure)))
  :config
  (add-to-list 'eglot-server-programs
               '(typescript-ts-mode . ("typescript-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs
               '(yaml-ts-mode . ("yaml-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs
               '((bash-ts-mode) . ("bash-language-server" "start")))
  (add-to-list 'eglot-server-programs
               '(perl-ts-mode . ("perlnavigator" "--stdio"))))

;; Lean 4 : variante Eglot de lean4-mode (le paquet officiel impose
;; lsp-mode).  Elle déclare elle-même son serveur : « lake serve » à la
;; racine du projet Lake (Mathlib compris), avec détection du projet.
(use-package lean4-mode
  :ensure (:host github :repo "bustercopley/lean4-mode" :files ("*.el" "data"))
  :mode "\\.lean\\'")

;; lean4-mode dépend de markdown-mode, dont les autoloads réclament les
;; fichiers .md : on garde le mode natif tree-sitter (Emacs 31).
(add-to-list 'major-mode-remap-alist '(markdown-mode . markdown-ts-mode))

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
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :custom
  (diff-hl-update-async t))               ; git hors du fil principal

;; Emacs 31 : resynchroniser les buffers après une opération VC.
(use-package vc
  :ensure nil
  :hook (elpaca-after-init . vc-auto-revert-mode))

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
         (org-mode          . visual-line-mode)
         (org-mode          . visual-wrap-prefix-mode))) ; retour indenté (30)
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
  (org-src-content-indentation 0)         ; ex-org-edit-src-… (Org 9.8)
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
  (org-startup-with-link-previews t)      ; ex-…-inline-images (Org 9.8)
  ;; Citations : bibliographie CSL-JSON ; style, processeur et locales dans
  ;; lisp/my-export-config.el (partagé avec l'export asynchrone).
  (org-cite-global-bibliography my/bibliography-files)
  (org-cite-csl-styles-dir  my/zotero-styles-dir)

  ;; --- Prévisualisation LaTeX : API mainline ---
  (org-startup-with-latex-preview nil)     ; t = preview auto à l'ouverture
  (org-preview-latex-default-process 'xelatex)
  (org-format-latex-options
   '(:foreground default :background default :scale 1.4
     :html-foreground "Black" :html-background "Transparent"
     :html-scale 1.0 :matchers ("begin" "$1" "$" "$$" "\\(" "\\[")))
  :config
  (dolist (pair '(("lean"       . lean4)
                  ("ebnf"       . ebnf)
                  ("typescript" . typescript-ts)
                  ("ocaml"      . neocaml)))
    (add-to-list 'org-src-lang-modes pair))

  ;; Langages Babel : lisp/my-babel.el, partagé avec l'export asynchrone.
  (require 'my-babel)
  ;; Export PDF/UA (backend pdfua, C-c C-e u) et configuration partagée avec
  ;; le processus asynchrone.  ox charge ox-latex (`org-export-backends').
  (with-eval-after-load 'ox-latex
    (require 'my-export-config)))

;; Export Typst (backend my-typst, C-c C-e T) : ox-typst, étendu par
;; lisp/my-export-typst.el (partagé avec le processus d'export asynchrone).
;; Binaire requis : typst (>= 0.14 pour PDF/UA), voir M-x my/deps-check.
(use-package ox-typst
  :ensure t
  :after ox
  :config (require 'my-export-typst))

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
;; Après citar ET org : ne dépend pas de l'ordre de chargement d'Org.
(use-package citar-org :ensure nil :after (:all citar (:any org oc)) :demand t)
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
         (LaTeX-mode        . visual-wrap-prefix-mode)))

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
  (reftex-default-bibliography my/bibtex-files) ; .bib synchronisée par Zotero
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
  (org-noter-doc-split-fraction '(0.6 . 0.4)))

;; Ouvrir le PDF d'une référence et y lancer org-noter.  Les notes restent
;; gérées par la source de notes par défaut de citar (`citar-notes-paths').
(use-package my-citar-noter
  :ensure nil
  :commands my/citar-open-pdf-with-noter
  :bind ("C-c n P" . my/citar-open-pdf-with-noter))

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
            ;; 3. Dépendances système : à la demande, M-x my/deps-check
            ;;    (autochargé depuis lisp/my-deps.el).
            ))

(provide 'init)
;;; init.el ends here

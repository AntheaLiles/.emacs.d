;;; my-appearance.el --- Visual appearance -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Thème, fontes, mode-line, curseur, numéros de ligne, indicateurs visuels.
;;
;; Principes :
;;   - 100 % natif : aucun paquet externe, aucune dépendance optionnelle dure ;
;;   - toute la personnalisation du thème passe par les options Modus, jamais
;;     par `set-face-attribute' sur une face que le thème re-spécifie ;
;;   - la mode-line ne calcule rien au redessin : tout est en cache ou natif ;
;;   - tests/my-appearance-test.el établit l'état des lieux (API natives,
;;     palette, fontes, glyphes) ; il remplace l'ancien `my/ml-diagnose'.
;;
;; Vérifié sur Emacs 31.1.50.

;;; Code:

(declare-function set-fontset-font "fontset" (name target font-spec &optional frame add))
(declare-function vc-root-dir "vc-hooks" ())
(declare-function vc-file-getprop "vc-hooks" (file property))
(declare-function project-current "project" (&optional maybe-prompt directory))
(declare-function project-name "project" (project))
(declare-function modus-themes-toggle "modus-themes" ())
(declare-function modus-themes-get-color-value "modus-themes" (color &optional overrides theme))


;;;; 1. FONTES — déclaratif

(defconst my/font-default "JetBrainsMonoNL Nerd Font Propo"
  "Police du corps de texte.  La variante Propo est à chasse variable.")

(defconst my/font-fixed
  '("JetBrainsMonoNL Nerd Font Mono" "JetBrains Mono" "DejaVu Sans Mono")
  "Candidats pour `fixed-pitch' : tables et blocs de code Org.")

(defconst my/font-variable
  '("Inter" "Cantarell" "Source Sans 3" "DejaVu Sans" "Noto Sans")
  "Candidats pour `variable-pitch' : titres et prose.")

(defconst my/font-symbols "Symbols Nerd Font Mono"
  "Police à chasse fixe pour les glyphes de la zone à usage privé.")

(defconst my/font-height 120
  "Hauteur de la police par défaut, en 1/10 de point.")

(defun my/font-first-available (candidates)
  "Return the first installed family among CANDIDATES, or nil."
  (seq-find (lambda (family) (member family (font-family-list)))
            (ensure-list candidates)))

(defun my/setup-fonts (&optional _frame)
  "Configure default, fixed-pitch, variable-pitch and symbol fonts."
  (when (display-graphic-p)
    (if-let* ((family (my/font-first-available my/font-default)))
        (set-face-attribute 'default nil :family family :height my/font-height)
      (message "[appearance] police « %s » introuvable" my/font-default))
    ;; `fixed-pitch' est indispensable : `modus-themes-mixed-fonts' y fait
    ;; hériter les tables et blocs Org.  Hauteur relative (flottant) pour
    ;; rester solidaire de la police par défaut.
    (when-let* ((family (my/font-first-available my/font-fixed)))
      (set-face-attribute 'fixed-pitch nil :family family :height 1.0))
    (when-let* ((family (my/font-first-available my/font-variable)))
      (set-face-attribute 'variable-pitch nil :family family :height 1.0))
    ;; La variante Propo a des glyphes à chasse variable : les icônes
    ;; feraient tressauter la mode-line.  On redirige la zone à usage privé
    ;; (Devicons, Octicons, Font Awesome, Codicons) vers la variante Mono.
    (when (my/font-first-available my/font-symbols)
      (dolist (range '((#xe000 . #xf8ff) (#xf0000 . #xfffff)))
        (set-fontset-font t range my/font-symbols nil 'prepend)))))

(my/setup-fonts)
;; Mode démon : la première frame graphique n'existe pas encore au chargement.
(add-hook 'server-after-make-frame-hook #'my/setup-fonts)


;;;; 2. THÈME — modus-vivendi
;; TOUTES les options Modus doivent précéder `load-theme'.

(defvar modus-themes-italic-constructs)
(defvar modus-themes-bold-constructs)
(defvar modus-themes-mixed-fonts)
(defvar modus-themes-to-toggle)
(defvar modus-themes-headings)
(defvar modus-themes-common-palette-overrides)

(setq modus-themes-italic-constructs t
      modus-themes-bold-constructs nil
      ;; Tables et blocs Org en chasse fixe : nécessite la face `fixed-pitch'
      ;; configurée en section 1.
      modus-themes-mixed-fonts t
      modus-themes-to-toggle '(modus-vivendi modus-operandi)

      ;; Headings Org : mécanisme natif Modus.  Remplace les appels à
      ;; `set-face-attribute' sur org-level-N, que le thème écrasait à chaque
      ;; rechargement.  Retirer `variable-pitch' pour rester en chasse fixe.
      modus-themes-headings
      '((0 . (variable-pitch semibold 1.35))
        (1 . (variable-pitch semibold 1.30))
        (2 . (variable-pitch semibold 1.25))
        (3 . (variable-pitch semibold 1.20))
        (4 . (variable-pitch 1.15))
        (5 . (variable-pitch 1.10))
        (6 . (variable-pitch 1.05))
        (7 . (variable-pitch 1.00))
        (8 . (variable-pitch 1.00))
        (agenda-date      . (variable-pitch semibold 1.15))
        (agenda-structure . (variable-pitch light 1.25))
        (t . (variable-pitch 1.00)))

      modus-themes-common-palette-overrides
      '(;; Mode-line sans bordure.  Les FONDS ne sont pas touchés : le
        ;; contraste actif / inactif de Modus est déjà fort et accessible.
        (border-mode-line-active   unspecified)
        (border-mode-line-inactive unspecified)
        ;; Blocs Org discrets.  `modus-themes-org-blocks' est supprimé
        ;; depuis Modus 4.4 au profit de ces noms de palette.
        (bg-prose-block-contents  bg-dim)
        (bg-prose-block-delimiter bg-dim)
        (fg-prose-block-delimiter fg-dim)))

(mapc #'disable-theme custom-enabled-themes)
(load-theme 'modus-vivendi t)

(keymap-global-set "<f5>" #'modus-themes-toggle)


;;;; 3. CURSEUR

(setopt cursor-type 'bar)


;;;; 4. MODE LINE — native Emacs 31

;;;;; 4.1 Faces ---------------------------------------------------------------
;; Les faces génériques (`error', `warning', `shadow') sont calibrées pour
;; `bg-main', pas pour `bg-mode-line-active'.  On dérive donc des faces
;; dédiées via la FONCTION `modus-themes-get-color-value' : contrairement à la
;; macro `modus-themes-with-colors', elle ne produit aucun avertissement de
;; variable libre et permet un repli propre sur `:inherit'.

(defgroup my/ml nil
  "Faces for the custom mode line."
  :group 'mode-line-faces
  :prefix "my/ml-")

(defface my/ml-dim '((t :inherit shadow))
  "Mode line, informations secondaires." :group 'my/ml)
(defface my/ml-ok '((t :inherit shadow))
  "Mode line, état nominal." :group 'my/ml)
(defface my/ml-warn '((t :inherit warning))
  "Mode line, attention requise." :group 'my/ml)
(defface my/ml-err '((t :inherit error))
  "Mode line, problème." :group 'my/ml)
(defface my/ml-accent '((t :inherit mode-line-buffer-id :weight normal))
  "Mode line, branche Git et nom de projet." :group 'my/ml)

(defconst my/ml-palette-map
  '((my/ml-dim    . fg-dim)
    (my/ml-ok     . green-faint)
    (my/ml-warn   . yellow-cooler)
    (my/ml-err    . red)
    (my/ml-accent . cyan-cooler))
  "Association FACE → nom de couleur Modus.
Si un nom est absent de la palette, la face garde son `:inherit' de repli.")

(defun my/ml-set-faces (&optional _theme)
  "Derive the mode line faces from the active Modus palette."
  (when (and (fboundp 'modus-themes-get-color-value)
             (seq-some (lambda (th) (string-prefix-p "modus-" (symbol-name th)))
                       custom-enabled-themes))
    (pcase-dolist (`(,face . ,color) my/ml-palette-map)
      (let ((value (ignore-errors (modus-themes-get-color-value color t))))
        (set-face-attribute face nil
                            :foreground (if (stringp value) value 'unspecified))))))

(add-hook 'enable-theme-functions #'my/ml-set-faces)
(my/ml-set-faces)

;;;;; 4.2 Glyphes --------------------------------------------------------------
;; Codepoints Nerd Fonts v3 vérifiés.  `remote' reste en ASCII : c'est la
;; convention de `mode-line-remote' et cela supprime tout risque de tofu.

(defconst my/ml-icons
  '((saved    . "\uf00c")   ; nf-fa-check
    (modified . "\uf111")   ; nf-fa-circle
    (readonly . "\uf023")   ; nf-fa-lock
    (encoding . "\uf0ac")   ; nf-fa-globe
    (git      . "\ue725")   ; nf-oct-git_branch
    (remote   . "@"))
  "Glyphes utilisés par la mode-line.")

(defsubst my/ml-icon (key)
  "Return the glyph associated with KEY."
  (alist-get key my/ml-icons))

;;;;; 4.3 Options natives --------------------------------------------------------

(setopt mode-line-collapse-minor-modes t  ; Emacs 31 : remplace diminish/minions
        mode-line-percent-position nil    ; redondant avec ligne:colonne
        mode-line-position-column-line-format '(" %l:%c")
        mode-line-right-align-edge 'window
        ;; Rendu explicitement en 4.7 : project.el passe par la valeur par
        ;; défaut de `mode-line-format', que l'on remplace entièrement.
        project-mode-line nil)

;; Emacs 31 : supprime les parenthèses autour des modes.
(when (boundp 'mode-line-modes-delimiters)
  (setopt mode-line-modes-delimiters '("" . "")))

(column-number-mode 1)

;;;;; 4.4 États du buffer — remplace « U:--- » ------------------------------------
;;
;;   U   → coding system   |  :  → fin de ligne
;;   --  → RO / modifié    |  -  → local vs distant
;;
;; On n'affiche que ce qui dévie de la normale (UTF-8 + LF + local), plus un
;; indicateur permanent enregistré / modifié.  Narrowing (« %n ») et édition
;; récursive (« %[ %] ») sont déjà fournis par `mode-line-modes'.

(defun my/ml-state ()
  "Return buffer state indicators, silent when everything is nominal."
  (let ((parts nil)
        (cs (or buffer-file-coding-system 'utf-8-unix)))
    (push (cond
           (buffer-read-only
            (propertize (my/ml-icon 'readonly) 'face 'my/ml-dim
                        'help-echo "Lecture seule — C-x C-q pour basculer"))
           ((and (buffer-modified-p) buffer-file-name)
            (propertize (my/ml-icon 'modified) 'face 'my/ml-err
                        'help-echo "Modifications non enregistrées"))
           (buffer-file-name
            (propertize (my/ml-icon 'saved) 'face 'my/ml-ok
                        'help-echo "Enregistré"))
           (t " "))
          parts)
    (when-let* ((remote (and buffer-file-name (file-remote-p buffer-file-name))))
      (push (propertize (my/ml-icon 'remote) 'face 'my/ml-warn
                        'help-echo (format "Distant : %s" remote))
            parts))
    (let ((base (coding-system-base cs))
          (eol  (coding-system-eol-type cs)))
      (unless (and (memq base '(utf-8 prefer-utf-8 undecided no-conversion))
                   (or (vectorp eol) (eq eol 0)))
        (push (propertize (concat (my/ml-icon 'encoding) " "
                                  (symbol-name base)
                                  (pcase eol (1 " CRLF") (2 " CR") (_ "")))
                          'face 'my/ml-warn
                          'help-echo "Encodage ou fin de ligne non standard")
              parts)))
    (mapconcat #'identity (nreverse parts) " ")))

;;;;; 4.5 Caches par buffer ---------------------------------------------------------
;; Tout est calculé sur hook, jamais au redessin.

(defvar-local my/ml-dir nil)
(defvar-local my/ml-vc-root nil)
(defvar-local my/ml-project nil)

(defun my/ml--dir (directory)
  "Return DIRECTORY abbreviated and propertized, or nil."
  (and directory
       (propertize (abbreviate-file-name directory) 'face 'my/ml-dim)))

(defun my/ml--project-name ()
  "Return the current project name, propertized, or nil."
  (when-let* (((fboundp 'project-current))
              (proj (ignore-errors (project-current nil)))
              (name (ignore-errors (project-name proj))))
    (propertize (concat "  " name) 'face 'my/ml-dim 'help-echo "Projet courant")))

(defun my/ml-update-caches ()
  "Refresh cached path, VC root and project name of the current buffer."
  (setq my/ml-dir     (my/ml--dir (and buffer-file-name
                                       (file-name-directory buffer-file-name)))
        my/ml-vc-root (and buffer-file-name
                           (not (file-remote-p buffer-file-name))
                           (ignore-errors (vc-root-dir)))
        my/ml-project (my/ml--project-name)))

(dolist (hook '(find-file-hook after-save-hook
                after-set-visited-file-name-hook))
  (add-hook hook #'my/ml-update-caches))

;;;;; 4.6 Git -----------------------------------------------------------------------
;; Branche : `vc-mode', maintenu par VC — zéro appel externe au redessin.
;; État    : propriété VC en cache — pas de `vc-state' potentiellement bloquant.
;; Amont   : processus asynchrone, dédupliqué par dépôt, fenêtres visibles only.

(defvar my/ml-upstream-cache   (make-hash-table :test #'equal))
(defvar my/ml-upstream-pending (make-hash-table :test #'equal))

(defconst my/ml-vc-state-faces
  '((up-to-date . my/ml-accent)
    (edited     . my/ml-warn)
    (added      . my/ml-ok)
    (conflict   . my/ml-err)
    (missing    . my/ml-err)
    (removed    . my/ml-err))
  "Association état VC → face de la mode-line.")

(defun my/ml-vc ()
  "Return Git branch, file state and upstream divergence."
  (when (and vc-mode buffer-file-name)
    (let* ((branch (replace-regexp-in-string
                    "\\` *Git[:@-]" "" (substring-no-properties vc-mode)))
           (state (vc-file-getprop buffer-file-name 'vc-state))
           (face  (or (alist-get state my/ml-vc-state-faces) 'my/ml-dim)))
      (concat (propertize (my/ml-icon 'git) 'face face) " "
              (propertize branch 'face face)
              (or (gethash my/ml-vc-root my/ml-upstream-cache) "")))))

(defun my/ml-refresh-upstream (root)
  "Asynchronously compute ahead/behind counts for repository ROOT."
  (unless (gethash root my/ml-upstream-pending)
    (puthash root t my/ml-upstream-pending)
    (let ((default-directory root)
          (buf (generate-new-buffer " *ml-git*" t)))
      (make-process
       :name "ml-git" :buffer buf :noquery t
       :command '("git" "rev-list" "--left-right" "--count" "@{upstream}...HEAD")
       :sentinel
       (lambda (proc _event)
         (when (memq (process-status proc) '(exit signal))
           (unwind-protect
               (let ((out (with-current-buffer (process-buffer proc)
                            (string-trim (buffer-string)))))
                 (puthash
                  root
                  (if (and (zerop (process-exit-status proc))
                           (string-match
                            "\\`\\([0-9]+\\)[ \t]+\\([0-9]+\\)\\'" out))
                      (let ((behind (string-to-number (match-string 1 out)))
                            (ahead  (string-to-number (match-string 2 out))))
                        (concat (and (> ahead 0)  (format " ↑%d" ahead))
                                (and (> behind 0) (format " ↓%d" behind))))
                    "")  ; pas d'amont : git sort en 128 → rien, sans blocage
                  my/ml-upstream-cache)
                 (force-mode-line-update t))
             ;; Toujours exécuté : empêche l'interblocage sur code ≠ 0.
             (remhash root my/ml-upstream-pending)
             (when (buffer-live-p (process-buffer proc))
               (kill-buffer (process-buffer proc))))))))))

(defun my/ml-upstream-tick ()
  "Refresh upstream info for repositories visible on screen."
  (let (roots)
    (walk-windows
     (lambda (win)
       (with-current-buffer (window-buffer win)
         (when (and my/ml-vc-root (not (member my/ml-vc-root roots)))
           (push my/ml-vc-root roots))))
     'nomini 'visible)
    (mapc #'my/ml-refresh-upstream roots)))

(run-with-idle-timer 30 t #'my/ml-upstream-tick)

;;;;; 4.7 Langue naturelle --------------------------------------------------------
;; Emacs ne détecte pas la langue d'un texte ; le dictionnaire de correction est
;; le seul indicateur natif fiable.  La « langue » Python / R / Org relève du
;; mode majeur, affiché par `mode-line-modes'.

(defun my/ml-language ()
  "Return the active spelling dictionary and input method."
  (let ((dict (or (bound-and-true-p ispell-local-dictionary)
                  (bound-and-true-p ispell-dictionary)
                  (bound-and-true-p ispell-current-dictionary))))
    (concat
     (and dict (propertize (format " %s" dict) 'face 'my/ml-dim))
     (and current-input-method-title
          (propertize (format " %s" current-input-method-title)
                      'face 'my/ml-accent)))))

;;;;; 4.8 Segments et variantes ------------------------------------------------------
;; `mode-line-window-selected-p' : le contexte lourd n'apparaît que dans la
;; fenêtre active, ce qui l'identifie sans ajouter de bruit visuel.

(defconst my/ml-seg
  `((prefix   . ("%e" mode-line-front-space
                 (:propertize (:eval (my/ml-state)) display (min-width (4.0)))
                 " "))
    (lite     . ("%e" mode-line-front-space))
    (path     . ((:eval (and (mode-line-window-selected-p) my/ml-dir))))
    (buffer   . (mode-line-buffer-identification))
    (vc       . ((:eval (and (mode-line-window-selected-p)
                             (when-let* ((g (my/ml-vc))) (concat "  " g))))))
    (right    . (mode-line-format-right-align))
    (lang     . ((:eval (and (mode-line-window-selected-p) (my/ml-language))) "  "))
    ;; Construct conditionnel : rien si flymake est inactif ou absent.
    (flymake  . ((flymake-mode flymake-mode-line-counters) "  "))
    ;; Mode majeur, `mode-line-process', %n, %[ %], mineurs repliés.
    (modes    . (mode-line-modes))
    (position . (mode-line-position))
    (percent  . ((:propertize "  %p" face my/ml-dim)))
    (project  . ((:eval (and (mode-line-window-selected-p) my/ml-project))))
    (suffix   . (mode-line-misc-info mode-line-end-spaces)))
  "Segments réutilisables de la mode-line.")

(defun my/ml-compose (&rest keys)
  "Assemble the mode line segments named by KEYS."
  (mapcan (lambda (key) (copy-sequence (alist-get key my/ml-seg))) keys))

(defconst my/ml-formats
  `((default . ,(my/ml-compose 'prefix 'path 'buffer 'vc 'right 'lang
                               'flymake 'modes 'position 'project 'suffix))
    (prog    . ,(my/ml-compose 'prefix 'path 'buffer 'vc 'right
                               'flymake 'modes 'position 'project 'suffix))
    (text    . ,(my/ml-compose 'prefix 'path 'buffer 'vc 'right 'lang
                               'modes 'position 'project 'suffix))
    ;; Dired : ligne:colonne n'a pas de sens, on montre la progression.
    (dired   . ,(my/ml-compose 'prefix 'path 'buffer 'vc 'right
                               'modes 'percent 'project 'suffix))
    (special . ,(my/ml-compose 'lite 'buffer 'right 'modes 'position)))
  "Variantes de mode-line par famille de modes majeurs.")

(setq-default mode-line-format (alist-get 'default my/ml-formats))

(defun my/ml-use (variant)
  "Install the mode line VARIANT buffer-locally."
  (setq-local mode-line-format (alist-get variant my/ml-formats)))

(defun my/ml-setup-prog ()    (my/ml-use 'prog))
(defun my/ml-setup-text ()    (my/ml-use 'text))
(defun my/ml-setup-special () (my/ml-use 'special))

(defun my/ml-setup-dired ()
  "Install the Dired mode line and seed its caches."
  ;; Dired n'a pas de `buffer-file-name' : on affiche le répertoire parent,
  ;; `mode-line-buffer-identification' se chargeant du répertoire courant.
  (setq my/ml-dir (my/ml--dir (or (file-name-directory
                                   (directory-file-name default-directory))
                                  default-directory))
        my/ml-vc-root (ignore-errors (vc-root-dir))
        my/ml-project (my/ml--project-name))
  (my/ml-use 'dired))

;; `markdown-ts-mode' dérive de `fundamental-mode' (vérifié) : `text-mode-hook'
;; ne le couvre pas.  `dired-mode-hook' passe après `special-mode-hook',
;; la variante Dired l'emporte donc.
(pcase-dolist (`(,hook . ,fn)
               '((prog-mode-hook        . my/ml-setup-prog)
                 (text-mode-hook        . my/ml-setup-text)
                 (markdown-ts-mode-hook . my/ml-setup-text)
                 (special-mode-hook     . my/ml-setup-special)
                 (dired-mode-hook       . my/ml-setup-dired)))
  (add-hook hook fn))

;;;; 5. NUMÉROS DE LIGNE
;; prog-mode : relatifs | org/markdown/LaTeX : absolus | autres : aucun

(defun my/line-numbers-relative ()
  "Enable relative line numbers."
  (setq-local display-line-numbers 'relative))

(defun my/line-numbers-absolute ()
  "Enable absolute line numbers."
  (setq-local display-line-numbers t))

(add-hook 'prog-mode-hook #'my/line-numbers-relative)

;; Modes réellement utilisés : markdown-ts-mode (natif Emacs 31) et
;; LaTeX-mode (AUCTeX), pas markdown-mode ni le latex-mode d'Emacs.
(dolist (hook '(org-mode-hook markdown-ts-mode-hook LaTeX-mode-hook))
  (add-hook hook #'my/line-numbers-absolute))


;;;; 6. PROG-MODE

(defun my/truncate-lines ()
  "Disable line wrapping in the current buffer."
  (setq-local truncate-lines t))

(dolist (fn '(display-fill-column-indicator-mode  ; colonne 80
              goto-address-mode                   ; URLs cliquables
              my/truncate-lines))
  (add-hook 'prog-mode-hook fn))


;;;; 7. SHOW-PAREN

(setopt show-paren-delay 0.0
        show-paren-style 'parenthesis
        show-paren-when-point-in-periphery t
        show-paren-when-point-inside-paren t)
(show-paren-mode 1)


;;;; 8. HL-LINE

(global-hl-line-mode 1)

(defun my/disable-hl-line ()
  "Disable `hl-line-mode' in the current buffer."
  (hl-line-mode -1))

(dolist (hook '(pdf-view-mode-hook term-mode-hook vterm-mode-hook
                shell-mode-hook eshell-mode-hook))
  (add-hook hook #'my/disable-hl-line))


;;;; 9. ORG — présentation
;; Les tailles et couleurs des titres sont gérées par `modus-themes-headings'
;; en section 2.  Ne JAMAIS utiliser `set-face-attribute' sur org-level-N :
;; le thème re-spécifie ces faces à chaque chargement et écraserait le réglage.
;; Ici, uniquement des réglages de présentation indépendants du thème.

(with-eval-after-load 'org
  (setopt org-ellipsis " ▾"
          org-hide-emphasis-markers t
          org-pretty-entities t
          org-startup-indented t
          ;; Cohérent avec `modus-themes-mixed-fonts'.
          org-fontify-quote-and-verse-blocks t
          org-fontify-whole-heading-line t))

;; Prose en chasse variable, tables et blocs restant en chasse fixe grâce à
;; `modus-themes-mixed-fonts'.  Décommenter pour un rendu « traitement de
;; texte » ; à laisser inactif si vous alignez du texte à la main.
;; (add-hook 'org-mode-hook #'variable-pitch-mode)

(provide 'my-appearance)
;;; my-appearance.el ends here

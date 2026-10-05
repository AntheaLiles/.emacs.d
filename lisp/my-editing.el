;;; my-editing.el --- Editing defaults -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Configuration d'édition : encodage, kill-ring, sélection, sauvegardes,
;; correction orthographique (flyspell/hunspell), backups.

;;; Code:

;;;; ENCODAGE
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)

;;;; COMPORTEMENT D'ÉDITION
(setopt save-interprogram-paste-before-kill t
        kill-do-not-save-duplicates t
        set-mark-command-repeat-pop t
        reb-re-syntax 'string
        ffap-machine-p-known 'reject
        ;; ADDED: typographie française — une seule espace après le point
        sentence-end-double-space nil
        ;; ADDED: indenter avec des espaces, jamais des tabulations
        indent-tabs-mode nil
        ;; ADDED: colonne de remplissage à 80 (défaut 70 trop court)
        fill-column 80
        ;; ADDED: couper la ligne entière avec C-k (inclut le \n)
        kill-whole-line t
        ;; ADDED: coller au point du curseur, pas à la position de la souris
        mouse-yank-at-point t)

(delete-selection-mode 1)
(electric-pair-mode 1)
(save-place-mode 1)
;; Copier du code sans son indentation commune (Emacs 30)
(when (fboundp 'kill-ring-deindent-mode) (kill-ring-deindent-mode 1))
;; Appliquer les .editorconfig des projets (intégré depuis Emacs 30)
(when (fboundp 'editorconfig-mode) (editorconfig-mode 1))

;;;; DÉPLACER DES LIGNES — M-<up> / M-<down>
;; Remplace le paquet move-text : la ligne courante, ou les lignes couvertes
;; par la région, montent ou descendent d'un cran ; la région est conservée.

(defun my/move-lines (n)
  "Move the current line, or the lines spanned by the region, N lines down.
A negative N moves them up."
  (let* ((region (use-region-p))
         (beg (save-excursion
                (goto-char (if region (region-beginning) (point)))
                (line-beginning-position)))
         (end (save-excursion
                (goto-char (if region (region-end) (point)))
                ;; Une région qui finit en début de ligne n'inclut pas celle-ci
                (when (and region (bolp) (> (point) beg)) (backward-char))
                (line-beginning-position 2)))
         (col (current-column))
         (point-offset (- (point) beg))
         (mark-offset (and region (- (mark) beg))))
    (when (save-excursion
            (goto-char (if (< n 0) beg end))
            (zerop (forward-line n)))
      (let* ((text (delete-and-extract-region beg end))
             (_ (forward-line n))
             (new-beg (point)))
        ;; Dernière ligne sans saut de ligne final
        (unless (string-suffix-p "\n" text)
          (setq text (concat text "\n"))
          (when (eobp) (insert "\n") (backward-char)))
        (insert text)
        (goto-char (+ new-beg point-offset))
        (if region
            (progn (set-mark (+ new-beg mark-offset))
                   (setq deactivate-mark nil))
          (move-to-column col))))))

(defun my/move-lines-up (n)
  "Move the current line or region N lines up."
  (interactive "p")
  (my/move-lines (- n)))

(defun my/move-lines-down (n)
  "Move the current line or region N lines down."
  (interactive "p")
  (my/move-lines n))

(keymap-global-set "M-<up>"   #'my/move-lines-up)
(keymap-global-set "M-<down>" #'my/move-lines-down)

;;;; SAVE-PLACE
(setopt save-place-ignore-files-regexp
        "\\(?:COMMIT_EDITMSG\\|hg-hierarchet\\|svn-commit\\|bzr_log\\|/ssh:\\|/sudo:\\)"
        ;; Emacs 31 : enregistrer régulièrement, rien de perdu au plantage
        save-place-autosave-interval 300)

(add-hook 'save-place-after-find-file-hook
          (lambda ()
            (when buffer-file-name
              (ignore-errors (recenter)))))

;;;; SCRIPTS EXÉCUTABLES
(add-hook 'after-save-hook #'executable-make-buffer-file-executable-if-script-p)

;;;; AUTO-SAVE
;; Sauvegarde automatique des fichiers visités toutes les 2 s, pour TOUS les
;; fichiers (disques Windows /mnt/… de WSL compris) : l'usage quotidien s'y
;; appuie.  Ne pas espacer ni restreindre sans le demander (régression de
;; septembre 2026 : 30 s et /mnt/ exclu, Emacs redemandait de sauvegarder).
(setopt auto-save-visited-interval 2)
(auto-save-visited-mode 1)

;;;; LOCKFILES
(setopt create-lockfiles nil)

;;;; BACKUPS
(let ((backup-dir (expand-file-name "backups/" user-emacs-directory)))
  (unless (file-directory-p backup-dir)
    (make-directory backup-dir t))
  (setopt backup-directory-alist `(("." . ,backup-dir))))
(setopt backup-by-copying t      ; copie au lieu de renommage (plus sûr)
        version-control t         ; versions numérotées
        delete-old-versions t     ; supprimer les vieilles versions
        kept-new-versions 5      ; garder les 5 plus récentes
        kept-old-versions 2)     ; garder les 2 plus anciennes

;;;; AUTO-SAVE FILES
;; Évite les fichiers #foo# qui polluent les dossiers de travail
(let ((auto-save-dir (expand-file-name "auto-save/" user-emacs-directory)))
  (unless (file-directory-p auto-save-dir)
    (make-directory auto-save-dir t))
  (setopt auto-save-file-name-transforms
          `((".*" ,auto-save-dir t))))

;;;; FLYSPELL
;; Backend : hunspell (multi-dictionnaire, meilleur support UTF-8 que aspell)
;; Dictionnaires requis : hunspell-fr (français), hunspell-en-us (anglais)
;; Vérification : M-x my/deps-check (lisp/my-deps.el) signale un hunspell absent
;;
;; Workflow :
;;   - Erreurs soulignées automatiquement pendant la frappe
;;   - C-c $   : corriger le mot au curseur (menu de suggestions)
;;   - C-M-;   : corriger automatiquement le mot mal orthographié précédent
;;   - C-,     : aller à l'erreur suivante
;;   - M-x flyspell-buffer : vérifier le buffer entier
;;
;; C-. et C-; sont rendus à Embark (embark-act / embark-dwim, init.el) :
;; flyspell les prenait dans son keymap, qui masquait les raccourcis globaux
;; dans tous les buffers où il est actif, c'est-à-dire partout.
;;   - Dictionnaire personnel dans ~/.emacs.d/ispell-personal (versionné)

(with-eval-after-load 'ispell
  ;; Utiliser hunspell comme backend
  (when (executable-find "hunspell")
    (setopt ispell-program-name "hunspell"
            ;; Dictionnaire français par défaut, anglais en complément
            ispell-dictionary "fr_FR"
            ;; Multi-dictionnaire : français + anglais simultanément
            ispell-local-dictionary-alist
            '(("fr_FR"
               "[[:alpha:]]" "[^[:alpha:]]"
               "[-']" t
               ("-d" "fr_FR,en_US")
               nil utf-8)
              ("en_US"
               "[[:alpha:]]" "[^[:alpha:]]"
               "[-']" t
               ("-d" "en_US")
               nil utf-8))
            ;; Dictionnaire personnel versionné avec la config
            ispell-personal-dictionary
            (expand-file-name "ispell-personal" user-emacs-directory)))
  ;; Emacs 31 : une correction choisie devient une abréviation globale
  ;; (C-u avant le choix inverse ce réglage au cas par cas).
  (setopt ispell-save-corrections-as-abbrevs t))

;; Flyspell en mode texte.  Org, markdown-ts-mode et LaTeX-mode (AUCTeX)
;; dérivent tous de `text-mode' : un seul hook les couvre.
(add-hook 'text-mode-hook #'flyspell-mode)

;; Keymap de flyspell, modifié ci-dessous après son chargement
(defvar flyspell-mode-map)
(declare-function flyspell-auto-correct-previous-word "flyspell" (position))

;; Flyspell-prog en mode programmation (vérifie commentaires + strings)
(add-hook 'prog-mode-hook #'flyspell-prog-mode)

;; Messages de flyspell
(with-eval-after-load 'flyspell
  (setopt flyspell-issue-message-flag nil    ; pas de message par mot vérifié
          flyspell-issue-welcome-flag nil    ; pas de message au démarrage
          ;; Emacs 31 : vérifier par minuteur plutôt que par sit-for, sans
          ;; bloquer les autres minuteurs (futur comportement par défaut)
          flyspell-delay-use-timer t)
  ;; Libérer C-. et C-; pour Embark, déplacer l'auto-correction sur C-M-;
  (keymap-unset flyspell-mode-map "C-." t)
  (keymap-unset flyspell-mode-map "C-;" t)
  (keymap-set flyspell-mode-map "C-M-;" #'flyspell-auto-correct-previous-word))

;;;; CONFIANCE (trusted-content)
;; Depuis Emacs 30 (CVE-2024-53920), Flymake n'exécute plus le code Elisp d'un
;; fichier non fiable : sans réglage, le linting est désactivé dans la
;; configuration elle-même.  On ne déclare fiable que le code écrit ici, jamais
;; `user-emacs-directory' entier (il contient elpaca/, du code téléchargé) et
;; jamais `:all'.  La barre oblique finale désigne un répertoire.

(defvar trusted-content)                 ; Emacs 30+ ; absente avant

(defun my/trusted-content-setup ()
  "Add this configuration's own Lisp files to `trusted-content'.
Directories lisp/, tests/, scripts/ and perf/ plus init.el and early-init.el
are added; elpaca/ and any other downloaded code are not."
  (dolist (entry '("init.el" "early-init.el" "lisp/" "tests/" "scripts/" "perf/"))
    (add-to-list 'trusted-content
                 (abbreviate-file-name
                  (expand-file-name entry user-emacs-directory)))))

(when (boundp 'trusted-content)
  (my/trusted-content-setup))

(provide 'my-editing)
;;; my-editing.el ends here

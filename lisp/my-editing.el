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

;;;; SAVE-PLACE
(setopt save-place-ignore-files-regexp
        "\\(?:COMMIT_EDITMSG\\|hg-hierarchet\\|svn-commit\\|bzr_log\\|/ssh:\\|/sudo:\\)")

(add-hook 'save-place-after-find-file-hook
          (lambda ()
            (when buffer-file-name
              (ignore-errors (recenter)))))

;;;; SCRIPTS EXÉCUTABLES
(add-hook 'after-save-hook #'executable-make-buffer-file-executable-if-script-p)

;;;; AUTO-SAVE
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

;;;; KILL-RING — nettoyer les text properties avant persistance
;; Évite que savehist gonfle avec les propriétés de face/overlay
;; des buffers Org et du .bib de 14 Mo.
(defun my/savehist-strip-text-properties ()
  "Strip text properties from `kill-ring' before saving to disk."
  (setq kill-ring
        (mapcar #'substring-no-properties kill-ring)))
(add-hook 'savehist-save-hook #'my/savehist-strip-text-properties)

;;;; FLYSPELL
;; Backend : hunspell (multi-dictionnaire, meilleur support UTF-8 que aspell)
;; Dictionnaires requis : hunspell-fr (français), hunspell-en-us (anglais)
;; Vérification : M-x my/check-system-deps signalera si hunspell est absent
;;
;; Workflow :
;;   - Erreurs soulignées automatiquement pendant la frappe
;;   - C-; : correction du mot au curseur (flyspell-correct-wrapper)
;;   - C-c $ : correction du mot au curseur (flyspell natif)
;;   - M-x flyspell-buffer : vérifier le buffer entier
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
            (expand-file-name "ispell-personal" user-emacs-directory))))

;; Flyspell en mode texte (Org, Markdown, etc.)
(dolist (hook '(text-mode-hook
               org-mode-hook
               markdown-mode-hook))
  (add-hook hook #'flyspell-mode))

;; Flyspell-prog en mode programmation (vérifie commentaires + strings)
(add-hook 'prog-mode-hook #'flyspell-prog-mode)

;; Performance flyspell : ne pas vérifier les blocs source Org
(with-eval-after-load 'flyspell
  (setopt flyspell-issue-message-flag nil    ; pas de message par mot vérifié
          flyspell-issue-welcome-flag nil))   ; pas de message au démarrage

(provide 'my-editing)
;;; my-editing.el ends here

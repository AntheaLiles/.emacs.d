;;; early-init.el --- Pre-initialisation -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Télémétrie (sur demande), ramasse-miettes, modules maison (user-lisp),
;; compilation native, désactivation de l'UI avant le premier rendu.

;;; Code:

;;;; TÉLÉMÉTRIE — sur demande
;; Le collecteur (perf/perf-start.el) fait tourner le profileur natif en
;; permanence : il ne se charge que pour une campagne de mesure, activée par
;; le fichier perf/enabled (non versionné) ou la variable d'environnement
;; EMACS_PERF.  Démarrer une campagne : touch ~/.emacs.d/perf/enabled
(defvar my/perf-enabled
  (or (getenv "EMACS_PERF")
      (file-exists-p (expand-file-name "perf/enabled" user-emacs-directory)))
  "Non-nil when the long-running performance collector is loaded.")
(when my/perf-enabled
  (load (expand-file-name "perf/perf-start.el" user-emacs-directory)))

;;;; RAMASSE-MIETTES
;; Désactivé pendant le démarrage, puis seuil fixe et collecte pendant
;; l'inactivité (ce que faisait gcmh, en quelques lignes).
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(defconst my/gc-cons-threshold (* 64 1024 1024)
  "Allocation threshold between two garbage collections after startup.")

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold my/gc-cons-threshold
                  gc-cons-percentage 0.1)
            ;; Collecter pendant les pauses plutôt qu'en pleine frappe.
            (run-with-idle-timer 10 t #'garbage-collect)))

;;;; FILE-NAME-HANDLER-ALIST — vidé pendant le démarrage
(defvar my/file-name-handler-alist-backup file-name-handler-alist
  "Sauvegarde de `file-name-handler-alist' pour restauration post-boot.")
(setq file-name-handler-alist nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist
                  (delete-dups
                   (append my/file-name-handler-alist-backup
                           file-name-handler-alist)))))

;;;; MODULES MAISON (Emacs 31 : user-lisp)
;; lisp/ est traité comme un répertoire de paquets locaux : ajouté au
;; load-path et ses autoloads chargés avant init.el (remplace compile-angel).
;;
;; La COMPILATION, elle, n'a pas lieu ici mais après l'initialisation
;; (init.el, `my/user-lisp-compile') : avant init.el, compiler un module
;; exécute ses `require' et chargeait Org avant qu'Elpaca n'ait activé les
;; paquets (« Cannot load citar-org »).  D'ici là, `load-prefer-newer'
;; garantit qu'un .el plus récent que son .elc (après un git pull) est
;; chargé à la place du .elc périmé.
(setopt user-lisp-directory (expand-file-name "lisp/" user-emacs-directory)
        user-lisp-auto-scrape nil)
(setq load-prefer-newer t)

;;;; COMPILATION NATIVE
;; Vitesse, compilation JIT et répertoire eln-cache/ : valeurs par défaut.
(setq native-comp-async-report-warnings-errors 'silent)

;; Désactiver package.el (on utilise Elpaca)
(setq package-enable-at-startup nil)

;;;; UI — désactivée AVANT le premier frame
;; (Plus d'`inhibit-redisplay' : une question posée pendant l'init, par Elpaca
;; ou pour une grammaire tree-sitter, restait invisible et Emacs semblait
;; figé ; l'interface est déjà masquée par `default-frame-alist'.)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(left-fringe . 8) default-frame-alist)
(push '(right-fringe . 8) default-frame-alist)
(push '(internal-border-width . 8) default-frame-alist)
(push '(undecorated . t) default-frame-alist)

(setq frame-inhibit-implied-resize t)
(setq frame-title-format nil)

;; Rendu typographique
;; Soulignement positionné sous la ligne de descente (plus esthétique)
(setq x-underline-at-descent-line t)

;; Ne pas compiler le fichier site-default.el au démarrage
(setq site-run-file nil)

;; Startup silencieux
(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil)

(setq initial-major-mode 'fundamental-mode)

(provide 'early-init)
;;; early-init.el ends here

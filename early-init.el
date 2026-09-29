;;; early-init.el --- Pre-initialisation -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Configuration de la compilation native.
;; Désactivation de l'UI avant le premier rendu.

;;; Code:

;; Profilage
(load (expand-file-name "perf/perf-start.el" user-emacs-directory))

;; Garbage Collector — désactivé pendant le boot
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; …et rétabli après le boot.  gcmh (init.el) ne gère que le seuil : sans
;; ceci, `gc-cons-percentage' resterait à 0.6 toute la session (un GC
;; seulement après une allocation de 60 % du tas, d'où de longues pauses),
;; et le seuil resterait infini si gcmh ne se chargeait pas (premier
;; lancement, échec d'Elpaca).  gcmh, une fois actif, reprend la main.
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-percentage 0.1)
            (unless (bound-and-true-p gcmh-mode)
              (setq gc-cons-threshold (* 16 1024 1024)))))

;; file-name-handler-alist — vidé pendant le boot
(defvar my/file-name-handler-alist-backup file-name-handler-alist
  "Sauvegarde de `file-name-handler-alist' pour restauration post-boot.")
(setq file-name-handler-alist nil)

;; inhibit-redisplay — pas de rendu pendant le boot
(setq inhibit-redisplay t)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist
                  (delete-dups
                   (append my/file-name-handler-alist-backup
                           file-name-handler-alist)))
            (setq inhibit-redisplay nil)
            ;; Forcer un redraw complet maintenant que tout est chargé
            (redraw-frame)))

;; Compilation native (Emacs 30.2)
(when (featurep 'native-compile)
  (setq native-comp-jit-compilation t)
  ;; (0 = désactivé, 1 = basique, 2 = complet, 3 = agressif/risqué)
  (setq native-comp-speed 2)
  (setq native-comp-async-report-warnings-errors 'silent)
  (when (fboundp 'startup-redirect-eln-cache)
    (startup-redirect-eln-cache
     (expand-file-name "eln-cache/" user-emacs-directory))))

;; Désactiver package.el (on utilise Elpaca)
(setq package-enable-at-startup nil)

;; Désactivation de l'UI AVANT le premier frame
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

;;;; USER-LISP (Emacs 31) — désactivé
;; La compilation et le load-path de lisp/ sont gérés par compile-angel,
;; qui couvre en outre les paquets elpaca et fait de la native-compilation.
;; user-lisp-auto-scrape ferait double emploi sans apporter de couverture.
(setopt user-lisp-auto-scrape nil)

;; Startup silencieux
(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil)

(setq initial-major-mode 'fundamental-mode)

(provide 'early-init)
;;; early-init.el ends here

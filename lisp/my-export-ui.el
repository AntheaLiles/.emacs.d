;;; my-export-ui.el --- Export UI in side window -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Affiche le log d'export dans une fenêtre à droite,
;; puis remplace par le PDF quand la compilation réussit.
;;
;; Guards :
;;   - N'active le split que si la fenêtre est assez large (>120 colonnes)
;;   - N'active le split que pour les exports asynchrones
;;   - En export synchrone ou fenêtre étroite : comportement Org standard

;;; Code:

(defvar my/export-pdf-file nil
  "Path of the PDF being exported.")

(defvar my/export-window nil
  "Window used for export log then PDF display.")

(defvar my/export-watch-timer nil
  "Timer watching the export process for completion.")

(defun my/org-export-pdf-open (orig-fun &rest args)
  "Advice to show log in right window then switch to PDF.
Only activates for async exports with sufficient window width."
  (let* ((org-file (buffer-file-name))
         (pdf-file (and org-file
                        (concat (file-name-sans-extension org-file) ".pdf"))))
    (setq my/export-pdf-file pdf-file)
    ;; Buffer sans fichier : pas de PDF à suivre, comportement Org standard.
    (if (and pdf-file
             org-export-in-background
             (> (window-total-width) 120))
        (progn
          (setq my/export-window (split-window-right))
          (apply orig-fun args)
          (run-with-timer 1 nil #'my/show-export-log-right)
          ;; Un export relancé avant la fin du précédent ne doit pas
          ;; laisser tourner l'ancien minuteur indéfiniment.
          (when (timerp my/export-watch-timer)
            (cancel-timer my/export-watch-timer))
          (setq my/export-watch-timer
                (run-with-timer 2 2 #'my/watch-export-process)))
      (apply orig-fun args))))

(defun my/show-export-log-right ()
  "Display export log in the right window."
  (let ((buf (get-buffer "*Org Export Process*")))
    (when (and buf (window-live-p my/export-window))
      (set-window-buffer my/export-window buf)
      (with-current-buffer buf
        (goto-char (point-max))
        (set-window-point my/export-window (point-max))))))

(defun my/watch-export-process ()
  "Watch for export completion, then replace log with PDF."
  (let ((proc-buf (get-buffer "*Org Export Process*")))
    (cond
     ;; Processus terminé
     ((or (null proc-buf)
          (and proc-buf (not (get-buffer-process proc-buf))))
      ;; Annuler le timer proprement
      (when (timerp my/export-watch-timer)
        (cancel-timer my/export-watch-timer)
        (setq my/export-watch-timer nil))
      (cond
       ;; Succès — PDF existe et récent (moins de 60s)
       ((and my/export-pdf-file
             (file-exists-p my/export-pdf-file)
             (< (float-time
                 (time-subtract nil
                                (file-attribute-modification-time
                                 (file-attributes my/export-pdf-file))))
                60))
        (when (window-live-p my/export-window)
          (select-window my/export-window)
          (condition-case nil
              (find-file my/export-pdf-file)
            (error nil)))
        (message "Export complete: %s"
                 (file-name-nondirectory my/export-pdf-file)))
       ;; Échec — garder le log visible
       (t (message "Export failed. See *Org Export Process*"))))
     ;; Processus en cours — scroll le log
     (proc-buf
      (when (window-live-p my/export-window)
        (with-current-buffer proc-buf
          (goto-char (point-max))
          (set-window-point my/export-window (point-max))))))))

;; Activer l'advice
(with-eval-after-load 'ox-latex
  (advice-add 'org-latex-export-to-pdf :around #'my/org-export-pdf-open))

(provide 'my-export-ui)
;;; my-export-ui.el ends here

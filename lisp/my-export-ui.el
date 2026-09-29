;;; my-export-ui.el --- Export UI in side window -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Affiche le journal d'un export PDF/UA asynchrone dans une fenêtre à
;; droite, puis le remplace par le PDF quand la compilation réussit.
;;
;; Aucun minuteur : Org appelle `org-export-add-to-stack' à chaque étape
;; d'un export asynchrone, et c'est là qu'on se branche.
;;   - lancement : SOURCE est le buffer du processus, PROCESS est vivant ;
;;   - succès    : SOURCE est le chemin du fichier produit (le PDF) ;
;;   - échec     : SOURCE est le buffer du processus, PROCESS est terminé.
;;
;; Garde-fous : la fenêtre n'est ouverte que pour un export asynchrone et
;; une fenêtre assez large (> 120 colonnes) ; sinon comportement Org
;; standard (pile d'export, C-c C-e &).

;;; Code:

(defvar my/export-pdf-file nil
  "Path of the PDF being exported asynchronously, or nil.")

(defvar my/export-window nil
  "Window used for the export log, then the PDF.")

(defun my/export-ui-start (orig-fun &optional async subtreep &rest args)
  "Around advice for `my/pdfua-export-to-pdf': prepare the side window.
ORIG-FUN is called with ASYNC, SUBTREEP and ARGS unchanged."
  (let ((pdf (and buffer-file-name
                  (concat (file-name-sans-extension
                           (org-export-output-file-name ".tex" subtreep))
                          ".pdf"))))
    (if (and async pdf (> (window-total-width) 120))
        (progn
          (setq my/export-pdf-file (expand-file-name pdf)
                my/export-window (split-window-right))
          (apply orig-fun async subtreep args))
      (apply orig-fun async subtreep args))))

(defun my/export-ui--show (window buffer-or-file)
  "Show BUFFER-OR-FILE in WINDOW, scrolled to its end if it is a buffer."
  (when (window-live-p window)
    (if (bufferp buffer-or-file)
        (progn
          (set-window-buffer window buffer-or-file)
          (with-current-buffer buffer-or-file
            (set-window-point window (point-max))))
      (with-selected-window window
        (find-file buffer-or-file)))))

(defun my/export-ui-on-stack (source _backend &optional process)
  "After advice for `org-export-add-to-stack', following one export.
SOURCE and PROCESS tell the stage of the export (see Commentary)."
  (when my/export-pdf-file
    (cond
     ;; Lancement : afficher le journal du processus
     ((and (bufferp source) (processp process) (process-live-p process))
      (my/export-ui--show my/export-window source))
     ;; Succès : remplacer le journal par le PDF
     ((and (stringp source)
           (string= (expand-file-name source) my/export-pdf-file))
      (my/export-ui--show my/export-window source)
      (message "Export terminé : %s" (file-name-nondirectory source))
      (setq my/export-pdf-file nil))
     ;; Échec : garder le journal visible
     ((and (bufferp source) (processp process))
      (my/export-ui--show my/export-window source)
      (message "Échec de l'export : voir %s" (buffer-name source))
      (setq my/export-pdf-file nil)))))

(advice-add 'my/pdfua-export-to-pdf :around #'my/export-ui-start)
(with-eval-after-load 'ox
  (advice-add 'org-export-add-to-stack :after #'my/export-ui-on-stack))

(provide 'my-export-ui)
;;; my-export-ui.el ends here

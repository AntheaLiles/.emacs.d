;;; my-lean.el --- Lean 4 and Lake: editing, builds, errors -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Complète lean4-mode (variante Eglot, voir init.el) pour les projets Lake
;; comme k7pl :
;;
;;   - `my/lean-setup' (lean4-mode-hook) : lignes de 100 colonnes (règle de
;;     k7pl et de Mathlib), `compile-command' = « lake build » ;
;;   - `my/lake' (M-x, C-x p L) : lance « lake CMD » À LA RACINE du projet.
;;     Lake ne remonte pas l'arborescence : lancé depuis src/K7pl/, il échoue
;;     (« no configuration file »), et les chemins relatifs de ses messages
;;     ne se résoudraient pas hors de la racine ;
;;   - analyse des messages de Lake dans *compilation*, qui écrit
;;     « error: src/K7pl/Arith.lean:12:3: … » : le mot error/warning précède le
;;     chemin, et la regexp « gnu » d'Emacs ne distingue alors pas les
;;     avertissements des erreurs.
;;
;; Pour compiler sans `my/lake', utiliser C-x p c (project-compile), qui
;; s'exécute à la racine du projet, et non M-x compile depuis un sous-dossier.

;;; Code:

(require 'compile)

(defconst my/lean-fill-column 100
  "Maximum line length of k7pl's Lean files (also Mathlib's).")

(defcustom my/lake-commands
  '("build" "test" "lint" "exe cache get" "update" "clean")
  "Lake commands offered by `my/lake' (any other command can be typed)."
  :type '(repeat string)
  :group 'compilation)

(defvar my/lake-history nil
  "Minibuffer history of `my/lake'.")

;;;; ANALYSE DES MESSAGES
(add-to-list 'compilation-error-regexp-alist-alist
             '(lake
               "^\\(?:\\(error\\)\\|\\(warning\\)\\|\\(info\\)\\): \\([^ \n:][^:\n]*\\):\\([0-9]+\\):\\([0-9]+\\):"
               4 5 6 (2 . 3)))
(add-to-list 'compilation-error-regexp-alist 'lake)

;;;; RACINE ET COMMANDES
(defun my/lake-root (&optional file)
  "Return the Lake workspace root containing FILE (default: current file).
A file inside .lake/packages/ belongs to the workspace that holds .lake/.
Return nil outside any Lake project."
  (let* ((path (expand-file-name (or file buffer-file-name default-directory)))
         (cut (string-match "/\\.lake/" path))
         (start (if cut (substring path 0 (1+ cut)) path)))
    (locate-dominating-file
     start
     (lambda (dir)
       (or (file-exists-p (expand-file-name "lakefile.lean" dir))
           (file-exists-p (expand-file-name "lakefile.toml" dir)))))))

;;;###autoload
(defun my/lake (command)
  "Run \"lake COMMAND\" at the root of the current Lake project."
  (interactive
   (list (completing-read "lake: " my/lake-commands nil nil nil
                          'my/lake-history "build")))
  (let ((root (or (my/lake-root)
                  (user-error "Pas de projet Lake (lakefile.lean ou lakefile.toml)"))))
    (let ((default-directory root))
      (compile (concat "lake " command)))))

;;;###autoload
(defun my/lean-setup ()
  "Set up a Lean 4 buffer: 100-column lines, \"lake build\" as compile command."
  (setq-local fill-column my/lean-fill-column
              compile-command "lake build"))

(provide 'my-lean)
;;; my-lean.el ends here

;;; my-appearance-test.el --- Tests for my-appearance -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Ancien `my/ml-diagnose' (état des lieux interactif de la mode-line),
;; devenu des assertions : API natives d'Emacs 31, résolution des couleurs
;; Modus, polices, glyphes, segments.  Seul le jugement visuel des glyphes
;; (« tofu » ou non) reste hors de portée d'un test : les fontes ne sont
;; vérifiées qu'en session graphique.
;;
;; Usage, depuis la racine du dépôt :
;;   emacs -Q --batch -L lisp -l tests/my-appearance-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'seq)
(require 'flymake)
(require 'project)
(require 'ispell)               ; variables spéciales : `let' dynamique
(require 'my-appearance)

(defconst my/test--themes '(modus-vivendi modus-operandi)
  "Themes between which `modus-themes-to-toggle' switches.")

;;;; API natives (section « Variables » du diagnostic)

(ert-deftest my/ml-native-variables ()
  "Mode line and theme variables used by the configuration exist."
  (skip-unless (>= emacs-major-version 31))
  (dolist (sym '(mode-line-format-right-align mode-line-right-align-edge
                 mode-line-collapse-minor-modes mode-line-modes-delimiters
                 mode-line-position-column-line-format project-mode-line
                 flymake-mode-line-counters modus-themes-headings))
    (should (boundp sym))))

(ert-deftest my/ml-native-functions ()
  "Functions called by the mode line are available."
  (skip-unless (>= emacs-major-version 31))
  (dolist (fn '(mode-line-window-selected-p modus-themes-get-color-value
                vc-root-dir vc-file-getprop project-current project-name))
    (should (fboundp fn))))

;;;; Couleurs (section « Couleurs résolues »)

(ert-deftest my/ml-palette-names-exist-in-both-themes ()
  "Every colour name of `my/ml-palette-map' exists in both Modus themes.
A missing name silently falls back to :inherit and hides a typo."
  (skip-unless (>= emacs-major-version 31))
  (pcase-dolist (`(,face . ,color) my/ml-palette-map)
    (dolist (theme my/test--themes)
      (should (stringp (modus-themes-get-color-value color t theme))))
    (should (facep face))))

(ert-deftest my/ml-faces-resolve-to-colours ()
  "`my/ml-set-faces' gives each mode line face a concrete foreground."
  (skip-unless (>= emacs-major-version 31))
  (my/ml-set-faces)
  (pcase-dolist (`(,face . ,_) my/ml-palette-map)
    (should (stringp (face-attribute face :foreground nil t)))))

;;;; Fontes (section « Fontes »)

(ert-deftest my/ml-fonts-families ()
  "Default, fixed-pitch and variable-pitch faces resolve to a family."
  (skip-unless (display-graphic-p))
  (dolist (face '(default fixed-pitch variable-pitch))
    (should (stringp (face-attribute face :family nil t)))))

(ert-deftest my/ml-font-first-available ()
  "`my/font-first-available' ignores missing families and accepts a string."
  (should-not (my/font-first-available '("Police Qui N'Existe Pas")))
  (should-not (my/font-first-available "Police Qui N'Existe Pas")))

;;;; Glyphes (section « Glyphes »)

(ert-deftest my/ml-icons-are-single-characters ()
  "Every icon is one character; Nerd Font glyphs sit in the redirected ranges."
  (pcase-dolist (`(,name . ,glyph) my/ml-icons)
    (should (and (stringp glyph) (= (length glyph) 1)))
    (let ((code (aref glyph 0)))
      (should (or (< code 128)          ; ASCII : `remote'
                  (<= #xe000 code #xf8ff)
                  (<= #xf0000 code #xfffff))))
    (should (equal glyph (my/ml-icon name)))))

(ert-deftest my/ml-icons-displayable ()
  "Each glyph has a font in a graphical session with the symbols font."
  (skip-unless (and (display-graphic-p)
                    (my/font-first-available my/font-symbols)))
  (pcase-dolist (`(,_ . ,glyph) my/ml-icons)
    (should (char-displayable-p (aref glyph 0)))))

;;;; Segments et variantes

(ert-deftest my/ml-formats-complete ()
  "Every variant carries the buffer name and the modes segment.
`my/ml-compose' ignores an unknown key without error, so a typo in a variant
would otherwise only show up as a missing segment."
  (pcase-dolist (`(,_ . ,format) my/ml-formats)
    (should (consp format))
    (should (memq 'mode-line-buffer-identification format))
    (should (memq 'mode-line-modes format))
    (should (memq 'mode-line-format-right-align format)))
  (should-not (my/ml-compose 'absent)))

(ert-deftest my/ml-formats-render ()
  "Each variant renders to a string without error in a file buffer."
  (let ((file (make-temp-file "ml-" nil ".txt")))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name file)
          (my/ml-update-caches)
          (pcase-dolist (`(,variant . ,_) my/ml-formats)
            (my/ml-use variant)
            (should (stringp (format-mode-line mode-line-format)))))
      (delete-file file))))

(ert-deftest my/ml-state-nominal-and-deviant ()
  "State indicator: saved, modified, read-only, then non-standard encoding."
  (let ((file (make-temp-file "ml-" nil ".txt")))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name file)
          (set-buffer-modified-p nil)
          (should (string-match-p (regexp-quote (my/ml-icon 'saved)) (my/ml-state)))
          (insert "x")
          (should (string-match-p (regexp-quote (my/ml-icon 'modified)) (my/ml-state)))
          (set-buffer-modified-p nil)
          (setq buffer-read-only t)
          (should (string-match-p (regexp-quote (my/ml-icon 'readonly)) (my/ml-state)))
          (setq buffer-read-only nil
                buffer-file-coding-system 'iso-latin-1-dos)
          (should (string-match-p "CRLF" (my/ml-state))))
      (delete-file file))))

(ert-deftest my/ml-language-shows-dictionary ()
  "The language segment reports the spelling dictionary."
  (let ((ispell-local-dictionary "fr_FR") (current-input-method-title nil))
    (should (string-match-p "fr_FR" (my/ml-language))))
  (let ((ispell-local-dictionary nil) (ispell-dictionary nil)
        (ispell-current-dictionary nil) (current-input-method-title nil))
    (should (equal (my/ml-language) ""))))

(provide 'my-appearance-test)
;;; my-appearance-test.el ends here

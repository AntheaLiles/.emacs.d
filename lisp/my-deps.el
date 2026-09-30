;;; my-deps.el --- System dependency checker -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;; Vérifie, à la demande, les dépendances système de la configuration :
;; exécutables, fichiers, paquets LaTeX du préambule, polices.
;;
;;   M-x my/deps-check   — rapport dans *Dépendances* (rien si tout va bien)
;;
;; Synchrone et sans cache : la vérification dure une à deux secondes et ne
;; se lance que sur demande (autrefois : hachage BLAKE3 du dépôt et processus
;; Emacs en arrière-plan, 440 lignes pour le même résultat).

;;; Code:

(require 'cl-lib)
(require 'my-paths)

;;;; DÉCLARATION
;; Exécutables : (NOM EXÉCUTABLE REQUIS USAGE INSTALLATION)
(defvar my/deps-binaries
  '(("Git"          "git"          t   "Elpaca, magit, diff-hl, project.el"
     "sudo apt install git")
    ("hunspell"     "hunspell"     t   "flyspell — dictionnaires fr_FR et en_US"
     "sudo apt install hunspell hunspell-fr hunspell-en-us")
    ("LuaLaTeX"     "lualatex"     t   "export Org → PDF/UA"
     "TeX Live (texlive-luatex, texlive-latex-extra, texlive-lang-french)")
    ("latexmk"      "latexmk"      t   "compilation LaTeX multi-passes"
     "sudo apt install latexmk")
    ("kpsewhich"    "kpsewhich"    t   "recherche des paquets LaTeX"
     "fourni par TeX Live")
    ("ripgrep"      "rg"           nil "consult-ripgrep, howm"
     "sudo apt install ripgrep")
    ("fd"           "fdfind"       nil "consult-find"
     "sudo apt install fd-find")
    ("fc-list"      "fc-list"      nil "vérification des polices"
     "sudo apt install fontconfig")
    ("drawio"       "drawio"       nil "conversion .drawio → .pdf à l'export"
     "https://github.com/jgraph/drawio-desktop/releases")
    ("Lake (Lean 4)" "lake"        nil "lean4-mode : serveur « lake serve »"
     "curl https://elan.lean-lang.org/elan-init.sh -sSf | sh")
    ("emacs-lsp-booster" "emacs-lsp-booster" nil "eglot-booster"
     "cargo install emacs-lsp-booster")
    ("bash-language-server" "bash-language-server" nil "Eglot — Bash"
     "npm install -g bash-language-server")
    ("yaml-language-server" "yaml-language-server" nil "Eglot — YAML"
     "npm install -g yaml-language-server")
    ("typescript-language-server" "typescript-language-server" nil
     "Eglot — TypeScript" "npm install -g typescript-language-server typescript")
    ("perlnavigator" "perlnavigator" nil "Eglot — Perl"
     "npm install -g perlnavigator-server"))
  "Executables checked by `my/deps-check': (NAME EXEC REQUIRED USAGE INSTALL).")

(defun my/deps--repo-file (file)
  "Return FILE, relative to `user-emacs-directory', as an absolute path."
  (expand-file-name file user-emacs-directory))

;; Fichiers : (DESCRIPTION CHEMIN REQUIS)
(defun my/deps-files ()
  "Return the files checked by `my/deps-check': (DESC PATH REQUIRED)."
  (append
   `(("Préambule commun"      ,(my/deps--repo-file "latex/preamble-common.tex") t)
     ("Préambule article-ua"  ,(my/deps--repo-file "latex/preamble-article-ua.tex") t)
     ("Préambule book-ua"     ,(my/deps--repo-file "latex/preamble-book-ua.tex") t)
     ("Config latexmk"        ,(my/deps--repo-file "latex/latexmkrc") t)
     ("Style CSL"             ,(my/deps--repo-file "csl/iso-ieee-localised-collapsed.csl") t)
     ("Locales CSL"           ,my/csl-locales-dir nil)
     ("Icône ORCID"           ,(my/deps--repo-file "assets/ORCID-iD-icon-BW-16x16.png") nil)
     ("Icône ORCID non authentifié"
      ,(my/deps--repo-file "assets/ORCID-iD-icon-unauth-BW-16x16.png") nil)
     ("Glossaire"             ,my/glossary-file nil))
   (mapcar (lambda (f) (list "Bibliographie CSL-JSON (Org, citar)" f t))
           my/bibliography-files)
   (mapcar (lambda (f) (list "Bibliographie BibTeX (AUCTeX, RefTeX)" f nil))
           my/bibtex-files)))

;;;; EXTRACTION DEPUIS LE PRÉAMBULE
(defun my/deps--preamble-files ()
  "Return the common preamble and the LaTeX modules (latex/modules/)."
  (let ((modules (my/deps--repo-file "latex/modules/")))
    (cons (my/deps--repo-file "latex/preamble-common.tex")
          (and (file-directory-p modules)
               (directory-files modules t "\\`[^.].*\\.tex\\'")))))

(defun my/deps--preamble-matches (regexp)
  "Return the first groups of REGEXP matches in the preamble and modules."
  (mapcan (lambda (f) (my/deps--file-matches f regexp))
          (my/deps--preamble-files)))

(defun my/deps--file-matches (preamble regexp)
  "Return the first groups of REGEXP matches in the LaTeX file PREAMBLE."
  (when (file-exists-p preamble)
    (with-temp-buffer
      ;; % ouvre un commentaire jusqu'à la fin de la ligne
      (let ((table (make-syntax-table)))
        (modify-syntax-entry ?% "<" table)
        (modify-syntax-entry ?\n ">" table)
        (set-syntax-table table))
      (insert-file-contents preamble)
      (cl-loop while (re-search-forward regexp nil t)
               ;; `syntax-ppss' déplace le point et peut écraser les
               ;; données de correspondance : on préserve les deux.
               unless (nth 4 (save-excursion
                               (save-match-data (syntax-ppss (match-beginning 0)))))
               collect (match-string 1)))))

(defun my/deps--latex-packages ()
  "Return the LaTeX packages loaded by the common preamble and the modules."
  (delete-dups
   (mapcan (lambda (s) (mapcar #'string-trim (split-string s ",")))
           (my/deps--preamble-matches
            "\\\\\\(?:usepackage\\|RequirePackage\\)\\(?:\\[[^]]*\\]\\)?{\\([^}]+\\)}"))))

(defun my/deps--fonts ()
  "Return the font files of the preamble and the Emacs font family."
  (append (my/deps--preamble-matches
           "\\(?:ItalicFont\\|BoldFont\\|BoldItalicFont\\)=\\([^],]+\\)")
          (my/deps--preamble-matches
           "\\\\set\\(?:main\\|mono\\|math\\)font{\\([^}]+\\)}")
          (list "JetBrainsMonoNL Nerd Font Propo")))

;;;; VÉRIFICATIONS
(defun my/deps--kpsewhich-p (file)
  "Non-nil if kpsewhich finds FILE."
  (and (executable-find "kpsewhich")
       (with-temp-buffer
         (and (zerop (call-process "kpsewhich" nil t nil file))
              (> (buffer-size) 0)))))

(defun my/deps--font-p (font)
  "Non-nil if FONT, a file name or a family, is installed."
  (if (string-match-p "\\.\\(?:otf\\|ttf\\)\\'" font)
      (or (my/deps--kpsewhich-p font)
          (and (executable-find "fc-list")
               (with-temp-buffer
                 (call-process "fc-list" nil t nil)
                 (goto-char (point-min))
                 (search-forward (concat "/" font) nil t))))
    (or (not (executable-find "fc-list"))   ; invérifiable : pas de faux manque
        (with-temp-buffer
          (call-process "fc-list" nil t nil (concat ":family=" font))
          (> (buffer-size) 0)))))

(defun my/deps-run ()
  "Run every check.  Return a plist of missing dependencies."
  (let (req-bin opt-bin req-files opt-files)
    (pcase-dolist (`(,name ,exec ,req ,usage ,install) my/deps-binaries)
      (unless (executable-find exec)
        (push (list name usage install) (if req req-bin opt-bin))))
    (pcase-dolist (`(,desc ,path ,req) (my/deps-files))
      (unless (file-exists-p path)
        (push (list desc path) (if req req-files opt-files))))
    (list :required-binaries (nreverse req-bin)
          :optional-binaries (nreverse opt-bin)
          :required-files (nreverse req-files)
          :optional-files (nreverse opt-files)
          :latex-packages (and (executable-find "kpsewhich")
                               (cl-remove-if (lambda (p) (my/deps--kpsewhich-p (concat p ".sty")))
                                             (my/deps--latex-packages)))
          :fonts (cl-remove-if #'my/deps--font-p (delete-dups (my/deps--fonts))))))

;;;; RAPPORT
(defun my/deps--section (title face items fmt)
  "Insert section TITLE in FACE listing ITEMS formatted by FMT."
  (when items
    (insert (propertize title 'face face) "\n\n")
    (dolist (it items) (insert (funcall fmt it)))
    (insert "\n")))

;;;###autoload
(defun my/deps-check ()
  "Check the system dependencies of this configuration and report what is missing."
  (interactive)
  (let ((r (my/deps-run)))
    (if (cl-loop for (_k v) on r by #'cddr never v)
        (message "Toutes les dépendances sont présentes.")
      (with-current-buffer (get-buffer-create "*Dépendances*")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (my/deps--section "REQUIS — Exécutables" 'error (plist-get r :required-binaries)
                            (lambda (d) (format "  ✗ %s — %s\n    %s\n" (nth 0 d) (nth 1 d) (nth 2 d))))
          (my/deps--section "REQUIS — Fichiers" 'error (plist-get r :required-files)
                            (lambda (d) (format "  ✗ %s\n    %s\n" (nth 0 d) (nth 1 d))))
          (my/deps--section "OPTIONNEL — Exécutables" 'warning (plist-get r :optional-binaries)
                            (lambda (d) (format "  ○ %s — %s\n    %s\n" (nth 0 d) (nth 1 d) (nth 2 d))))
          (my/deps--section "OPTIONNEL — Fichiers" 'warning (plist-get r :optional-files)
                            (lambda (d) (format "  ○ %s\n    %s\n" (nth 0 d) (nth 1 d))))
          (my/deps--section "Paquets LaTeX introuvables" 'warning (plist-get r :latex-packages)
                            (lambda (p) (format "  ○ %s\n" p)))
          (my/deps--section "Polices introuvables" 'warning (plist-get r :fonts)
                            (lambda (f) (format "  ○ %s\n" f)))
          (special-mode)
          (goto-char (point-min)))
        (display-buffer (current-buffer))))))

(provide 'my-deps)
;;; my-deps.el ends here

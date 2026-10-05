# Consignes pour Claude Code

Dépôt : configuration Emacs 31.1 personnelle (vanilla + Elpaca), orientée
Org-mode, LaTeX (LuaLaTeX, PDF/UA-2) et recherche. Utilisée sous WSL Ubuntu.
Objectif de la collaboration : **améliorer et fiabiliser** la configuration.

## Règles impératives

- **Le dépôt est `~/.emacs.d/`.** Les chemins sont relatifs à
  `user-emacs-directory` (`lisp/`, `latex/`, `perf/`). Ne jamais déplacer un
  fichier sans mettre à jour toutes ses références (`grep -rn` sur le nom).
- **REUSE.** Tout nouveau fichier doit être couvert : en-tête SPDX pour `.el`
  (LGPL-3.0-or-later) et `latex/` (CC-BY-SA-4.0) ; entrée dans `REUSE.toml`
  pour la documentation (GFDL-1.3-or-later) et les métadonnées (CC0-1.0).
  `reuse lint` doit passer avant chaque commit. Voir `LICENSE.md`.
- **Ne rien versionner de généré** (voir `.gitignore`) : `.elc`, `elpaca/`,
  `custom.el`, historiques, données `perf/*.tsv`.
- **CHANGELOG.md** : consigner chaque changement notable sous `[Non publié]`.
- Ne pas lire ni afficher `history`, `custom.el`, `recentf`, `tramp` : ils
  peuvent contenir des données personnelles.

## Conventions Emacs Lisp

- Ligne 1 : `;;; fichier.el --- Résumé -*- lexical-binding: t; -*-`, puis
  l'en-tête SPDX, `;;; Commentary:`, `;;; Code:`, `(provide 'fichier)`,
  `;;; fichier.el ends here`.
- Préfixe `my/` pour tout symbole maison ; `my/…--…` pour l'interne.
- Commentaires en français, docstrings en anglais (première ligne complète,
  arguments en MAJUSCULES).
- Sections repérées par `;;;;` (utilisées par outline et `consult-outline`).
- `use-package` : différé par défaut (`use-package-always-defer t`) ; éviter
  `:demand t` sauf nécessité au démarrage.
- Préférer `setopt` pour les options `defcustom`, `setq` pour les variables.
- Les hooks d'export Org modernes sont `org-export-before-*-functions`
  (les `-hook` sont obsolètes depuis Org 9.6).

## Vérifications

```sh
reuse lint
emacs -Q --batch -l scripts/check.el      # parenthèses + compilation
emacs -Q --batch --eval '(setq my/perf-root (make-temp-file "perf-" t))' \
      -l perf/perf-start.el -l perf/perf-self-test.el \
      -f ert-run-tests-batch-and-exit
emacs -Q --batch -L lisp -l tests/my-export-config-test.el \
      -f ert-run-tests-batch-and-exit
emacs -Q --batch -L lisp -l tests/my-config-test.el \
      -f ert-run-tests-batch-and-exit
tests/regression/run.sh                   # export + LuaLaTeX réels
```

Un changement du préambule LaTeX, de l'export ou du style CSL se valide par
une vraie compilation LuaLaTeX (`make regress`), pas seulement par l'export
`.tex`.

Ou la commande `/check`. La version de référence est **Emacs 31.1**
(celle utilisée au quotidien et par la CI). L'Emacs de l'environnement cloud
peut être plus ancien : un résultat local n'y vaut pas validation, seule la
CI sous 31.1 fait foi.

## Architecture

- `early-init.el` → télémétrie (`perf/perf-start.el`), GC, UI, native-comp.
- `init.el` → Elpaca, puis `require` des modules `lisp/` dans l'ordre :
  paths, performance, editing, windows, appearance, folding, formatting,
  export-ui ; puis déclarations `use-package`.
- `lisp/` est le `user-lisp-directory` d'Emacs 31 (déclaré dans
  `early-init.el`) : autoloads avant `init.el`, compilation APRÈS
  (`my/user-lisp-compile`, jamais avant l'activation d'Elpaca).
  `scripts/check.el` compile chaque module seul et refuse tout
  avertissement, visible sinon dans *Compile-Log* au démarrage.
- Export PDF/UA : backend dérivé `pdfua` (`C-c C-e u`) défini dans
  `lisp/my-export-config.el` ; classes `article-ua` et `book-ua`
  (`latex/preamble-{article,book}-ua.tex` → `preamble-common.tex`) ;
  bibliographie CSL (`csl/`, CSL-JSON). La chaîne s'active par la classe
  (`my/pdfua-active-p`) : elle vaut aussi pour `C-c C-e l` sur un document
  `-ua`, jamais pour `article` ni Beamer. Modules de préambule optionnels :
  `latex/modules/*.tex`, par `#+LATEX_MODULES:`.
- Export Typst : backend dérivé `my-typst` (`C-c C-e T`), module
  `lisp/my-export-typst.el` au-dessus du paquet `ox-typst` (Elpaca) ; le
  module n'agit que si `ox-typst` est présent (tests ignorés sinon). Typst lit
  le `.bib` et le style CSL, pas le CSL-JSON.
- Export Org asynchrone : processus séparé initialisé par
  `lisp/my-export-async.el` (ne lit pas `init.el`) ; il charge `my-babel`
  et `my-export-config`, comme la session.
- Chemins externes (wiki, bibliographie, Zotero) : **uniquement** dans
  `lisp/my-paths.el`.

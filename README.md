# .emacs.d — configuration Emacs pour la recherche scientifique

[![REUSE](https://github.com/AntheaLiles/.emacs.d/actions/workflows/reuse.yml/badge.svg)](https://github.com/AntheaLiles/.emacs.d/actions/workflows/reuse.yml)
[![Lint](https://github.com/AntheaLiles/.emacs.d/actions/workflows/lint.yml/badge.svg)](https://github.com/AntheaLiles/.emacs.d/actions/workflows/lint.yml)

Configuration personnelle d'**Emacs 31.1** (vanilla, sans framework), pensée
pour la rédaction scientifique : Org-mode, LaTeX (LuaLaTeX, PDF/UA-2),
bibliographie Zotero/BibLaTeX, prise de notes (howm, org-noter) et
développement léger via Eglot et tree-sitter. Elle tourne principalement sous
**WSL (Ubuntu)**.

> [!NOTE]
> Il s'agit d'une configuration personnelle publiée à titre de référence.
> Les contributions extérieures ne sont pas acceptées pour l'instant (voir
> [CONTRIBUTING.md](CONTRIBUTING.md)).

---

## Sommaire

- [Organisation du dépôt](#organisation-du-dépôt)
- [Séquence de démarrage](#séquence-de-démarrage)
- [Les modules](#les-modules)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Adapter à sa machine](#adapter-à-sa-machine)
- [Ce qui n'est pas versionné](#ce-qui-nest-pas-versionné)
- [Vérifications locales](#vérifications-locales)
- [Licences](#licences)

---

## Organisation du dépôt

Le dépôt **est** le répertoire `~/.emacs.d/` : la configuration référence ses
fichiers par des chemins relatifs à `user-emacs-directory`
(`lisp/…`, `latex/…`, `perf/…`). L'arborescence ne doit donc pas être
réorganisée sans adapter ces chemins.

```text
.emacs.d/
├── early-init.el          Pré-initialisation : GC, UI, native-comp, télémétrie
├── init.el                Configuration principale (Elpaca + use-package)
├── lisp/                  Modules maison, chargés par init.el
│   ├── my-paths.el          Source unique des chemins (wiki, bibliographie…)
│   ├── my-performance.el    Réglages de rendu, processus, compilation
│   ├── my-editing.el        Édition, sauvegardes, orthographe (hunspell)
│   ├── my-windows.el        Fenêtres, défilement, souris
│   ├── my-appearance.el     Police, curseur, numéros de ligne, titres Org
│   ├── my-folding.el        Repliement façon Org dans tous les modes
│   ├── my-formatting.el     Nettoyage / formatage à la sauvegarde manuelle
│   ├── my-export-config.el  Configuration partagée de l'export Org → PDF
│   ├── my-export-async.el   Init du processus d'export asynchrone
│   ├── my-export-ui.el      Journal d'export puis PDF dans une fenêtre latérale
│   ├── my-citar-noter.el    Pont citar ↔ org-noter
│   └── my-deps.el           Vérificateur asynchrone des dépendances système
├── latex/                 Configuration LaTeX utilisée par l'export Org
│   ├── preamble-article.tex     Préambule LuaLaTeX PDF/UA-2 (classe « article »)
│   ├── old-preamble-article.tex Version précédente, conservée pour comparaison
│   └── latexmkrc                Réglages latexmk (LuaLaTeX, SyncTeX)
├── perf/                  Télémétrie de performance à long terme
│   ├── perf-start.el        Collecteur (chargé depuis early-init.el)
│   ├── perf-self-test.el    Test ERT de non-régression du collecteur
│   └── README.md            Description du jeu de données produit
├── scripts/check.el       Vérifications statiques (parenthèses, compilation)
├── Makefile               `make check` : REUSE + lint + test ERT
├── LICENSES/              Textes intégraux des licences (REUSE)
├── REUSE.toml             Licences des fichiers sans en-tête SPDX
├── .github/               CI (REUSE, lint Lisp), gabarits, Dependabot
├── .claude/               Consignes et réglages pour Claude Code
└── *.md, CITATION.cff     Documentation du dépôt
```

Les répertoires `snippets/` (yasnippet) et `assets/` (icônes, dont l'icône
ORCID attendue par `my-deps.el`) sont utilisés par la configuration et ont
vocation à être versionnés dès qu'ils contiennent des fichiers.

## Séquence de démarrage

1. **`early-init.el`** — charge le collecteur `perf/perf-start.el`, suspend le
   ramasse-miettes et `file-name-handler-alist`, bloque le rendu, configure la
   compilation native (cache dans `eln-cache/`), désactive `package.el` et
   supprime barres de menu/outils avant l'affichage de la première frame.
2. **`init.el`** — amorce **Elpaca** (clonage automatique au premier
   lancement), active `elpaca-use-package`, puis charge les modules de `lisp/`
   dans l'ordre : `my-paths` → `my-performance` → `my-editing` → `my-windows`
   → `my-appearance` → `my-folding` → `my-formatting` → `my-export-ui`.
3. **Paquets** — déclarés via `use-package` (différés par défaut) :
   `compile-angel` (compilation à la volée), `gcmh`, `doom-themes`,
   `mood-line`, pile de complétion (`vertico`, `orderless`, `marginalia`,
   `consult`, `embark`, `corfu`, `cape`), `magit`, `diff-hl`, Eglot et
   tree-sitter, Org et son écosystème (`org-appear`, `org-glossary`,
   `olivetti`, `citar`, `howm`, `org-noter`), AUCTeX, `cdlatex`, `pdf-tools`.
4. **`elpaca-after-init-hook`** — charge `custom.el` s'il existe et affiche la
   durée de démarrage.

Le processus d'**export asynchrone** d'Org ne lit pas `init.el` : il charge
`lisp/my-export-async.el`, qui reconstruit le `load-path` depuis
`elpaca/builds/` puis charge `my-paths` et `my-export-config`.

## Les modules

| Module | Rôle | Points d'attention |
| --- | --- | --- |
| `my-paths` | Définit tous les chemins externes (`~/wiki`, bibliographie, CSL, Zotero), ajoute Node (nvm) au `PATH` et le dossier `tree-sitter/`. | À adapter sur toute nouvelle machine. |
| `my-performance` | Rendu, bidi, lecture des processus, avertissements de compilation. | — |
| `my-editing` | UTF-8, kill-ring, sauvegardes numérotées dans `backups/`, auto-save dans `auto-save/`, hunspell fr/en. | Dictionnaire personnel attendu dans `ispell-personal`. |
| `my-windows` | Séparateurs, défilement conservatif, défilement pixel. | Conseils (`advice`) sur `mwheel-scroll`. |
| `my-appearance` | Police JetBrains Mono Nerd, numéros de ligne, `hl-line`, puces et tailles de titres Org. | — |
| `my-folding` | `TAB` / `S-TAB` à la Org dans les modes de programmation, LaTeX et Markdown. | Org lui-même est exclu. |
| `my-formatting` | Supprime les blancs finaux et formate via Eglot **uniquement** lors d'un `C-x C-s`. | Ignore les sauvegardes automatiques. |
| `my-export-*` | Pipeline Org → LuaLaTeX → PDF (latexmk, `engrave-faces`, BibLaTeX) et affichage du PDF. | Utilise `latex/preamble-article.tex`. |
| `my-citar-noter` | Ouvre le PDF d'une référence et lance org-noter. | — |
| `my-deps` | Vérifie les exécutables et fichiers requis, avec cache BLAKE3. | Désactivé dans `init.el` (lignes commentées). |

## Prérequis

- **Emacs 31.1** compilé avec tree-sitter et la compilation native
  (la configuration utilise des fonctionnalités d'Emacs 31 :
  `markdown-ts-mode`, `treesit-auto-install-grammar`, `user-lisp-auto-scrape`).
- **Git** (Elpaca, Magit).
- **hunspell** avec `hunspell-fr` et `hunspell-en-us`.
- **Chaîne LaTeX** : `lualatex`, `latexmk`, `biber` (TeX Live complet
  recommandé) ; outils de compilation d'AUCTeX (`autoconf`, `make`).
- **Recherche** : `ripgrep` (`rg`), `fd` (`fdfind` sous Debian/Ubuntu).
- **Facultatifs** : `b3sum`, `emacs-lsp-booster`, serveurs de langage
  (`bash-language-server`, `yaml-language-server`,
  `typescript-language-server`, `perlnavigator`, `lean`), `drawio`.
- **Police** : *JetBrainsMonoNL Nerd Font Propo*.

`M-x my/deps-check` (après `(require 'my-deps)`) liste ce qui manque avec la
commande d'installation correspondante.

## Installation

### Nouvelle machine

```sh
# Sauvegarder une éventuelle configuration existante
[ -d ~/.emacs.d ] && mv ~/.emacs.d ~/.emacs.d.bak

git clone https://github.com/AntheaLiles/.emacs.d.git ~/.emacs.d
emacs   # le premier lancement installe Elpaca puis tous les paquets
```

Le premier démarrage est long (clonage et compilation des paquets, dont
AUCTeX et pdf-tools). Relancer Emacs une fois l'installation terminée.

### Rattacher un `~/.emacs.d` existant

Si le répertoire contient déjà des paquets et des états locaux à conserver :

```sh
cd ~/.emacs.d
git init -b main
git remote add origin https://github.com/AntheaLiles/.emacs.d.git
git fetch origin
git checkout -f -t origin/main   # remplace les fichiers suivis, garde le reste
```

Le `.gitignore` garantit que les caches, historiques et paquets restent hors
du suivi.

## Adapter à sa machine

Tous les chemins externes sont centralisés dans **`lisp/my-paths.el`** :

| Variable | Valeur par défaut |
| --- | --- |
| `my/wiki-path` | `~/wiki` |
| `my/resources-path` | `~/wiki/00.resources` |
| `my/bibliography-files` | `…/00.resources/references.bib` |
| `my/zotero-storage` | `/mnt/c/Users/CPIERRE/Documents/My Library/storage` (WSL) |
| `my/glossary-file` | `…/00.resources/glossary.org` |
| `my/notes-path` | `…/00.resources/notes` |
| `my/zotero-styles-dir` | `…/00.resources/csl` |
| `my/csl-locales-dir` | `…/00.resources/csl-locales` |

Les réglages faits via `M-x customize` sont écrits dans `custom.el`, qui n'est
pas versionné.

## Ce qui n'est pas versionné

Le [`.gitignore`](.gitignore) exclut tout ce qui est régénéré ou propre à une
machine :

- paquets et compilations : `elpaca/`, `elpa/`, `eln-cache/`, `*.elc`, `*.eln` ;
- grammaires compilées : `tree-sitter/` ;
- états de session : `history`, `places`, `recentf`, `projects`, `tramp`,
  `.lsp-session-v1`, `.mc-lists.el`, `transient/`, `eshell/`, `auto-save-list/` ;
- sauvegardes : `backups/`, `auto-save/` ;
- caches : `.cache/`, `deps-cache/` ;
- télémétrie : `perf/*.tsv`, `perf/cpu/` ;
- produits LaTeX : `.auctex-auto/`, `*.aux`, `*.log`, `*.pdf`… ;
- réglages Custom : `custom.el`.

## Vérifications locales

```sh
make check    # = make reuse lint test
```

| Cible | Commande | Rôle |
| --- | --- | --- |
| `reuse` | `reuse lint` | Conformité REUSE de chaque fichier. |
| `lint` | `emacs -Q --batch -l scripts/check.el` | Parenthèses de tous les `.el`, compilation à octets des modules (dans un dossier temporaire). |
| `test` | ERT sur `perf/perf-self-test.el` | Non-régression du collecteur de télémétrie. |

La CI GitHub exécute les mêmes vérifications à chaque push (Emacs 31.1 et
snapshot).

## Licences

Le dépôt suit la spécification [REUSE](https://reuse.software/) : chaque
fichier déclare son titulaire et sa licence.

| Contenu | Licence |
| --- | --- |
| Code Emacs Lisp (`*.el`) | [LGPL-3.0-or-later](LICENSES/LGPL-3.0-or-later.txt) |
| Documentation (`*.md`) | [GFDL-1.3-or-later](LICENSES/GFDL-1.3-or-later.txt) |
| Configuration LaTeX (`latex/`) | [CC-BY-SA-4.0](LICENSES/CC-BY-SA-4.0.txt) |
| Métadonnées et outillage du dépôt | [CC0-1.0](LICENSES/CC0-1.0.txt) |

Le détail et le fonctionnement de REUSE sont expliqués dans
[LICENSE.md](LICENSE.md). Pour citer ce travail, voir
[CITATION.cff](CITATION.cff).

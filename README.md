# .emacs.d — configuration Emacs pour la recherche scientifique

[![CI](https://github.com/AntheaLiles/.emacs.d/actions/workflows/lint.yml/badge.svg)](https://github.com/AntheaLiles/.emacs.d/actions/workflows/lint.yml)
[![REUSE status](https://api.reuse.software/badge/github.com/AntheaLiles/.emacs.d)](https://api.reuse.software/info/github.com/AntheaLiles/.emacs.d)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/AntheaLiles/.emacs.d/badge)](https://scorecard.dev/viewer/?uri=github.com/AntheaLiles/.emacs.d)
[![DOI](https://img.shields.io/badge/DOI-%C3%A0%20venir-lightgrey)](https://zenodo.org)
[![SWH origin](https://img.shields.io/badge/SWH%20origin-%C3%A0%20archiver-lightgrey)](https://archive.softwareheritage.org/save/)
[![SWH directory](https://img.shields.io/badge/SWH%20directory-%C3%A0%20archiver-lightgrey)](https://archive.softwareheritage.org/save/)
[![fair-software.eu](https://img.shields.io/badge/fair--software.eu-%E2%97%8F%20%20%E2%97%8F%20%20%E2%97%8F%20%20%E2%97%8F%20%20%E2%97%8B-yellow)](https://fair-software.eu)

<!-- Badges DOI et SWH vides : aucun dépôt Zenodo ni archive Software Heritage pour l'instant.
Une fois la release publiée et le dépôt archivé, les remplacer par (NNNNNNN : numéro Zenodo ;
HASH, VISIT et REL : valeurs du SWHID qualifié affiché par Software Heritage) :
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.NNNNNNN.svg)](https://doi.org/10.5281/zenodo.NNNNNNN)
[![SWH origin](https://archive.softwareheritage.org/badge/origin/https://github.com/AntheaLiles/.emacs.d/)](https://archive.softwareheritage.org/browse/origin/?origin_url=https://github.com/AntheaLiles/.emacs.d)
[![SWH directory](https://archive.softwareheritage.org/badge/swh:1:dir:HASH/)](https://archive.softwareheritage.org/swh:1:dir:HASH;origin=https://github.com/AntheaLiles/.emacs.d;visit=swh:1:snp:VISIT;anchor=swh:1:rel:REL)
-->

Configuration personnelle d'**Emacs 31.1** (vanilla, sans framework), pensée
pour la rédaction scientifique : Org-mode, LaTeX (LuaLaTeX, PDF/UA-2),
bibliographie Zotero en CSL-JSON (styles CSL), prise de notes (howm, org-noter) et
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
- [Export PDF/UA](#export-pdfua)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Adapter à sa machine](#adapter-à-sa-machine)
- [Télémétrie](#télémétrie)
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
│   ├── my-babel.el          Langages Babel (session et export asynchrone)
│   ├── my-export-config.el  Backend d'export « pdfua » (Org → PDF/UA, CSL)
│   ├── my-export-async.el   Init du processus d'export asynchrone
│   ├── my-export-ui.el      Journal d'export puis PDF dans une fenêtre latérale
│   ├── my-citar-noter.el    Pont citar ↔ org-noter
│   └── my-deps.el           Vérificateur des dépendances système (M-x my/deps-check)
├── latex/                 Configuration LaTeX utilisée par l'export Org
│   ├── preamble-common.tex      Préambule LuaLaTeX PDF/UA-2 commun
│   ├── preamble-article-ua.tex  Classe « article-ua » (recto seul)
│   ├── preamble-book-ua.tex     Classe « book-ua » (recto verso, sections sur page impaire)
│   ├── modules/                 Modules optionnels (#+LATEX_MODULES:) : tikz, styles-figures
│   ├── old-preamble-article.tex Version précédente, conservée pour comparaison
│   └── latexmkrc                Réglages latexmk (LuaLaTeX, SyncTeX, run.xml)
├── csl/                   Style CSL personnel et locale française
├── perf/                  Télémétrie de performance à long terme
│   ├── perf-start.el        Collecteur (chargé depuis early-init.el)
│   ├── perf-self-test.el    Test ERT de non-régression du collecteur
│   └── README.md            Description du jeu de données produit
├── scripts/check.el       Vérifications statiques (parenthèses, compilation)
├── scripts/bench-latex.sh Mesure du temps de compilation LaTeX (variantes)
├── docs/                  Audit et documentation complémentaire
├── tests/                 Tests ERT (export, modules) et banc de non-régression
├── Makefile               `make check` : REUSE + lint + tests ERT ; `make regress`
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

1. **`early-init.el`** — charge le collecteur `perf/perf-start.el` **s'il est
   activé** (voir [Télémétrie](#télémétrie)), suspend le ramasse-miettes et
   `file-name-handler-alist`, déclare `lisp/` comme `user-lisp-directory`
   (Emacs 31 : `load-path` et autoloads des modules), configure
   la compilation native, désactive `package.el` et supprime barres de
   menu/outils avant l'affichage de la première frame.
2. **`init.el`** — amorce **Elpaca** (clonage automatique au premier
   lancement), active `elpaca-use-package`, puis charge les modules de `lisp/`
   dans l'ordre : `my-paths` → `my-performance` → `my-editing` → `my-windows`
   → `my-appearance` → `my-folding` → `my-formatting` → `my-export-ui`.
3. **Paquets** — déclarés via `use-package` (différés par défaut) :
   thème `modus-vivendi` (intégré, `<f5>` bascule clair/sombre), mode line
   native, pile de complétion (`vertico`, `orderless`, `marginalia`,
   `consult`, `embark`, `corfu`, `cape`), `magit`, `diff-hl`, Eglot et
   tree-sitter, Org et son écosystème (`org-appear`, `org-glossary`,
   `olivetti`, `citar`, `howm`, `org-noter`), AUCTeX, `cdlatex`, `pdf-tools`,
   `lean4-mode` (via Eglot et `lake serve`).
4. **`elpaca-after-init-hook`** — charge `custom.el` s'il existe, affiche la
   durée de démarrage, puis, à la première inactivité, recompile les modules
   de `lisp/` modifiés (`prepare-user-lisp`). Cette compilation n'a jamais
   lieu avant `init.el` : elle chargerait Org avant qu'Elpaca n'active les
   paquets. `lisp/my-export-async.el`, script d'un autre processus, n'est
   jamais compilé.

Le processus d'**export asynchrone** d'Org ne lit pas `init.el` : il charge
`lisp/my-export-async.el`, qui reconstruit le `load-path` depuis
`elpaca/builds/` puis charge `my-paths`, `my-babel` et `my-export-config`.

## Les modules

| Module | Rôle | Points d'attention |
| --- | --- | --- |
| `my-paths` | Définit tous les chemins externes (`~/wiki`, bibliographie, CSL, Zotero), ajoute Node (nvm) au `PATH` et le dossier `tree-sitter/`. | À adapter sur toute nouvelle machine. |
| `my-performance` | Rendu, bidi, lecture des processus, avertissements de compilation. | — |
| `my-editing` | UTF-8, kill-ring, sauvegardes numérotées dans `backups/`, auto-save dans `auto-save/`, hunspell fr/en. | Dictionnaire personnel attendu dans `ispell-personal`. Auto-correction sur `C-M-;` (`C-.`/`C-;` restent à Embark). |
| `my-windows` | Séparateurs, défilement conservatif, défilement pixel. | — |
| `my-appearance` | Thème modus, mode line native, police JetBrains Mono Nerd, numéros de ligne, `hl-line`, titres Org. | `<f5>` : clair / sombre. |
| `my-folding` | Repliement natif d'Emacs 31 : `TAB` sur un titre, `S-TAB` global, blocs par `C-c z b` et indicateurs en frange. | `TAB` **indente** hors des titres. Org est exclu. |
| `my-formatting` | Supprime les blancs finaux et formate via Eglot **uniquement** lors d'un `C-x C-s`. | Ignore les sauvegardes automatiques. |
| `my-babel` | Langages Babel (Emacs Lisp, Python, R, shell, calc, Lua), partagés avec l'export asynchrone. | — |
| `my-export-*` | Backend `pdfua` : Org → LuaLaTeX → PDF/UA (latexmk, `engrave-faces`, CSL) et affichage du PDF. | Menu `C-c C-e u`. |
| `my-citar-noter` | Ouvre le PDF d'une référence et lance org-noter. | `C-c n P`. |
| `my-deps` | Vérifie à la demande exécutables, fichiers, paquets LaTeX et polices. | `M-x my/deps-check`. |

## Export PDF/UA

C'est la **classe** du document qui active la chaîne PDF/UA : un document
en `#+LATEX_CLASS: article-ua` ou `book-ua` s'exporte de la même façon par
`C-c C-e l` ou par le menu dédié `C-c C-e u` (backend `pdfua`, qui prend
`article-ua` par défaut et offre le brouillon). Un document en `article`
standard n'est jamais modifié.

| Touche | Action |
| --- | --- |
| `C-c C-e u l` | fichier `.tex` |
| `C-c C-e u p` | PDF |
| `C-c C-e u o` | PDF, puis ouverture |
| `C-c C-e u d` | PDF **brouillon** : sans balisage PDF/UA, plus rapide |

Deux classes, choisies par `#+LATEX_CLASS:` :

| Classe | Mise en page |
| --- | --- |
| `article-ua` (défaut) | recto seul, sections enchaînées |
| `book-ua` | recto verso, chaque section commence sur une page impaire |

La première page est une page de titre symétrique, sans zone de notes :
titre, auteurs, résumé et mots-clés (tout ce qui précède la première
section). Le corps commence page suivante (`article-ua`) ou page impaire
suivante (`book-ua`).

Chaque page porte « *page* / *total* », première page comprise.

Balisages propres à cette configuration, conservés : remarques en marge
`[rmq:…]`, éléments de flottant `#+DESC:`, `#+NOTE:`, `#+SOURCE:`,
conversion automatique des `.drawio` en PDF, titres `:ignore:`,
`\orcidlink{…}` et, pour un identifiant ORCID non authentifié,
`\orcidlinkunauth{…}` (icônes de `assets/`, marque d'ORCID, Inc. ; si une
icône manque, le lien s'affiche en texte).

### Modules LaTeX

Des compléments de préambule optionnels se déclarent par document :

```org
#+LATEX_MODULES: styles-figures
```

| Module | Contenu |
| --- | --- |
| `tikz` | TikZ et pgfplots, palettes accessibles, trames, environnement `qvfigure` (texte alternatif) |
| `styles-figures` | styles de figures en niveaux de gris (`fg …`) ; charge `tikz` |

Un module est un fichier `latex/modules/NOM.tex`, chargé après le préambule
de la classe ; ses dépendances se déclarent dans son en-tête par une ligne
`% requires: …`. Ajouter un module revient à déposer un fichier.

### Bibliographie

Les citations passent par **CSL** (`oc-csl`, paquet `citeproc`) avec le style
personnel `csl/iso-ieee-localised-collapsed.csl` : pas de biber, deux passes
LuaLaTeX. Chaque section de premier niveau reçoit sa propre bibliographie
(`#+PRINT_BIBLIOGRAPHY:` dans la section) ; un seul `#+PRINT_BIBLIOGRAPHY:`
dans le document donne une bibliographie unique de toutes les références
citées. Elle est composée en `\scriptsize` et titrée comme le faisait
biblatex :

| Mot-clé | Titre |
| --- | --- |
| `#+PRINT_BIBLIOGRAPHY:` | « Références » en `\section*` |
| `… :heading subbibliography` | « Références » en `\subsection*` |
| `… :heading bibintoc` / `subbibintoc` | idem, ajouté à la table des matières |
| `… :heading bibnumbered` / `subbibnumbered` | titre numéroté |
| `… :heading none` | aucun titre |
| `… :title "Sources"` | remplace « Références » |

Les espaces insécables (avant « [ », « : », dans les guillemets) et le
trait d'union insécable des pages sont posés par le style CSL lui-même :
rien à écrire. Le préambule les compose quelle que soit la police.

- **Org** lit `~/wiki/00.resources/references.json`, exporté par Zotero au
  format *Better CSL JSON* (Better BibTeX, « Garder à jour »).
- **AUCTeX / RefTeX** gardent `references.bib`, synchronisé de la même façon.

Sans `citeproc`, l'export reste possible avec le processeur `basic`.

## Code en ligne à l'export PDF

| Écrit dans Org | Rendu PDF |
| --- | --- |
| `~code~` | monospace sur fond grisé |
| `src_emacs-lisp{(setq x 1)}`, `src_python{x = 1}`… | monospace sur fond grisé, **coloré** selon le langage (engrave-faces) |
| `=verbatim=` | monospace simple, sans fond |
| `src_python[:exports results]{1 + 1}` | le **résultat** de l'évaluation (`2`) |

Le fond grisé vient de la macro `\CodeInline` du préambule (paquet `lua-ul`,
LuaLaTeX) : le code reste sécable en fin de ligne. Sa couleur se règle via
`fondcodeenligne` dans `latex/preamble-common.tex`. `lua-ul` n'est chargé que
si le document contient du code en ligne.

> [!IMPORTANT]
> Par défaut, Org **exécute** les blocs `src_…` à l'export et n'en imprime que
> le résultat. Cette configuration exporte le **code** à la place (et
> n'exécute rien) ; il faut demander `:exports results` explicitement.

## Prérequis

- **Emacs 31.1** compilé avec tree-sitter et la compilation native
  (la configuration utilise des fonctionnalités d'Emacs 31 :
  `markdown-ts-mode`, `treesit-auto-install-grammar`, `user-lisp-auto-scrape`).
- **Git** (Elpaca, Magit).
- **hunspell** avec `hunspell-fr` et `hunspell-en-us`.
- **Chaîne LaTeX** : `lualatex`, `latexmk` (TeX Live complet recommandé) ;
  outils de compilation d'AUCTeX (`autoconf`, `make`). biber n'est plus
  nécessaire.
- **Recherche** : `ripgrep` (`rg`), `fd` (`fdfind` sous Debian/Ubuntu).
- **Facultatifs** : `emacs-lsp-booster`, serveurs de langage
  (`bash-language-server`, `yaml-language-server`,
  `typescript-language-server`, `perlnavigator`), Lean 4 (`elan`, `lake`),
  `drawio`.
- **Police** : *JetBrainsMonoNL Nerd Font Propo*.

`M-x my/deps-check` liste ce qui manque avec la commande d'installation
correspondante.

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
| `my/bibliography-files` | `…/00.resources/references.json` (CSL-JSON, Org) |
| `my/bibtex-files` | `…/00.resources/references.bib` (AUCTeX, RefTeX) |
| `my/zotero-storage` | `/mnt/c/Users/CPIERRE/Documents/My Library/storage` (WSL) |
| `my/glossary-file` | `…/00.resources/glossary.org` |
| `my/notes-path` | `…/00.resources/notes` |
| `my/zotero-styles-dir` | `…/00.resources/csl` |
| `my/csl-locales-dir` | `…/00.resources/csl-locales` |

Les réglages faits via `M-x customize` sont écrits dans `custom.el`, qui n'est
pas versionné.

## Télémétrie

Le collecteur `perf/perf-start.el` n'est chargé que sur demande :

```sh
touch ~/.emacs.d/perf/enabled     # ou EMACS_PERF=1 emacs
```

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
| `test` | ERT sur `perf/perf-self-test.el` et `tests/` | Collecteur de télémétrie, export Org, modules (repliement, dépendances, init). |
| `regress` | `tests/regression/run.sh` | Export réel d'un document d'essai en `article-ua`, `book-ua` et brouillon, compilé par LuaLaTeX. Hors de `make check` : requiert TeX Live. |

La CI GitHub exécute les mêmes vérifications à chaque push (Emacs 31.1 et
snapshot), ainsi que le banc de non-régression (Emacs 31.1).

## Audit

[`docs/audit-2026-09.md`](docs/audit-2026-09.md) : état de l'architecture,
inventaire des alternatives natives d'Emacs 30/31, défauts restants, et
mesures de performance LaTeX (dont l'évaluation de Lua et de LuaJIT), avec
une feuille de route.

## Licences

Le dépôt suit la spécification [REUSE](https://reuse.software/) : chaque
fichier déclare son titulaire et sa licence.

| Contenu | Licence |
| --- | --- |
| Code Emacs Lisp (`*.el`) | [LGPL-3.0-or-later](LICENSES/LGPL-3.0-or-later.txt) |
| Documentation (`*.md`) | [GFDL-1.3-or-later](LICENSES/GFDL-1.3-or-later.txt) |
| Configuration LaTeX (`latex/`), style CSL | [CC-BY-SA-4.0](LICENSES/CC-BY-SA-4.0.txt) |
| Locale CSL française (`csl/locales/`) | [CC-BY-SA-3.0](LICENSES/CC-BY-SA-3.0.txt) |
| Métadonnées et outillage du dépôt | [CC0-1.0](LICENSES/CC0-1.0.txt) |

Le détail et le fonctionnement de REUSE sont expliqués dans
[LICENSE.md](LICENSE.md). Pour citer ce travail, voir
[CITATION.cff](CITATION.cff).

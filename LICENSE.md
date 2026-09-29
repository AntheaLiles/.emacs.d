# Licences

Ce dépôt n'a pas une licence unique : chaque catégorie de fichiers est placée
sous la licence la mieux adaptée à sa nature. La correspondance
fichier → licence est déclarée de façon lisible par machine selon la
spécification **REUSE 3.3** de la Free Software Foundation Europe.

## Politique de licences

| Catégorie | Fichiers | Licence (identifiant SPDX) | Pourquoi |
| --- | --- | --- | --- |
| **Code source Emacs Lisp** | `early-init.el`, `init.el`, `lisp/*.el`, `perf/*.el`, `snippets/**` | GNU Lesser General Public License v3.0 ou ultérieure (`LGPL-3.0-or-later`) | Copyleft faible : toute modification des fichiers eux-mêmes reste libre, mais ils peuvent être chargés depuis une configuration sous une autre licence. |
| **Documentation** | `*.md`, `perf/README.md`, `docs/**` | GNU Free Documentation License v1.3 ou ultérieure (`GFDL-1.3-or-later`) | Licence conçue pour les manuels, cohérente avec la documentation du projet GNU Emacs. |
| **Configuration LaTeX** | `latex/*.tex`, `latex/latexmkrc` | Creative Commons Attribution – Partage dans les mêmes conditions 4.0 International (`CC-BY-SA-4.0`) | Les préambules relèvent de la mise en page et de la typographie plus que du logiciel ; CC BY-SA impose l'attribution et le partage à l'identique. |
| **Style CSL** | `csl/iso-ieee-localised-collapsed.csl` | `CC-BY-SA-4.0` | Adaptation du style IEEE du dépôt CSL de Zotero (CC BY-SA 3.0), redistribuée sous la version 4.0 comme le permet l'article 4(b) de la licence d'origine. Auteurs du style d'origine crédités dans `REUSE.toml` et dans le fichier. |
| **Locale CSL** | `csl/locales/**` | `CC-BY-SA-3.0` | Fichier du projet CSL, inchangé, sous sa licence d'origine. |
| **Métadonnées et outillage** | `.gitignore`, `.gitattributes`, `.editorconfig`, `REUSE.toml`, `CITATION.cff`, `.github/**`, `.claude/settings.json`, `tests/regression/` (hors `.el`) | Creative Commons Zero 1.0 (`CC0-1.0`) | Fichiers sans originalité notable : les verser au domaine public permet de les réutiliser sans formalité. |

Pour la GFDL, aucune section invariante, aucun texte de première ni de
quatrième de couverture n'est défini.

La LGPL-3.0 se présente comme un ensemble de permissions supplémentaires
ajoutées à la GNU GPL v3 ; le texte de la GPL auquel elle renvoie est
disponible sur <https://www.gnu.org/licenses/gpl-3.0.html>.

Les textes intégraux des licences se trouvent dans [`LICENSES/`](LICENSES/).

## Fonctionnement de REUSE

[REUSE](https://reuse.software/) répond à une question simple — *« sous quelle
licence est ce fichier, et à qui appartient-il ? »* — pour **chaque** fichier du
dépôt, sans ambiguïté et de façon vérifiable automatiquement. Trois règles :

1. **Choisir et fournir les licences.** Chaque licence utilisée est copiée
   intégralement dans `LICENSES/<identifiant-SPDX>.txt`.
2. **Déclarer chaque fichier.** Chaque fichier indique son titulaire
   (`SPDX-FileCopyrightText`) et sa licence (`SPDX-License-Identifier`), soit
   directement, soit via un fichier de métadonnées.
3. **Vérifier.** L'outil `reuse lint` contrôle que rien ne manque.

### Deux façons de déclarer une licence dans ce dépôt

**En-tête dans le fichier** — utilisé pour le code Lisp et LaTeX, afin que la
licence accompagne le fichier s'il est copié ailleurs :

```elisp
;;; my-module.el --- Description -*- lexical-binding: t; -*-
;;
;; SPDX-FileCopyrightText: 2026 AntheaLiles
;; SPDX-License-Identifier: LGPL-3.0-or-later
```

```latex
% SPDX-FileCopyrightText: 2026 AntheaLiles
% SPDX-License-Identifier: CC-BY-SA-4.0
```

**Fichier [`REUSE.toml`](REUSE.toml)** — utilisé pour la documentation et les
métadonnées, où un en-tête serait encombrant ou impossible. Il associe des
motifs de chemins à une licence :

```toml
[[annotations]]
path = ["README.md", "docs/**"]
precedence = "override"
SPDX-FileCopyrightText = "2026 AntheaLiles"
SPDX-License-Identifier = "GFDL-1.3-or-later"
```

La clé `precedence` règle les conflits : `override` fait primer `REUSE.toml`
sur l'en-tête éventuel du fichier ; `aggregate` cumule les deux ;
`closest` (défaut) donne la priorité à l'en-tête.

### Ajouter un fichier

| Nouveau fichier | Action |
| --- | --- |
| Module Lisp `lisp/my-x.el` | Copier l'en-tête SPDX d'un module existant sous la première ligne. |
| Fichier LaTeX dans `latex/` | Ajouter les deux lignes `% SPDX-…` en tête. |
| Documentation Markdown | L'ajouter à la liste GFDL de `REUSE.toml` (ou dans `docs/`, déjà couvert). |
| Image dans `assets/` | Ajouter une entrée dans `REUSE.toml` avec son **titulaire réel** et sa licence (un logo tiers, comme l'icône ORCID iD, n'appartient pas à l'auteur du dépôt). |
| Snippet yasnippet | Rien : `snippets/**` est couvert par `REUSE.toml`. |

L'outil peut aussi écrire l'en-tête lui-même :

```sh
reuse annotate --copyright "AntheaLiles" --year 2026 \
               --license LGPL-3.0-or-later lisp/my-x.el
```

### Vérifier la conformité

```sh
pipx install reuse     # ou : pip install --user reuse
reuse lint             # doit se terminer par « Congratulations! »
reuse spdx > sbom.spdx # nomenclature SPDX complète (facultatif)
```

La même vérification tourne en CI à chaque push et pull request
([`.github/workflows/reuse.yml`](.github/workflows/reuse.yml)).

## Dépendances tierces

Les paquets installés par Elpaca (`elpaca/`) ne font pas partie de ce dépôt :
ils sont téléchargés depuis leurs dépôts d'origine et restent sous leurs
propres licences.

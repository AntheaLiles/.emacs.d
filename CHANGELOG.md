# Journal des modifications

Toutes les modifications notables de ce dépôt sont consignées ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
projet adopte le [versionnage sémantique](https://semver.org/lang/fr/),
interprété pour une configuration : **majeur** = rupture (chemin, raccourci ou
comportement par défaut retiré), **mineur** = nouvelle fonctionnalité ou
paquet, **correctif** = correction sans changement de comportement attendu.

## [Non publié]

## [0.1.0] — 2026-09-29

### Ajouté

- Import initial de la configuration existante :
  `early-init.el`, `init.el`, les modules `lisp/my-*.el`, le collecteur de
  télémétrie `perf/perf-start.el` et son test `perf/perf-self-test.el`, les
  préambules LaTeX et `latex/latexmkrc`.
- Conformité **REUSE 3.3** : en-têtes SPDX dans les fichiers Lisp et LaTeX,
  `REUSE.toml` pour la documentation et les métadonnées, textes des licences
  dans `LICENSES/` (LGPL-3.0-or-later, GFDL-1.3-or-later, CC-BY-SA-4.0,
  CC0-1.0).
- Documentation : `README.md`, `LICENSE.md`, `CONTRIBUTING.md`,
  `SECURITY.md`, `CITATION.cff`, ce journal.
- `.gitignore` excluant paquets, caches, historiques, compilations,
  télémétrie et produits LaTeX ; `.gitattributes` (LF, pilotes de diff) ;
  `.editorconfig`.
- `scripts/check.el` (parenthèses et compilation à octets sans écrire dans le
  dépôt) et `Makefile` (`make check`).
- CI GitHub Actions : vérification REUSE, lint Emacs Lisp et test ERT du
  collecteur (Emacs 30.2 et snapshot) ; Dependabot pour les actions ;
  gabarits de tickets et de pull request.
- Consignes (`.claude/CLAUDE.md`), réglages, hook de démarrage de session et
  commande `/check` pour Claude Code.

### Modifié

- `perf/perf-README.md` renommé en `perf/README.md` (affichage automatique sur
  GitHub).
- `latex/latexmkrc` : ajout du saut de ligne final manquant.

[Non publié]: https://github.com/AntheaLiles/.emacs.d/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/AntheaLiles/.emacs.d/releases/tag/v0.1.0

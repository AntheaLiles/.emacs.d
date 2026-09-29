# Journal des modifications

Toutes les modifications notables de ce dépôt sont consignées ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
projet adopte le [versionnage sémantique](https://semver.org/lang/fr/),
interprété pour une configuration : **majeur** = rupture (chemin, raccourci ou
comportement par défaut retiré), **mineur** = nouvelle fonctionnalité ou
paquet, **correctif** = correction sans changement de comportement attendu.

## [Non publié]

### Corrigé

- **Télémétrie** (`perf/perf-start.el`) : une parenthèse mal placée imbriquait
  `my/perf--post-gc`, `my/perf--snapshot-allocation` et
  `my/perf--snapshot-system` dans `my/perf--post-command`.
  `post-gc-hook` signalait `void-function` jusqu'à la première commande, les
  trois fonctions étaient redéfinies à chaque commande, et la remise à zéro de
  l'état par commande, devenue un faux gestionnaire d'erreur, ne s'exécutait
  jamais.
- **Ramasse-miettes** (`early-init.el`) : `gc-cons-percentage` restait à 0.6
  toute la session (gcmh ne gère que le seuil) ; il revient à 0.1 après le
  démarrage, et le seuil retombe à 16 Mo si gcmh n'est pas actif.
- **citar ↔ org-noter** : `init.el` enregistrait une source de notes sans les
  clés `:items`/`:hasitems` exigées par citar, avec une fonction inexistante
  (`my/citar-open-noter`), ce qui provoquait une erreur au chargement
  d'org-noter. La source est retirée (citar garde sa source de notes par
  défaut) et `my/citar-open-pdf-with-noter`, qui traitait le résultat de
  `citar-get-files` comme une liste alors que c'est une table de hachage, est
  réécrite et liée à `C-c n P`.
- **Citations CSL** : `org-cite-export-processors` désignait un style littéral
  `"expand-file-name.csl"` ; le style par défaut est rétabli.
- **Titres `:ignore:`** : le filtre, défini deux fois, supprimait des lignes
  en avançant dans `init.el` (titres consécutifs sautés). Une seule définition,
  correcte, vit désormais dans `lisp/my-export-config.el`, partagée par les
  exports synchrone et asynchrone.
- **Export asynchrone** : le repli sur le rendu `verbatim` quand
  engrave-faces est absent était aussitôt écrasé par `my-export-config` ; le
  choix se fait maintenant dans la configuration partagée.
- **Hooks d'export obsolètes** : `org-export-before-processing-hook` et
  `org-export-before-parsing-hook` remplacés par leurs équivalents
  `-functions` (Org 9.6).
- **Chemins en dur** : `my-export-config.el` n'écrit plus `~/.emacs.d` ; le
  préambule et `latexmkrc` sont dérivés de `user-emacs-directory`.
- **Conversion drawio** : les positions du lien sont relevées avant l'appel
  au processus externe, et les liens `[[file:….drawio]]` sont reconnus.
- **Repliement** (`my-folding.el`) : `hs-looking-at-block-start-p`, supprimée
  dans Emacs 31, rendait `TAB` inopérant sur les blocs de code ; remplacée par
  `hs-get-first-block-on-line`.
- **Raccourcis** : flyspell masquait `C-.` (`embark-act`) et `C-;`
  (`embark-dwim`) dans tous les buffers ; l'auto-correction passe sur `C-M-;`.
- **Hooks de modes** : `latex-mode-hook` et `markdown-mode-hook` remplacés par
  `LaTeX-mode-hook` et `markdown-ts-mode-hook` (numéros de ligne absolus) ;
  flyspell n'est plus activé trois fois dans les buffers texte.
- **nvm** : la version de Node la plus récente est choisie par numéro de
  version et non par ordre alphabétique (v9 passait après v18).
- **Vérificateur de dépendances** (`my-deps.el`) : n'échoue plus sans
  `kpsewhich` ni `fc-list`, cesse de signaler comme manquants tous les
  serveurs LSP par défaut d'Eglot, utilise `my/bibliography-files` et le même
  nom de police que `my-appearance.el`.
- **Export UI** : plus d'erreur dans un buffer sans fichier ; un export
  relancé ne laisse plus tourner l'ancien minuteur.
- Obsolescences d'Emacs 31 : `when-let` → `when-let*`, `idle-update-delay`
  → `which-func-update-delay`.
- `perf/perf-self-test.el` : le `let` sur `my/perf-root` était lexical et
  sans effet ; ajout de deux tests de non-régression pour le bug de
  télémétrie.

### Modifié

- `magit` n'est plus chargé au démarrage (`:demand t` retiré).
- Les réglages et hooks outline/hideshow d'`init.el`, qui doublaient ceux de
  `lisp/my-folding.el`, sont retirés : ce module en est la seule source.

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
  collecteur (Emacs 31.1 et snapshot) ; Dependabot pour les actions ;
  gabarits de tickets et de pull request.
- Consignes (`.claude/CLAUDE.md`), réglages, hook de démarrage de session et
  commande `/check` pour Claude Code.

### Modifié

- `perf/perf-README.md` renommé en `perf/README.md` (affichage automatique sur
  GitHub).
- `latex/latexmkrc` : ajout du saut de ligne final manquant.

[Non publié]: https://github.com/AntheaLiles/.emacs.d/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/AntheaLiles/.emacs.d/releases/tag/v0.1.0

# Journal des modifications

Toutes les modifications notables de ce dépôt sont consignées ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
projet adopte le [versionnage sémantique](https://semver.org/lang/fr/),
interprété pour une configuration : **majeur** = rupture (chemin, raccourci ou
comportement par défaut retiré), **mineur** = nouvelle fonctionnalité ou
paquet, **correctif** = correction sans changement de comportement attendu.

## [Non publié]

### Ajouté

- **Export Typst** (`C-c C-e T`) : backend dérivé `my-typst`
  (`lisp/my-export-typst.el`, paquet `ox-typst`). Fichier `.typ`, PDF/UA-1,
  brouillon, tampon. Reprend de la chaîne LaTeX la mise en page, le style CSL
  (avec le `.bib`, Typst ne lisant pas le CSL-JSON), `#+ALT_TEXT:`,
  `\orcidlink{…}`, les blocs `abstract` et `keyword`, un bloc de titre et la
  conversion des `.drawio` (en SVG). Fonctionne aussi en export asynchrone.
  Corrige au passage trois défauts d'`ox-typst` : seul le premier auteur
  figurait dans les métadonnées, un `#+DATE:` en texte libre faisait échouer
  le gabarit, et un tampon sans fichier aussi.
- `tests/my-typst-test.el` (14 tests) et section « export Typst » du banc de
  non-régression : compilation réelle par `typst`, PDF/UA-1 vérifié sur le
  PDF, brouillon. La CI installe Typst 0.15.1 (somme SHA-256 vérifiée) et
  épingle `ox-typst` sur un commit.
- **OpenSSF Scorecard** : workflow `.github/workflows/scorecard.yml`
  (hebdomadaire, sur `main` et à chaque règle de protection de branche),
  résultats publiés pour le badge du README et envoyés à l'onglet Security.
- `tests/regression/requirements.txt` : PyMuPDF épinglé par hachage, suivi par
  Dependabot (pip).
- **Icônes ORCID** (`assets/`, marque d'ORCID, Inc., déclarée dans
  `REUSE.toml`) et `\orcidlinkunauth{…}` pour un identifiant non
  authentifié, à côté de `\orcidlink{…}`.
- **Modules LaTeX** : `#+LATEX_MODULES: tikz styles-figures` charge des
  compléments de préambule de `latex/modules/` (TikZ et pgfplots accessibles,
  styles de figures en niveaux de gris), dépendances comprises (ligne
  `% requires:` de chaque module).
- Titres de bibliographie **comme biblatex** : « Références » en `\section*`
  par défaut, en `\subsection*` avec `:heading subbibliography`, et
  `none`, `bibintoc`, `subbibintoc`, `bibnumbered`, `subbibnumbered`,
  `:title "…"`.
- Banc de non-régression : vérifications sur le PDF compilé (pagination,
  corps de la bibliographie, première page) par `tests/regression/pdfcheck.py`
  (PyMuPDF) ; export `C-c C-e l` d'un document `article-ua` et d'un document
  `article` ; `REGRESS_KEEP=1` conserve les fichiers produits.
- **Backend d'export `pdfua`** (dérivé de `latex`, menu `C-c C-e u`) : `.tex`,
  PDF, PDF ouvert et **PDF brouillon** sans balisage (`C-c C-e u d`).
  L'export LaTeX standard (`C-c C-e l`) n'est plus modifié par la
  configuration.
- **Classes `article-ua` et `book-ua`** : préambule commun
  `latex/preamble-common.tex`, plus un préambule par classe ; `book-ua`
  compose en recto verso et ouvre chaque section sur une page impaire,
  `article-ua` non.
- **Bibliographie CSL** : style personnel
  `csl/iso-ieee-localised-collapsed.csl` (CC BY-SA 4.0) et locale française
  (`csl/locales/`, CC BY-SA 3.0) ; une bibliographie par section de premier
  niveau, restreinte aux références qui y sont citées ; repli sur le
  processeur `basic` si `citeproc` manque.
- `lisp/my-babel.el` : langages Babel (Emacs Lisp, Python, R, shell, calc,
  Lua, Mermaid si installé), partagés par la session et l'export asynchrone.
- **Lean 4** : `lean4-mode` (fork Eglot, `lake serve`), blocs `lean` dans Org.
- Déplacement de lignes natif `M-<up>` / `M-<down>` (`my/move-lines-up`,
  `my/move-lines-down`), région comprise.
- Nouveautés d'Emacs 31 : `user-lisp-directory` (compilation et autoloads de
  `lisp/`), indicateurs de repliement en frange, mode line native
  (`mode-line-collapse-minor-modes`, `project-mode-line`),
  `vc-auto-revert-mode`, `diff-hl-update-async`, `dabbrev-capf`,
  `visual-wrap-prefix-mode`, `flyspell-delay-use-timer`,
  `ispell-save-corrections-as-abbrevs`, `markdown-ts-mode` par
  `major-mode-remap-alist`.
- `tests/my-config-test.el` : tests ERT des modules (déplacement de lignes,
  repliement, Babel, dépendances, garde d'Eglot, `early-init.el`).
- `tests/regression/` et `make regress` : banc de bout en bout (export réel
  en processus asynchrone, compilation LuaLaTeX en `article-ua`, `book-ua`
  et brouillon), exécuté par la CI sous Emacs 31.1.
- Tests ERT de l'export étendus : classes, backend, brouillon, CSL,
  bibliographies par section, drawio, remarques, éléments de flottant,
  titres `:ignore:`, affichage du journal et du PDF.

- **Code en ligne à l'export PDF** : `~code~` et `src_LANG{…}` sont composés
  en monospace sur fond grisé (macro `\CodeInline`, paquet `lua-ul`, sécable
  en fin de ligne), les seconds colorés selon leur langage par engrave-faces ;
  titres et signets PDF compris. `=verbatim=` est inchangé.
- `tests/my-export-config-test.el` : tests ERT de l'export du code en ligne,
  exécutés par `make test` et la CI.
- `docs/audit-2026-09.md` : audit complet (architecture, alternatives
  natives d'Emacs 30/31 et d'Org 9.8, fiabilité, performance Emacs et LaTeX,
  Lua et LuaJIT), mesures à l'appui, et feuille de route.
- `scripts/bench-latex.sh` : mesure du temps de compilation d'un document
  exporté sous plusieurs variantes (options actuelles, règle `run.xml`, sans
  balisage PDF/UA, `.bib` réduite), à lancer sur la machine réelle.

### Modifié

- Conversion `.drawio` : SVG pour Typst, PDF pour tous les autres backends
  (comportement inchangé).
- **Badges du README** au format de k7pl : CI (`?branch=main`), REUSE status
  (api.reuse.software) et OpenSSF Scorecard. Pas de badge DOI : le dépôt n'est
  pas encore archivé sur Zenodo.
- **CI** : toutes les actions épinglées par SHA (commentaire de version, suivi
  par Dependabot) et `persist-credentials: false` sur chaque `checkout`.
- `.gitignore` : les fichiers `*.eld` (données Lisp écrites par Emacs et ses
  paquets) ne sont plus suivis.
- **Rupture** — l'export PDF/UA passe par `C-c C-e u` et la classe par défaut
  s'appelle `article-ua` : `#+LATEX_CLASS: article` redevient la classe
  standard de LaTeX.
- **Rupture** — `latex/preamble-article.tex` devient
  `latex/preamble-common.tex`.
- **Rupture** — la bibliographie d'Org est `~/wiki/00.resources/references.json`
  (CSL-JSON, export *Better CSL JSON* de Zotero) ; `references.bib` reste
  utilisée par AUCTeX et RefTeX (`my/bibtex-files`). biber et biblatex ne
  sont plus employés : deux passes LuaLaTeX au lieu de quatre.
- **Rupture** — `TAB` n'agit plus sur les blocs de code : il replie les
  titres (outline natif) et **indente** partout ailleurs ; les blocs se
  replient par `C-c z b` ou la frange.
- **Rupture** — paquets retirés au profit du natif : `compile-angel`
  (`user-lisp`), `gcmh` (seuil fixe et GC à l'inactivité), `move-text`,
  `doom-themes` (`modus-themes`, `<f5>`), `mood-line` (mode line native),
  `diredfl` ; `cape-dabbrev` remplacé par `dabbrev-capf`.
- **Rupture** — la télémétrie `perf/` est désactivée par défaut : l'activer
  par `touch ~/.emacs.d/perf/enabled` ou `EMACS_PERF=1`.
- Eglot ne démarre plus dans tous les modes de programmation mais pour Lean,
  Bash, YAML, TypeScript et Perl, et jamais dans un buffer d'édition de bloc
  Org ni sans fichier.
- `latex/latexmkrc` : les lignes changeantes de `run.xml` sont ignorées dans
  le calcul d'empreinte (une passe LuaLaTeX inutile en moins).
- `lua-ul` n'est chargé que si le document contient du code en ligne.
- `org-latex-pdf-process` sans `-shell-escape` ni `-f`.
- Affichage de l'export (`my-export-ui.el`) : piloté par
  `org-export-add-to-stack`, sans minuteur.
- `my-deps.el` réécrit : synchrone, à la demande (`M-x my/deps-check`), sans
  cache BLAKE3 ni processus d'arrière-plan ; vérifie aussi les paquets LaTeX
  et les polices du préambule.
- Sauvegardes de `recentf` et `save-place` toutes les 5 min ; le
  `kill-ring` n'est plus enregistré par `savehist`.
- Renommages d'Org 9.8 : `org-src-content-indentation`,
  `org-startup-with-link-previews`.
- `my-folding.el` réécrit sur les mécanismes natifs d'Emacs 31 (variables
  `hs-*` locales, `hs-special-modes-alist` étant obsolète).
- Les blocs `src_LANG{…}` exportent désormais leur **code** au lieu d'être
  évalués (`:exports code` par défaut) : la confirmation Babel étant coupée
  pendant l'export, du code en ligne s'exécutait sans demander. Pour un
  résultat, écrire `src_LANG[:exports results]{…}`.
- `latex/preamble-common.tex` : l'icône ORCID est cherchée via `\emacsdir`,
  fourni par la classe d'export à partir de `user-emacs-directory` (repli sur
  `~/.emacs.d/`).
- `magit` n'est plus chargé au démarrage (`:demand t` retiré).
- Les réglages et hooks outline/hideshow d'`init.el`, qui doublaient ceux de
  `lisp/my-folding.el`, sont retirés : ce module en est la seule source.

### Corrigé

- **Bibliographie vide** : un `#+print_bibliography:` unique placé en fin
  d'article (après des `#+INCLUDE`, donc dans la dernière section) ne listait
  que les références de cette section, c'est-à-dire aucune. Un mot-clé
  unique donne désormais la bibliographie de tout le document ; le
  découpage par section ne vaut qu'à partir de deux.
- **Page de titre** : elle avait perdu sa géométrie symétrique (zone de
  notes visible) et l'introduction s'y imprimait. Titre, auteurs, résumé et
  mots-clés occupent une page symétrique ; le corps commence page 2
  (`article-ua`) ou page 3, impaire (`book-ua`).
- **Démarrage** : les modules de `lisp/` étaient compilés avant `init.el`,
  et la compilation exécutait leurs `require` (Org, ox-latex, et tout
  `my-export-async.el`) avant l'activation d'Elpaca : « Cannot load
  citar-org ». La compilation a lieu après l'initialisation, à la première
  inactivité ; `my-export-async.el` n'est jamais compilé ; `citar-org` attend
  `citar` en plus d'Org.
- **Avertissements de compilation** (*Compile-Log*) : variable
  `my/pdfua-classes` utilisée avant sa définition, fonction
  `org-export-output-file-name` non déclarée. `scripts/check.el` compile
  désormais chaque module dans un Emacs séparé et échoue sur tout
  avertissement : dans une session commune, ils étaient masqués.
- **Elpaca** : date des paquets intégrés fixée pour une version de
  développement d'Emacs (31.1.50), et `compat` pris dans Emacs 31 plutôt
  qu'installé depuis ELPA (« compat loaded before Elpaca activation »).
- **Sauvegarde automatique** : l'intervalle était passé de 2 à 30 s et les
  fichiers sous `/mnt/` (disques Windows de WSL) en étaient exclus ; Emacs
  redemandait de sauvegarder des fichiers Org. Le réglage d'origine est
  rétabli (2 s, tous les fichiers), avec un test.
- **Renvois « ?? » et total de pages absent** : sans `-f`, latexmk s'arrêtait
  après la première passe à la moindre erreur LaTeX (une image absente, comme
  l'icône ORCID), avant la résolution des `\ref` et de `LastPage` ; le PDF,
  produit quand même, affichait « (figure ??) ». `-f` est rétabli, et
  l'affichage de fin d'export signale désormais les erreurs du journal
  (« Export terminé AVEC n erreur(s) LaTeX »), y compris pour `C-c C-e l p`.
- **`C-c C-e l` sur un document `article-ua` ou `book-ua`** : seule la classe
  s'appliquait ; remarques en marge, éléments de flottant, bibliographies par
  section (`\scriptsize`, titre « Références ») et code en ligne ne
  passaient que par `C-c C-e u`. La chaîne PDF/UA dépend désormais de la
  classe du document, quel que soit le menu.
- **Espaces insécables du style CSL** affichées en boîte « ? » avec une police
  sans ce glyphe : U+00A0, U+202F et U+2011 sont composés par le préambule
  (espace insécable de TeX, espace fine, trait d'union insécable).
- **Pied de page** : la première page (style `plain` de `\maketitle`)
  n'affichait que son numéro, sans le total ; toutes les pages portent
  « page / total ».
- **ORCID** : l'icône porte un texte alternatif (PDF/UA), et son absence ne
  fait plus échouer la compilation (lien en texte).
- Banc de non-régression : le test du profil brouillon relisait le `.tex`
  d'un export précédent (variable `local` mal évaluée) et ne vérifiait rien.
- **Bibliographie CSL-JSON vide ou tronquée** : l'export échouait dans
  citeproc sur un `json-end-of-file` sans explication. Le fichier est
  désormais vérifié avant l'export (début « [ », fin « ] », sans le lire en
  entier), avec un message qui le nomme et indique de relancer l'export
  Better CSL JSON de Zotero.
- **Largeur des images** : `#+ATTR_LATEX: :options width=…` produisait deux
  clés `width=` dans `\includegraphics` ; seule la première est gardée.
- **Emphase finale** : une remarque `[rmq:…]` ou un élément `#+NOTE:`
  terminé par `*gras*` ou `/italique/` perdait sa mise en forme.
- **Espace avant espace insécable** : les espaces qui précèdent une espace
  insécable (style CSL) sont fusionnées.
- Obsolescences d'Emacs 31 et d'Org rétablies comme avertissements
  (`byte-compile-warnings` n'est plus restreint).
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
  au processus externe, et les liens `[[file:….drawio]]` sont reconnus et
  réécrits en `[[file:….pdf]]` (le préfixe était perdu, ce qui en faisait un
  lien interne introuvable) ; test ERT ajouté.
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
- CI : `actions/checkout` passe en v5 (Node 20 déprécié sur les runners).
- `perf/perf-self-test.el` : le `let` sur `my/perf-root` était lexical et
  sans effet ; ajout de deux tests de non-régression pour le bug de
  télémétrie.

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

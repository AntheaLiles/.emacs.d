---
description: Lance toutes les vérifications du dépôt (REUSE, Lisp, tests ERT)
---

Depuis la racine du dépôt, exécute dans l'ordre et résume les résultats :

1. `reuse lint`
2. `emacs -Q --batch -l scripts/check.el` — distingue erreurs (bloquantes) et
   avertissements (à signaler, non bloquants).
3. `emacs -Q --batch --eval '(setq my/perf-root (make-temp-file "perf-" t))' -l perf/perf-start.el -l perf/perf-self-test.el -f ert-run-tests-batch-and-exit`
4. `emacs -Q --batch -L lisp -l tests/my-export-config-test.el -f ert-run-tests-batch-and-exit`
5. `emacs -Q --batch -L lisp -l tests/my-config-test.el -f ert-run-tests-batch-and-exit`
6. Si le préambule LaTeX, l'export ou le style CSL ont changé :
   `tests/regression/run.sh` (compilation LuaLaTeX réelle).

Les tests propres à Emacs 31 sont ignorés sur une version antérieure : seule
la CI sous 31.1 fait foi.

Termine par un tableau : vérification, statut, points à corriger.

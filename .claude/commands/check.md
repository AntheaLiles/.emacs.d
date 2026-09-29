---
description: Lance toutes les vérifications du dépôt (REUSE, Lisp, test ERT)
---

Depuis la racine du dépôt, exécute dans l'ordre et résume les résultats :

1. `reuse lint`
2. `emacs -Q --batch -l scripts/check.el` — distingue erreurs (bloquantes) et
   avertissements (à signaler, non bloquants).
3. `emacs -Q --batch --eval '(setq my/perf-root (make-temp-file "perf-" t))' -l perf/perf-start.el -l perf/perf-self-test.el -f ert-run-tests-batch-and-exit`

Termine par un tableau : vérification, statut, points à corriger.

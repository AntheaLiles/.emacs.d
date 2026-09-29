# SPDX-FileCopyrightText: 2026 AntheaLiles
# SPDX-License-Identifier: CC0-1.0
#
# Raccourcis pour les vérifications locales.  Usage : make check

EMACS ?= emacs

.PHONY: check reuse lint test

check: reuse lint test

reuse:
	reuse lint

lint:
	$(EMACS) -Q --batch -l scripts/check.el

test:
	$(EMACS) -Q --batch \
	  --eval '(setq my/perf-root (make-temp-file "perf-" t))' \
	  -l perf/perf-start.el -l perf/perf-self-test.el \
	  -f ert-run-tests-batch-and-exit

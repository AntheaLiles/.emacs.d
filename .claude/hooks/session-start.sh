#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 AntheaLiles
# SPDX-License-Identifier: CC0-1.0
#
# Prépare les sessions Claude Code sur le web : installe les outils
# nécessaires aux vérifications du dépôt (reuse, emacs).  Sans effet en
# local, où l'environnement de la machine fait foi.
set -uo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

if ! command -v reuse >/dev/null 2>&1; then
  pip install --quiet --user reuse >/dev/null 2>&1 \
    || pip install --quiet reuse >/dev/null 2>&1 \
    || echo "session-start: installation de reuse impossible" >&2
fi

if ! command -v emacs >/dev/null 2>&1; then
  { apt-get update -qq && apt-get install -y -qq --no-install-recommends emacs-nox; } \
    >/dev/null 2>&1 \
    || echo "session-start: installation d'emacs impossible" >&2
fi

exit 0

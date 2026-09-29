#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 AntheaLiles
# SPDX-License-Identifier: CC0-1.0
#
# Mesure le temps de compilation d'un document exporté par Org, sous
# plusieurs variantes, sur la machine réelle (TeX Live, polices, .bib).
# Aucune modification du document ni de la configuration : tout se passe
# dans un répertoire temporaire.
#
# Usage :
#   scripts/bench-latex.sh chemin/vers/document.tex
#   (le .tex produit par C-c C-e l l ; le .bib qu'il cite doit exister)
#
# Variantes mesurées (compilation complète, à froid) :
#   actuel     options actuelles d'org-latex-pdf-process
#   runxml     + règle latexmkrc ignorant l'état des requêtes biblatex
#   sansbalis  sans balisage PDF/UA (testphase retiré de \DocumentMetadata)
#   sousbib    biber lit une .bib réduite aux entrées citées
# puis le temps d'une recompilation après une petite modification.
set -uo pipefail

src=${1:?usage: $0 document.tex}
[ -f "$src" ] || { echo "introuvable : $src" >&2; exit 1; }
here=$(cd "$(dirname "$0")/.." && pwd)
rc="$here/latex/latexmkrc"
srcdir=$(cd "$(dirname "$src")" && pwd)
base=$(basename "$src" .tex)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cp -r "$srcdir"/. "$work/" 2>/dev/null
cd "$work" || exit 1

cat "$rc" > rc-runxml
echo "\$hash_calc_ignore_pattern{'xml'} = '^\\s*<(?:internal|external) package=\"biblatex\"';" >> rc-runxml

now() { date +%s.%N; }
compile() { # $1 = latexmkrc, $2 = fichier .tex, $3 = répertoire de sortie
  rm -rf "$3"; mkdir -p "$3"
  local s e; s=$(now)
  latexmk -lualatex -shell-escape -interaction=nonstopmode -f \
          -output-directory="$3" -r "$1" "$2" > "$3.latexmk.log" 2>&1
  e=$(now)
  printf '%-10s %7.1f s   lualatex=%s biber=%s   erreurs=%s\n' "$3" \
    "$(echo "$e - $s" | bc)" \
    "$(grep -c "Run number .* of rule 'lualatex'" "$3.latexmk.log")" \
    "$(grep -c "Run number .* of rule 'biber" "$3.latexmk.log")" \
    "$(n=$(grep -c '^!' "$3/${2%.tex}.log" 2>/dev/null); echo "${n:-?}")"
}

echo "== $base ($(lualatex --version | head -1))"
compile "$rc"       "$base.tex" actuel
compile rc-runxml   "$base.tex" runxml

sed 's/,[[:space:]]*testphase=[^,}]*//' "$base.tex" > sansbalis.tex
compile rc-runxml sansbalis.tex sansbalis

# .bib réduite : biber sait écrire les seules entrées citées (et leurs
# crossref) à partir du .bcf de la compilation précédente.
if [ -f runxml/"$base".bcf ]; then
  biber --output-format=bibtex --output-resolve --output-file=sous.bib \
        --input-directory=. runxml/"$base" > /dev/null 2>&1
  if [ -s sous.bib ]; then
    sed 's#\\addbibresource{[^}]*}#\\addbibresource{sous.bib}#' "$base.tex" > sousbib.tex
    compile rc-runxml sousbib.tex sousbib
    printf '           (%s entrées au lieu de %s)\n' \
      "$(grep -c '^@' sous.bib)" \
      "$(cat $(sed -n 's#.*\\addbibresource{\([^}]*\)}.*#\1#p' "$base.tex") 2>/dev/null | grep -c '^@')"
  fi
fi

# Recompilation après une retouche du texte (cas quotidien)
echo '% retouche' >> "$base.tex"
s=$(now)
latexmk -lualatex -shell-escape -interaction=nonstopmode -f \
        -output-directory=runxml -r rc-runxml "$base.tex" > retouche.log 2>&1
e=$(now)
printf '%-10s %7.1f s   lualatex=%s biber=%s\n' retouche "$(echo "$e - $s" | bc)" \
  "$(grep -c "Run number .* of rule 'lualatex'" retouche.log)" \
  "$(grep -c "Run number .* of rule 'biber" retouche.log)"

#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 AntheaLiles
# SPDX-License-Identifier: CC0-1.0
#
# Banc de non-régression de l'export PDF/UA, de bout en bout.
#
# Exporte tests/regression/essai.org par le chemin réel (processus
# asynchrone : lisp/my-export-async.el, backend pdfua), en article-ua et en
# book-ua, puis compile avec latexmk et vérifie : remarques en marge,
# éléments de flottant, code en ligne, drawio (simulacre), titres :ignore:,
# Babel, bibliographies CSL par section, profil brouillon, compilation sans
# erreur, nombre de passes et mise en page des deux classes.
#
# Usage : tests/regression/run.sh      (make regress)
# Requiert : emacs, latexmk, lualatex, TeX Live (latex-extra, lang-french),
# python3 (Babel) et git (dépendances Lisp clonées au premier passage dans
# ~/.cache/emacs-d-regress, ou $REGRESS_DEPS).
#
# Vérifications sur le PDF (pagination, corps de la bibliographie, première
# page) : tests/regression/pdfcheck.py, qui requiert PyMuPDF ; sans lui, elles
# sont ignorées et signalées.
#
# Adaptations automatiques, signalées à l'écran :
#   - polices Luciole / Iosevka absentes → DejaVu et Latin Modern Math ;
#   - TeX Live antérieur à 2024 → balisage phase-III retiré (non supporté).
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HERE=$ROOT/tests/regression
# Hors du dépôt : reuse lint examinerait ces clones.
DEPS=${REGRESS_DEPS:-${XDG_CACHE_HOME:-$HOME/.cache}/emacs-d-regress}
WORK=$(mktemp -d)
# REGRESS_KEEP=1 : conserver les fichiers produits, pour inspection
if [ -n "${REGRESS_KEEP:-}" ]; then echo "  (fichiers conservés dans $WORK)"
else trap 'rm -rf "$WORK"' EXIT; fi
fail=0

ok()   { printf '  ✓ %s\n' "$1"; }
ko()   { printf '  ✗ %s\n' "$1"; fail=1; }
check() { # check DESCRIPTION COMMANDE...
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi
}

# --- Dépendances Lisp (hors Elpaca) ------------------------------------------
declare -A REPOS=(
  [citeproc-el]=andras-simonyi/citeproc-el [dash.el]=magnars/dash.el
  [s.el]=magnars/s.el [f.el]=rejeep/f.el [string-inflection]=akicho8/string-inflection
  [queue]=emacsmirror/queue [compat]=emacs-compat/compat
  [parsebib]=joostkremers/parsebib [engrave-faces]=tecosaur/engrave-faces)
mkdir -p "$DEPS"
LOADPATH=()
for d in "${!REPOS[@]}"; do
  [ -d "$DEPS/$d" ] || git clone -q --depth 1 "https://github.com/${REPOS[$d]}.git" "$DEPS/$d" \
    || { echo "clonage impossible : ${REPOS[$d]}" >&2; exit 2; }
  LOADPATH+=(-L "$DEPS/$d")
done

# --- Environnement de test ---------------------------------------------------
mkdir -p "$WORK/home/wiki/00.resources" "$WORK/doc/img"
cp "$HERE/references.json" "$WORK/home/wiki/00.resources/references.json"
cp "$HERE/essai.org" "$WORK/doc/"
echo '<mxfile><diagram>stub</diagram></mxfile>' > "$WORK/doc/img/schema.drawio"
cp "$(kpsewhich example-image-a.pdf)" "$WORK/doc/img/photo.pdf"
chmod +x "$HERE/stub-bin/drawio"

# Copie de latex/ : polices de repli si les vraies manquent
mkdir -p "$WORK/emacsd"
cp -r "$ROOT/latex" "$WORK/emacsd/"
[ -d "$ROOT/assets" ] && cp -r "$ROOT/assets" "$WORK/emacsd/"
if ! fc-list 2>/dev/null | grep -q "Luciole"; then
  echo "  (polices Luciole/Iosevka absentes : substitution par DejaVu)"
  perl -0pi -e 's/\\setmainfont\{Luciole-Regular\.ttf\}\[[^\]]*\]/\\setmainfont{DejaVu Serif}/;
                s/\\setmonofont\{IosevkaSS05-Regular\.ttf\}\[[^\]]*\]/\\setmonofont{DejaVu Sans Mono}/;
                s/\\setmathfont\{Luciole-Math\.otf\}/\\setmathfont{latinmodern-math.otf}/' \
    "$WORK/emacsd/latex/preamble-common.tex"
fi
PDFCHECK=0
if python3 -c 'import fitz' 2>/dev/null; then PDFCHECK=1
elif [ -n "${CI:-}" ]; then ko "PyMuPDF requis en CI (vérifications sur le PDF)"
else echo "  (PyMuPDF absent : vérifications sur le PDF ignorées)"; fi
pdf() { # pdf DESCRIPTION ARGS… : vérification pdfcheck.py sur le dernier PDF
  local d=$1; shift
  [ $PDFCHECK = 1 ] || { printf '  - %s (ignoré)\n' "$d"; return; }
  local out; out=$(python3 "$HERE/pdfcheck.py" "$PDF" "$@" 2>&1)
  if [ $? = 0 ]; then ok "$d — $out"; else ko "$d — $out"; fi
}

TLYEAR=$(lualatex --version | sed -n 's/.*TeX Live \([0-9]\{4\}\).*/\1/p' | head -1)
STRIP_TAGGING=0
if [ "${TLYEAR:-0}" -lt 2024 ]; then
  STRIP_TAGGING=1
  echo "  (TeX Live $TLYEAR : balisage phase-III non supporté, retiré pour la compilation)"
fi

# --- Export ------------------------------------------------------------------
export_doc() { # export_doc CLASSE FORME-LISP
  # Deux « local » : dans un seul, $cls vaudrait encore celui de l'appelant.
  local cls=$1 form=$2
  local dir=$WORK/out-$cls
  rm -rf "$dir"; cp -r "$WORK/doc" "$dir"
  [ "$cls" = book-ua ] && sed -i '1i #+LATEX_CLASS: book-ua' "$dir/essai.org"
  ( cd "$dir" && HOME=$WORK/home PATH=$HERE/stub-bin:$PATH emacs -Q --batch \
      --eval "(setq user-emacs-directory \"$ROOT/\")" "${LOADPATH[@]}" \
      -l "$ROOT/lisp/my-export-async.el" \
      --eval "(progn (setq org-confirm-babel-evaluate nil)
                     (find-file \"essai.org\")
                     $form)" > export.log 2>&1 )
}

compile_doc() { # compile_doc CLASSE → variables PASSES, ERREURS, PAGES
  local dir=$WORK/out-$1
  perl -pi -e "s#\Q$ROOT/\E#$WORK/emacsd/#g" "$dir/essai.tex"
  [ $STRIP_TAGGING = 1 ] && perl -0pi -e 's/,\s*pdfstandard=ua-2//; s/,\s*testphase=phase-III//' "$dir/essai.tex"
  ( cd "$dir" && latexmk -lualatex -f -interaction=nonstopmode -output-directory=build \
                   -r "$ROOT/latex/latexmkrc" essai.tex > latexmk.log 2>&1 )
  LATEXMK=$?
  PASSES=$(grep -c "Run number .* of rule 'lualatex'" "$dir/latexmk.log")
  ERREURS=$(grep -c '^!' "$dir/build/essai.log" 2>/dev/null)
  PAGES=$(sed -n 's/^Output written on .*(\([0-9]*\) page.*/\1/p' "$dir/build/essai.log" 2>/dev/null | tail -1)
  PAGES=${PAGES:-0}
  PDF=$dir/build/essai.pdf
  MANQUANTS=$(grep -c "Missing character" "$dir/build/essai.log" 2>/dev/null)
}

for cls in article-ua book-ua; do
  echo "== $cls"
  export_doc $cls "(my/pdfua-export-to-latex)"
  T=$WORK/out-$cls/essai.tex
  check "export réussi" test -s "$T"
  check "classe $cls" grep -q "preamble-$cls\.tex" "$T"
  check "remarque en marge, emphase et citation incluses" grep -q '\\RMQ{marge avec \\textbf{emphase}' "$T"
  check "[rmq:…] littéral dans un bloc de code" grep -q 'rmq:ceci doit rester littéral' "$T"
  check "titre :ignore: retiré, contenu conservé" \
    bash -c "! grep -q 'Titre à ignorer' '$T' && grep -q 'Ce paragraphe doit rester' '$T'"
  check "éléments de flottant (DESC, NOTE avec emphase finale, SOURCE)" \
    bash -c "grep -q 'descfig{Ce que le schéma' '$T' && grep -q 'notefig{Comment lire le \\\\textbf{schéma} }' '$T' && grep -q 'srcfig{Fait avec drawio}' '$T'"
  check "texte alternatif, largeur de :options conservée" \
    grep -q 'includegraphics\[width=.8\\linewidth,alt={Schéma de principe à trois boîtes}\]' "$T"
  check "drawio converti, lien file: conservé" grep -q '{img/schema.pdf}' "$T"
  check "code en ligne (\\CodeInline) et lua-ul demandé" \
    bash -c "grep -q 'CodeInline{x\\\\_1' '$T' && grep -q '^\\\\def\\\\uacodeinline{}' '$T'"
  check "Babel : calcul Python exécuté" grep -q 'Calcul : \\texttt{42}' "$T"
  check "deux bibliographies" test "$(grep -c 'begin{bibliographieua}' "$T")" = 2
  check "titres à la biblatex (subbibliography ; subbibintoc et :title)" \
    bash -c "grep -q '^\\\\subsection\*{\\\\refname}\$' '$T' \
             && grep -q 'subsection\*{Sources de la section}\\\\addcontentsline{toc}{subsection}' '$T'"
  check "modules : tikz chargé avant styles-figures" \
    bash -c "grep -n 'modules/\(tikz\|styles-figures\)\.tex' '$T' | cut -d: -f2- | tr '\n' ' ' \
             | grep -q 'tikz\.tex.*styles-figures\.tex'"
  # Org ≤ 9.7 : \citeprocitem ; Org 9.8 (Emacs 31) : \cslcitation
  check "citations CSL [n]" grep -Eq '\[\\(citeprocitem|cslcitation)\{' "$T"
  check "bibliographie de la section 3 : seulement ses références" \
    bash -c "sed -n '/Dans cette section/,\$p' '$T' | grep -q 'Citée seulement en section 3' \
             && ! sed -n '/Dans cette section/,\$p' '$T' | grep -q 'Communication A'"
  compile_doc $cls
  check "compilation sans erreur (latexmk=$LATEXMK, erreurs=$ERREURS)" \
    test "$LATEXMK" = 0 -a "$ERREURS" = 0
  check "au plus 3 passes lualatex, sans biber ($PASSES)" \
    bash -c "[ $PASSES -le 3 ] && ! grep -q \"rule 'biber\" '$WORK/out-$cls/latexmk.log'"
  check "aucun caractère manquant dans les polices ($MANQUANTS)" test "$MANQUANTS" = 0
  pdf "numéro de page et total sur chaque page" footer
  pdf "bibliographie en \\scriptsize (8 pt)" size "Martin," 8
  pdf "titres de bibliographie imprimés" count "Références" 1
  pdf "titre :title imprimé" count "Sources de la section" 1
  pdf "résumé en première page" page 1 "Ce résumé doit tenir"
  pdf "mots-clés en première page" page 1 "Mots-clés"
  pdf "titre centré sur la page (page de titre sans zone de notes)" centered 1 "Banc de non-régression"
  pdf "introduction hors de la page de titre" absent 1 "Introduction"
  pdf "icônes ORCID (authentifié et non authentifié)" images 1 2
  [ $cls = article-ua ] && pdf "introduction en page 2" page 2 "Introduction"
  [ $cls = book-ua ] && pdf "introduction en page 3 (impaire)" page 3 "Introduction"
  eval "PAGES_${cls%-ua}=$PAGES"
done

echo "== export LaTeX standard (C-c C-e l) d'un document article-ua"
export_doc std "(progn (goto-char (point-min)) (insert \"#+LATEX_CLASS: article-ua\\n\") (org-latex-export-to-latex))"
S=$WORK/out-std/essai.tex
check "classe article-ua" grep -q 'preamble-article-ua\.tex' "$S"
check "chaîne PDF/UA appliquée (remarques, bibliographies, code en ligne)" \
  bash -c "grep -q 'RMQ{marge' '$S' && grep -q 'begin{bibliographieua}' '$S' && grep -q 'CodeInline{x' '$S'"

echo "== export LaTeX standard d'un document en article : intact"
export_doc std "(org-latex-export-to-latex)"
check "classe article, sans traitement PDF/UA" \
  bash -c "grep -q 'documentclass\\[11pt\\]{article}' '$S' && ! grep -q 'RMQ{\\|bibliographieua\\|CodeInline' '$S'"

echo "== renvois résolus malgré une erreur LaTeX (latexmk -f)"
mkdir -p "$WORK/erreur"
cat > "$WORK/erreur/t.tex" <<'TEX'
\documentclass{article}
\usepackage{graphicx,lastpage}
\begin{document}
Voir figure \ref{fig:a}, page \pageref{LastPage}.
\includegraphics{image-absente.png}
\begin{figure}\caption{A}\label{fig:a}\end{figure}
\end{document}
TEX
# Même commande que org-latex-pdf-process
CMD=$(cd "$ROOT" && emacs -Q --batch -L lisp \
        --eval "(setq user-emacs-directory \"$ROOT/\")" \
        --eval "(progn (require 'my-export-config) (princ (car org-latex-pdf-process)))" 2>/dev/null)
CMD=${CMD//%o/.}
( cd "$WORK/erreur" && eval "${CMD//%f/t.tex}" >/dev/null 2>&1 )
PDF=$WORK/erreur/t.pdf
pdf "« figure 1, page 1 » et non « ?? »" page 1 "Voir figure 1, page 1."

echo "== mise en page"
check "book-ua plus long qu'article-ua (sections sur page impaire : $PAGES_book > $PAGES_article)" \
  test "$PAGES_book" -gt "$PAGES_article"

echo "== profil brouillon"
export_doc article-ua "(my/pdfua-export-to-latex nil nil nil nil '(:ua-draft t))"
D=$WORK/out-article-ua/essai.tex
check "\\DocumentMetadata sans balisage" \
  bash -c "grep -q 'DocumentMetadata{lang=fr,pdfversion=2.0}' '$D' && ! grep -q testphase '$D'"
compile_doc article-ua
check "PDF brouillon compilé sans erreur" test "$LATEXMK" = 0 -a "$ERREURS" = 0

echo
if [ $fail = 0 ]; then echo "Banc de non-régression : tout est conforme."; else echo "Banc de non-régression : ÉCHECS ci-dessus."; fi
exit $fail

#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 AntheaLiles
# SPDX-License-Identifier: CC0-1.0
"""Vérifications sur un PDF compilé, pour tests/regression/run.sh.

Usage :
  pdfcheck.py PDF footer              chaque page p porte « p / N »
  pdfcheck.py PDF page N TEXTE        TEXTE figure en page N
  pdfcheck.py PDF count TEXTE K       TEXTE figure K fois dans le document
  pdfcheck.py PDF absent N TEXTE      TEXTE ne figure pas en page N
  pdfcheck.py PDF centered N TEXTE    TEXTE est centré sur la page N (± 12 pt)
  pdfcheck.py PDF images N K          la page N contient K images
  pdfcheck.py PDF size TEXTE TAILLE   TEXTE est composé en TAILLE pt (± 0,3)
Code de sortie 0 si la vérification réussit ; le détail sur la sortie.
Requiert PyMuPDF (python3 -m pip install pymupdf).
"""
import sys

try:
    import pymupdf as fitz
except ImportError:                     # PyMuPDF < 1.24
    import fitz

doc = fitz.open(sys.argv[1])
check, args = sys.argv[2], sys.argv[3:]

def texte(i):
    # Espaces insécables et fines ramenées à l'espace simple
    return doc[i].get_text().replace(" ", " ").replace(" ", " ")

if check == "footer":
    n = len(doc)
    manque = [p for p in range(1, n + 1) if f"{p} / {n}" not in texte(p - 1)]
    print(f"{n} pages ; sans « p / {n} » : {manque or 'aucune'}")
    sys.exit(1 if manque else 0)
elif check == "page":
    n, cherche = int(args[0]), args[1]
    ok = cherche in texte(n - 1)
    print(f"« {cherche} » en page {n} : {'oui' if ok else 'non'}")
    sys.exit(0 if ok else 1)
elif check == "absent":
    n, cherche = int(args[0]), args[1]
    ok = cherche not in texte(n - 1)
    print(f"« {cherche} » absent de la page {n} : {'oui' if ok else 'non'}")
    sys.exit(0 if ok else 1)
elif check == "centered":
    n, cherche = int(args[0]), args[1]
    page = doc[n - 1]
    zones = page.search_for(cherche)
    if not zones:
        print(f"« {cherche} » introuvable en page {n}")
        sys.exit(1)
    centre, milieu = (zones[0].x0 + zones[0].x1) / 2, page.rect.width / 2
    print(f"« {cherche} » : centre à {centre:.0f} pt, milieu de page {milieu:.0f} pt")
    sys.exit(0 if abs(centre - milieu) <= 12 else 1)
elif check == "images":
    n, k = int(args[0]), int(args[1])
    nb = len(doc[n - 1].get_image_info())
    print(f"{nb} image(s) en page {n} (attendu {k})")
    sys.exit(0 if nb == k else 1)
elif check == "count":
    cherche, k = args[0], int(args[1])
    n = sum(texte(i).count(cherche) for i in range(len(doc)))
    print(f"« {cherche} » : {n} fois (attendu {k})")
    sys.exit(0 if n == k else 1)
elif check == "size":
    cherche, taille = args[0], float(args[1])
    tailles = sorted({round(s["size"], 1)
                      for page in doc
                      for b in page.get_text("dict")["blocks"]
                      for l in b.get("lines", [])
                      for s in l["spans"] if cherche in s["text"]})
    print(f"« {cherche} » en {tailles} pt (attendu {taille})")
    sys.exit(0 if tailles and all(abs(t - taille) <= 0.3 for t in tailles) else 1)
sys.exit(2)

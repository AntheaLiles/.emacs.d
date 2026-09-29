# Contribuer

Merci de l'intérêt porté à ce dépôt.

## Les contributions ne sont pas acceptées pour l'instant

Ce dépôt contient une **configuration Emacs personnelle**, publiée à titre de
référence. Il n'accepte pas de contributions extérieures à ce stade :

- les **pull requests** seront fermées sans être fusionnées ;
- les **tickets** de demande de fonctionnalité ne seront pas traités.

Cette politique pourra évoluer ; le cas échéant, ce fichier sera mis à jour.

## Ce qui reste possible

- **Réutiliser** librement tout ou partie de la configuration, dans le respect
  des licences décrites dans [LICENSE.md](LICENSE.md) (et en citant la source
  via [CITATION.cff](CITATION.cff) si c'est pertinent).
- **Forker** le dépôt pour l'adapter à vos besoins.
- **Signaler un problème de sécurité** en privé, selon
  [SECURITY.md](SECURITY.md).

## Conventions internes (pour mémoire)

Ces règles s'appliquent à toute modification du dépôt, y compris celles
réalisées avec un assistant :

- chaque fichier porte un en-tête SPDX ou est couvert par `REUSE.toml`
  (`reuse lint` doit passer) ;
- tout fichier Emacs Lisp déclare `lexical-binding: t` et respecte la
  structure `;;; Commentary:` / `;;; Code:` / `(provide …)` / `;;; … ends here` ;
- les fonctions et variables maison sont préfixées par `my/` ;
- les commentaires sont en français, les docstrings en anglais ;
- chaque changement notable est consigné dans [CHANGELOG.md](CHANGELOG.md) ;
- les messages de commit suivent la forme `type(portée): résumé`
  (ex. `fix(export): …`, `feat(org): …`, `docs: …`, `chore: …`).

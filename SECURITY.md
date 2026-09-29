# Politique de sécurité

## Périmètre

Ce dépôt est une configuration Emacs personnelle. Elle exécute du code à
chaque démarrage et interagit avec le système ; les points sensibles sont
notamment :

- l'**amorçage d'Elpaca** (`init.el`), qui clone et compile du code depuis
  GitHub, puis les paquets déclarés via `use-package` ;
- la **compilation LaTeX avec `-shell-escape`** (`lisp/my-export-config.el`),
  qui permet à un document `.org`/`.tex` d'exécuter des commandes système ;
- l'**exécution de blocs Org Babel** et l'export asynchrone ;
- les **processus externes** (serveurs de langage, hunspell, ripgrep,
  latexmk) et les connexions **TRAMP** ;
- la **télémétrie** (`perf/perf-start.el`), qui écrit sur le disque local
  (jamais sur le réseau) des informations sur les processus ; les arguments de
  ligne de commande ne sont pas journalisés par défaut
  (`my/perf-log-process-args`).

## Versions prises en charge

Seule la dernière révision de la branche `main` est maintenue.

| Version | Prise en charge |
| --- | --- |
| `main` (dernière révision) | ✅ |
| Révisions antérieures | ❌ |

## Signaler une vulnérabilité

**Ne pas ouvrir de ticket public** pour un problème de sécurité.

Utiliser le signalement privé de GitHub :
**Security → Report a vulnerability**
(<https://github.com/AntheaLiles/.emacs.d/security/advisories/new>).

Merci d'indiquer :

- le fichier et la ligne concernés ;
- le scénario d'exploitation (quel fichier ouvert, quelle commande lancée) ;
- l'impact (exécution de code, fuite d'information…) ;
- une correction proposée, le cas échéant.

Il s'agit d'un projet personnel maintenu sur le temps libre : un accusé de
réception est visé sous 14 jours, sans garantie de délai de correction.

## Bonnes pratiques pour qui réutilise cette configuration

- Lire `init.el` avant le premier lancement : il télécharge et exécute du code.
- N'exporter en PDF que des documents Org/LaTeX de confiance, à cause de
  `-shell-escape`.
- Garder `org-confirm-babel-evaluate` actif pour les fichiers d'origine
  inconnue.
- Ne jamais versionner `custom.el`, l'historique (`history`) ni les données de
  `perf/` : ils peuvent contenir des chemins, des noms d'hôtes TRAMP ou le
  contenu du kill-ring. Le `.gitignore` les exclut déjà.

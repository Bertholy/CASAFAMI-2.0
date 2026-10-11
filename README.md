# CASAFAMI — site et gestion du cabinet d'accouchement

## ⚡ Démarrage rapide

Après avoir installé **Git, Java 17+, Node 20+ et PostgreSQL** (voir plus bas) :

```powershell
git clone --recurse-submodules https://github.com/Bertholy/casafami.git
cd casafami
.\setup.ps1      # une seule fois : configuration, base de données, dépendances
.\dev.ps1        # lance le serveur et le site
```
Puis ouvrez **http://localhost:5173**.  *(Linux / macOS : `./setup.sh` puis `./dev.sh`.)*

Site public (rendez-vous en ligne, français / malagasy), espace du personnel (médecin, sage-femme, infirmière, secrétaire) et espace super administrateur (comptes, rôles et permissions, planning, sauvegardes, modification du site).

Ce dépôt réunit **tout le projet** : il récupère le serveur et le site en une seule commande.

| Dossier | Contenu | Dépôt |
|---|---|---|
| `backend/cabinet` | Serveur Spring Boot 4 (Java 17), Maven | [cabinet-medical-backend](https://github.com/Bertholy/cabinet-medical-backend) |
| `frontend` | Site React 19 + Vite + Tailwind 4 | [casafami-frontend](https://github.com/Bertholy/casafami-frontend) |
| `scripts` | Sauvegarde / restauration de la base | ici |
| `setup.ps1`, `setup.sh`, `dev.ps1`, `dev.sh` | Installation et lancement | ici |

## Ce qu'il faut installer (une seule fois)

| Outil | Version | Où le trouver |
|---|---|---|
| Git | récent | https://git-scm.com |
| Java (JDK) | 17 ou plus | https://adoptium.net |
| Node.js | 20 ou plus (22 conseillé) | https://nodejs.org |
| PostgreSQL | 16 | https://www.postgresql.org (retenez le mot de passe de l'utilisateur `postgres`) |

Maven n'est pas à installer : le projet embarque son propre `mvnw`.

## Installer et lancer

```bash
git clone --recurse-submodules https://github.com/Bertholy/casafami.git casafami
cd casafami
```

**Windows (PowerShell)**
```powershell
.\setup.ps1      # vérifie les outils, crée la configuration et la base, installe les dépendances
.\dev.ps1        # lance le serveur (8080) et le site (5173)
```

**Linux / macOS / Git Bash**
```bash
./setup.sh
./dev.sh
```

Puis ouvrez **http://localhost:5173**. Le premier démarrage du serveur prend 30 à 60 secondes (les tables sont créées toutes seules).


Si vous avez oublié `--recurse-submodules` : `git submodule update --init --recursive`.

### Premier compte super administrateur
Aucun compte n'est fourni avec le code. Donnez une adresse et un mot de passe à l'installation :

```powershell
.\setup.ps1 -AdminEmail admin@exemple.mg -AdminPassword "un-mot-de-passe-long"
```
(Linux/macOS : `ADMIN_EMAIL=... ADMIN_PASSWORD=... ./setup.sh`). Détails dans `backend/cabinet/ADMIN_SETUP.md`.

## Ce qui n'est volontairement PAS dans Git
- `backend/cabinet/config/application.properties` : mot de passe PostgreSQL et clé de connexion (créé par `setup`, jamais publié) ; le modèle est `application.example.properties`.
- Les photos téléversées (`uploads/`), les sauvegardes (`backups/`), `node_modules/`, `target/` : se recréent ou se sauvegardent à part.
- Les SMS (Twilio) et les e-mails sont **simulés** tant qu'ils ne sont pas configurés : voir `DEPLOY.md` §6 bis et §7.

## Pour aller plus loin
- `DEPLOY.md` : mise en ligne, HTTPS, sauvegardes, liste de contrôle avant ouverture au public.
- `backend/cabinet/ADMIN_SETUP.md` : rôles, permissions, premier super administrateur.
- `backend/cabinet/MISES_A_JOUR.md` et `frontend/MISES_A_JOUR.md` : ce qui a changé.
- Tests : `cd backend/cabinet && ./mvnw test` (base de test `casafami_test` à créer) ; `cd frontend && npm run lint`.

## Mettre à jour son clone
```bash
git pull --recurse-submodules
git submodule update --init --recursive
```

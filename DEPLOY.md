# CASAFAMI — Installation, mise en ligne et sauvegardes

## 1. Ce qu'il faut

| Outil | Version | Rôle |
|---|---|---|
| Java (JDK) | 17 ou plus | exécute le serveur (backend) |
| PostgreSQL | 16 | base de données |
| Node.js | 22 | compile le site (frontend) — pas nécessaire sur le serveur final |

## 2. Base de données

```sql
CREATE DATABASE casafami ENCODING 'UTF8';
```

Les tables sont créées automatiquement au premier démarrage. Au démarrage, le serveur crée aussi les horaires d'ouverture par défaut
(lundi–vendredi 8h–11h et 14h–17h, créneaux de 30 min) et l'index qui empêche un praticien d'avoir deux rendez-vous au même moment.

## 3. Configuration (variables d'environnement)

**Aucun secret n'est écrit dans le code.** Deux valeurs sont obligatoires : le mot de passe PostgreSQL et la clé de connexion (`CASAFAMI_JWT_SECRET`) ; le serveur refuse de démarrer sans clé valable.

- **En local** : copiez `backend/cabinet/config/application.example.properties` en `backend/cabinet/config/application.properties` (ce fichier est ignoré par Git) et remplissez-le. Spring Boot le lit tout seul quand le serveur est lancé depuis `backend/cabinet`.
- **Sur un serveur** : définissez les mêmes noms comme variables d'environnement.

| Variable | Rôle | Exemple |
|---|---|---|
| `CASAFAMI_DB_PASSWORD` | mot de passe PostgreSQL | un mot de passe long |
| `CASAFAMI_JWT_SECRET` | clé de signature des connexions (Base64, 256 bits minimum) | `openssl rand -base64 48` |
| `CASAFAMI_CORS_ORIGINS` | adresse(s) publique(s) du site | `https://casafami.mg` |
| `CASAFAMI_DB_URL` / `CASAFAMI_DB_USER` | base et utilisateur | `jdbc:postgresql://localhost:5432/casafami` |
| `CASAFAMI_UPLOAD_DIR` | dossier des photos (à sauvegarder) | `D:\casafami\uploads` |
| `PORT` | port du serveur | `8080` |
| `CASAFAMI_SUPER_ADMIN_EMAIL` / `CASAFAMI_SUPER_ADMIN_PASSWORD` | création du premier super administrateur (voir `backend/cabinet/ADMIN_SETUP.md`) | |
| `CASAFAMI_SMS_MODE`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM` | SMS réels (voir §7) | |
| `CASAFAMI_MAIL_HOST`, `CASAFAMI_MAIL_PORT`, `CASAFAMI_MAIL_USER`, `CASAFAMI_MAIL_PASSWORD`, `CASAFAMI_MAIL_FROM` | e-mails du « mot de passe oublié » (voir §6 bis) | `smtp.gmail.com`, `587` |
| `CASAFAMI_FRONTEND_URL` | adresse publique du site, utilisée dans le lien envoyé par e-mail | `https://casafami.mg` |
| `CASAFAMI_BACKUP_DIR`, `CASAFAMI_BACKUP_AUTO`, `CASAFAMI_BACKUP_KEEP`, `CASAFAMI_PG_DUMP` | dossier, activation, nombre conservé et chemin de `pg_dump` pour les sauvegardes automatiques | `D:\sauvegardes`, `true`, `14` |

Ne publiez jamais ces valeurs (dépôt Git, capture d'écran, message).

## 4. Construire et lancer

```powershell
# Serveur
cd backend\cabinet
.\mvnw.cmd -DskipTests package
java -jar target\cabinet-0.0.1-SNAPSHOT.jar

# Site : l'adresse de l'API est fixée à la construction
cd frontend
npm ci
$env:VITE_API_URL = "/api"      # le site et l'API sont servis depuis la même adresse (voir §5)
npm run build                   # résultat dans frontend\dist
```

Si le site et l'API ont deux adresses différentes, mettez l'adresse complète de l'API : `VITE_API_URL=https://api.casafami.mg/api`
et ajoutez l'adresse du site dans `CASAFAMI_CORS_ORIGINS`.

Pour un lancement automatique au démarrage de Windows : Planificateur de tâches → « Au démarrage de l'ordinateur » → programme `java`,
arguments `-jar C:\casafami\cabinet.jar`, avec les variables d'environnement définies au niveau système. Sous Linux : un service `systemd`.

## 5. Mise en ligne (exemple Nginx + HTTPS)

Le site (fichiers de `frontend/dist`) et l'API passent par le même nom de domaine, ce qui évite tout problème de CORS :

```nginx
server {
    listen 443 ssl http2;
    server_name casafami.mg;
    # certificat : sudo certbot --nginx -d casafami.mg

    root /var/www/casafami;            # contenu de frontend/dist
    index index.html;

    location / { try_files $uri /index.html; }          # le site gère ses propres routes
    location /api/ { proxy_pass http://127.0.0.1:8080; proxy_set_header X-Forwarded-For $remote_addr; client_max_body_size 6m; }
    location /uploads/ { proxy_pass http://127.0.0.1:8080; }
}
server { listen 80; server_name casafami.mg; return 301 https://$host$request_uri; }
```

Ouvrez uniquement les ports 80 et 443 sur le pare-feu : **le port 8080 et PostgreSQL (5432) ne doivent pas être accessibles depuis Internet.**

## 6. Sauvegardes (à mettre en place avant d'ouvrir le site aux patients)

**Automatiques, dans l'application.** Tant que le serveur tourne, il sauvegarde la base et les photos dès que la dernière sauvegarde a plus de 24 heures (contrôle toutes les 30 minutes : l'ordinateur n'a pas besoin d'être allumé à une heure précise). Les 14 dernières sont conservées dans `backups/` (ou `CASAFAMI_BACKUP_DIR`). Si une sauvegarde échoue, le super administrateur reçoit une notification. La page **Sauvegardes** (menu d'administration) permet de lancer une sauvegarde, de voir la dernière et de télécharger les fichiers. L'outil `pg_dump` de PostgreSQL doit être installé sur la machine du serveur (il est détecté automatiquement).

**Manuelles ou planifiées par le système.** Deux scripts sont fournis dans `scripts/` (PowerShell) :

```powershell
$env:CASAFAMI_DB_PASSWORD = "..."
.\scripts\backup-db.ps1                       # crée backups\casafami-AAAAMMJJ-HHMMSS.dump + photos-....zip, garde les 14 dernières
.\scripts\restore-db.ps1 -Fichier .\backups\casafami-20261010-180000.dump    # restaure dans une NOUVELLE base « casafami_restauree »
```

- **Copiez régulièrement les fichiers hors de l'ordinateur** (disque externe, stockage en ligne) : une sauvegarde sur le même disque ne protège pas d'une panne ou d'un vol.
- Testez une restauration une fois : une sauvegarde jamais testée n'est pas une sauvegarde.
- La restauration refuse d'écraser la base en service : elle crée une nouvelle base à vérifier, puis on bascule (`CASAFAMI_DB_URL`).

## 6 bis. « Mot de passe oublié » (e-mails)

Sur la page de connexion, « Mot de passe oublié ? » envoie au membre du personnel un lien valable 30 minutes, à usage unique. Le super administrateur reçoit aussi une notification et peut toujours réinitialiser le mot de passe dans **Comptes et accès**.

- **Sans serveur d'e-mails** (réglage par défaut) : rien n'est envoyé ; le lien est écrit dans les journaux du serveur (`[E-MAIL SIMULÉ]`) et le super administrateur est notifié.
- **Avec Gmail** : activez la validation en deux étapes du compte, créez un « mot de passe d'application », puis renseignez `CASAFAMI_MAIL_HOST=smtp.gmail.com`, `CASAFAMI_MAIL_PORT=587`, `CASAFAMI_MAIL_USER`, `CASAFAMI_MAIL_PASSWORD` (le mot de passe d'application) et `CASAFAMI_FRONTEND_URL`.

## 7. Activer les vrais SMS (à faire avant la semaine de soutenance)

Aujourd'hui `sms.mode=simulation` : les SMS (confirmation, annulation, rappel de la veille, notification au médecin) sont **écrits dans les journaux du serveur, rien n'est envoyé**.
Le code d'envoi Twilio est prêt et testé ; il ne manque que le compte :

1. Créez un compte sur twilio.com (essai gratuit : un crédit de départ, valable un temps limité). En essai, Twilio n'envoie qu'aux numéros que vous avez **vérifiés** dans la console.
2. Notez le *Account SID*, l'*Auth Token* et un numéro expéditeur (ou un identifiant d'expéditeur, si l'opérateur malgache l'accepte).
3. Définissez `CASAFAMI_SMS_MODE=twilio`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM`, puis redémarrez le serveur.
4. Testez : prenez un rendez-vous avec un numéro vérifié, puis confirmez-le depuis le tableau de bord — le SMS doit arriver. Les erreurs d'envoi sont visibles dans les journaux (`SMS refusé par Twilio…`).
5. Après l'essai, l'envoi devient payant à chaque SMS : vérifiez les tarifs vers Madagascar et le solde avant la mise en service réelle.

Les numéros sont enregistrés au format local (034 12 345 67) et convertis automatiquement au format international exigé par l'opérateur au moment de l'envoi.

## 8. Avant d'ouvrir au public — liste de contrôle

- [ ] `CASAFAMI_JWT_SECRET` et mot de passe PostgreSQL changés (l'ancienne clé de l'historique Git est refusée par le serveur ; si le dépôt est public, changez aussi le mot de passe PostgreSQL : `ALTER USER postgres PASSWORD '...'`).
- [ ] Site en HTTPS ; ports 8080 et 5432 fermés vers l'extérieur.
- [ ] Premier super administrateur créé avec un mot de passe long ; variables `CASAFAMI_SUPER_ADMIN_*` retirées ensuite.
- [ ] Horaires et congés vérifiés (menu *Horaires et congés*).
- [ ] Sauvegardes automatiques actives (page *Sauvegardes*), copie hors de l'ordinateur organisée et restauration testée.
- [ ] SMS réels activés et testés (§7), ou information donnée aux patients qu'ils ne recevront pas de SMS.
- [ ] Fiches maladies / traitements saisies **par le médecin** (l'assistant d'ordonnance ne contient aucun protocole médical par défaut).

## 9. Mettre à jour

1. Faites une sauvegarde (`backup-db.ps1`).
2. Arrêtez le serveur, remplacez le fichier `.jar` et le dossier du site, relancez.
3. Les nouvelles tables sont créées automatiquement ; vérifiez la page de connexion et le tableau de bord.

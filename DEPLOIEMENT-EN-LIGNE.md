# Mettre CASAFAMI en ligne gratuitement (Neon + Render + Netlify)

Trois services gratuits, chacun s'identifie avec votre compte GitHub. Comptez **30 à 40 minutes** la première fois.

```
Patients / personnel ──▶ Netlify (le site)  ──▶ Render (le serveur)  ──▶ Neon (la base PostgreSQL)
```

Tout est déjà préparé dans le code : `backend/cabinet/Dockerfile` et `render.yaml` (serveur), `frontend/netlify.toml` (site).
**Ce que vous devez faire vous-même** : créer les 3 comptes et copier quelques valeurs (personne d'autre ne peut le faire à votre place).

> Gardez un bloc-notes ouvert : vous allez copier des adresses et des mots de passe d'un service à l'autre. **Ne les publiez jamais** (ni Git, ni capture d'écran).

---

## Étape 1 — La base de données (Neon)

1. https://neon.tech → **Sign up** avec GitHub.
2. **Create project** : nom `casafami`, version PostgreSQL 16, région la plus proche (Frankfurt ou Singapore).
3. Sur la page du projet, bouton **Connect** : repérez l'**hôte** (`ep-xxxx.region.aws.neon.tech`), la **base** (`neondb`), l'**utilisateur** et le **mot de passe**.
4. Fabriquez l'adresse JDBC (à garder) :
   `jdbc:postgresql://HOTE/neondb?sslmode=require`
   (sans mot de passe dedans : il se donne à part, étape 2).

## Étape 2 — Le serveur (Render)

1. https://render.com → **Get started** avec GitHub.
2. **New +** → **Blueprint** → choisissez le dépôt **cabinet-medical-backend** (autorisez l'accès si demandé).
3. Render lit `render.yaml` et affiche les variables à remplir :

| Variable | Valeur |
|---|---|
| `CASAFAMI_DB_URL` | l'adresse JDBC de l'étape 1 |
| `CASAFAMI_DB_USER` | l'utilisateur Neon |
| `CASAFAMI_DB_PASSWORD` | le mot de passe Neon |
| `CASAFAMI_JWT_SECRET` | une clé secrète : sur votre PC, `node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"` et collez le résultat |
| `CASAFAMI_SUPER_ADMIN_EMAIL` | votre adresse e-mail (premier super administrateur) |
| `CASAFAMI_SUPER_ADMIN_PASSWORD` | un mot de passe long, au moins 10 caractères |
| `CASAFAMI_CORS_ORIGINS` et `CASAFAMI_FRONTEND_URL` | laissez vide pour l'instant (étape 4) |

4. **Apply** / **Deploy**. La première construction dure **8 à 12 minutes**.
5. Quand c'est « Live », ouvrez `https://casafami-api.onrender.com/api/planning` : vous devez voir du texte JSON (les horaires). Si l'adresse de votre service est différente (nom déjà pris), notez-la.

## Étape 3 — Le site (Netlify)

1. https://app.netlify.com → **Sign up** avec GitHub.
2. **Add new site** → **Import an existing project** → GitHub → dépôt **casafami-frontend**.
3. **Branch to deploy** : `design-montagne` (nouveau design) ou `main` (ancien design — mais `netlify.toml` n'existe que sur `design-montagne` tant que la fusion n'est pas faite).
4. Les réglages de construction sont lus dans `netlify.toml` : ne changez rien. **Deploy**.
5. Si l'adresse de votre serveur Render n'est pas `https://casafami-api.onrender.com`, allez dans **Site configuration → Environment variables** et créez `VITE_API_URL` = `https://VOTRE-SERVEUR.onrender.com/api`, puis **Deploys → Trigger deploy**.
6. Notez l'adresse du site : `https://xxxx.netlify.app` (vous pouvez la changer : **Site configuration → Change site name**).

## Étape 4 — Relier le site et le serveur

Retournez sur Render → votre service → **Environment** et renseignez, **sans « / » à la fin** :

- `CASAFAMI_CORS_ORIGINS` = `https://xxxx.netlify.app`
- `CASAFAMI_FRONTEND_URL` = `https://xxxx.netlify.app`

Enregistrez : le serveur redémarre (1 à 2 minutes). Ouvrez ensuite `https://xxxx.netlify.app` : le site s'affiche, la prise de rendez-vous fonctionne.

## Étape 5 — Se connecter et vérifier

1. `https://xxxx.netlify.app/medecin/login` avec l'e-mail et le mot de passe de l'étape 2.
2. Dans Render, **retirez** la variable `CASAFAMI_SUPER_ADMIN_PASSWORD` (le compte existe maintenant).
3. **Rôles et permissions**, **Comptes et accès** : créez les comptes du personnel.
4. Faites une réservation de test comme un patient, puis vérifiez la notification du super administrateur.

---

## À savoir (limites de la formule gratuite)

- **Le serveur s'endort après 15 minutes sans visite** : la première personne qui arrive attend 30 à 60 secondes. Solution gratuite : https://uptimerobot.com → un « monitor » HTTP sur `https://casafami-api.onrender.com/api/planning`, toutes les 5 minutes.
- **Les photos téléversées ne sont pas conservées** : le disque de Render gratuit est effacé à chaque redémarrage ou mise à jour. Les photos des services retombent alors sur les images par défaut du site ; les photos de profil disparaissent. Pour les garder : disque payant Render (≈ 1 $/mois pour 1 Go) ou un stockage d'images externe (à ajouter plus tard).
- **Les sauvegardes** : l'application ne peut pas faire de `pg_dump` sur cet hébergement ; c'est **Neon** qui garde l'historique de la base (restauration dans Neon → *Backup & Restore*). Pour une copie à vous : `scripts/backup-db.ps1` depuis votre PC avec l'adresse Neon.
- **Les SMS restent simulés** jusqu'à la configuration de Twilio (variables `CASAFAMI_SMS_MODE=twilio`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM` sur Render). Les e-mails du « mot de passe oublié » aussi (`CASAFAMI_MAIL_*`).
- **Mettre à jour** : un `git push` sur GitHub redéploie automatiquement le serveur (Render) et le site (Netlify).
- **Nom de domaine** (casafami.mg ou autre) : Netlify → *Domain management*, puis mettez ce domaine dans `CASAFAMI_CORS_ORIGINS` et `CASAFAMI_FRONTEND_URL`.
- **Avant d'ouvrir aux patients** : relisez la liste de contrôle de `DEPLOY.md` §8.

## En cas de problème

| Symptôme | Cause probable |
|---|---|
| Le site s'affiche mais « serveur injoignable » | `VITE_API_URL` faux, ou le serveur dort (attendez 1 minute) |
| Erreur « CORS » dans la console du navigateur | `CASAFAMI_CORS_ORIGINS` ne correspond pas exactement à l'adresse du site (sans « / » final) |
| Render : « no password was provided » / ne démarre pas | `CASAFAMI_DB_PASSWORD` ou `CASAFAMI_JWT_SECRET` absent |
| Render : « Out of memory » | l'offre gratuite (512 Mo) est juste : relancez, ou passez à l'offre à 7 $/mois |
| Page blanche au rechargement d'une adresse (`/services`) | la règle de redirection de `netlify.toml` manque : vérifiez qu'elle est bien dans le dépôt |

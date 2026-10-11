#!/usr/bin/env bash
# Installe tout ce qu'il faut pour lancer CASAFAMI après un « git clone » (Linux, macOS, Git Bash).
#   1. vérifie Java 17+, Node 20+ et PostgreSQL ; 2. récupère le backend et le frontend (sous-modules Git) ;
#   3. crée backend/cabinet/config/application.properties ; 4. crée la base PostgreSQL ;
#   5. installe les dépendances du site (npm ci) et compile le serveur (Maven).
# Variables facultatives : DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD ADMIN_EMAIL ADMIN_PASSWORD SKIP_BUILD=1
set -euo pipefail
cd "$(dirname "$0")"

DB_HOST="${DB_HOST:-localhost}"; DB_PORT="${DB_PORT:-5432}"; DB_NAME="${DB_NAME:-casafami}"; DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-${CASAFAMI_DB_PASSWORD:-}}"; ADMIN_EMAIL="${ADMIN_EMAIL:-}"; ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
manque=0
etape() { printf '\n\033[36m[%s/5] %s\033[0m\n' "$1" "$2"; }
absent() { printf '  \033[31mMANQUE : %s\033[0m\n' "$1"; manque=1; }

etape 1 "Vérification des outils"
java_major=$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -1 || true)
if [ "${java_major:-0}" -ge 17 ] 2>/dev/null; then echo "  Java $java_major : ok"; else absent "Java 17 ou plus (JDK) : https://adoptium.net"; fi
node_major=$(node --version 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/' || true)
if [ "${node_major:-0}" -ge 20 ] 2>/dev/null; then echo "  Node $node_major : ok"; else absent "Node.js 20 ou plus : https://nodejs.org"; fi
command -v git >/dev/null || absent "Git"
if command -v psql >/dev/null; then have_psql=1; echo "  PostgreSQL (psql) : ok"; else have_psql=0; echo "  psql introuvable : créez la base à la main (CREATE DATABASE casafami ENCODING 'UTF8';)"; fi
[ "$manque" = 0 ] || { echo; echo "Installez ce qui manque puis relancez ./setup.sh"; exit 1; }

etape 2 "Récupération du backend et du frontend"
[ -e .git ] && git submodule update --init --recursive
[ -f backend/cabinet/pom.xml ] && [ -f frontend/package.json ] || { echo "Backend/frontend introuvables : clonez avec « git clone --recurse-submodules <adresse> »"; exit 1; }
echo "  backend et frontend présents"

etape 3 "Configuration privée (jamais publiée sur GitHub)"
config=backend/cabinet/config/application.properties
if [ -f "$config" ]; then
  echo "  $config existe déjà : conservé"
else
  if [ -z "$DB_PASSWORD" ]; then read -r -s -p "  Mot de passe de l'utilisateur PostgreSQL '$DB_USER' : " DB_PASSWORD; echo; fi
  cle=$(head -c 48 /dev/urandom | base64 | tr -d '\n')
  {
    echo "# Généré par setup.sh - fichier privé, ignoré par Git."
    echo "CASAFAMI_DB_PASSWORD=$DB_PASSWORD"
    echo "CASAFAMI_JWT_SECRET=$cle"
    echo "CASAFAMI_DB_URL=jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME"
    echo "CASAFAMI_DB_USER=$DB_USER"
    if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
      echo "CASAFAMI_SUPER_ADMIN_EMAIL=$ADMIN_EMAIL"; echo "CASAFAMI_SUPER_ADMIN_PASSWORD=$ADMIN_PASSWORD"
    fi
  } > "$config"
  chmod 600 "$config" 2>/dev/null || true
  echo "  $config créé"
  [ -n "$ADMIN_EMAIL" ] || echo "  Pensez à créer le premier super administrateur : voir backend/cabinet/ADMIN_SETUP.md"
fi

etape 4 "Base de données PostgreSQL"
if [ "$have_psql" = 1 ] && [ -n "$DB_PASSWORD" ]; then
  export PGPASSWORD="$DB_PASSWORD"
  if existe=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null); then
    if [ "$existe" = "1" ]; then echo "  base '$DB_NAME' existe déjà"
    else psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -qc "CREATE DATABASE \"$DB_NAME\" ENCODING 'UTF8' TEMPLATE template0" && echo "  base '$DB_NAME' créée (les tables se créent toutes seules au premier démarrage)"; fi
  else echo "  Connexion à PostgreSQL impossible (serveur arrêté ? mot de passe ?). Créez la base à la main puis relancez."; fi
  unset PGPASSWORD
else
  echo "  étape ignorée (psql ou mot de passe absent) : CREATE DATABASE $DB_NAME ENCODING 'UTF8';"
fi

etape 5 "Dépendances du site et du serveur"
(cd frontend && npm ci)
if [ "${SKIP_BUILD:-0}" = 1 ]; then echo "  compilation du serveur ignorée (SKIP_BUILD=1)"; else (cd backend/cabinet && ./mvnw -q -DskipTests package) && echo "  serveur compilé"; fi

printf '\n\033[32mTerminé. Pour lancer CASAFAMI : ./dev.sh   (site : http://localhost:5173 - serveur : http://localhost:8080)\033[0m\n'

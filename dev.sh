#!/usr/bin/env bash
# Lance CASAFAMI en développement : le serveur (port 8080) et le site (port 5173). Ctrl+C arrête les deux.
set -euo pipefail
cd "$(dirname "$0")"
[ -f backend/cabinet/config/application.properties ] || { echo "Configuration absente : lancez d'abord ./setup.sh"; exit 1; }
(cd backend/cabinet && ./mvnw spring-boot:run) &
serveur=$!
trap 'kill $serveur 2>/dev/null || true' EXIT INT TERM
echo "Serveur : http://localhost:8080   Site : http://localhost:5173  (patientez 30 à 60 secondes au premier démarrage)"
cd frontend && npm run dev

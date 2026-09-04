#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

readonly INFRA_FILE="docker-compose.infra.yml"
readonly NETWORK_NAME="tipster-network"

echo "Starte Tipster-Infrastruktur (PostgreSQL, MinIO, MailHog) ..."

if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
  docker network create "${NETWORK_NAME}" >/dev/null
  echo "Netzwerk '${NETWORK_NAME}' wurde erstellt."
fi

docker compose -f "${INFRA_FILE}" up -d

echo "Infrastruktur läuft:"
echo "  PostgreSQL: localhost:5432"
echo "  MailHog:    http://localhost:8025"
echo "  MinIO:      http://localhost:9001"

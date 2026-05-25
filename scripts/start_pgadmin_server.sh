#!/usr/bin/env bash
set -euo pipefail

PGADMIN_CONTAINER="${PGADMIN_CONTAINER:-fred_macro_pgadmin}"
PGADMIN_IMAGE="${PGADMIN_IMAGE:-dpage/pgadmin4:latest}"
NETWORK_NAME="${NETWORK_NAME:-fred_macro_net}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-fred_macro_postgres}"
TAILSCALE_IP="${TAILSCALE_IP:-100.72.157.21}"
PGADMIN_PORT="${PGADMIN_PORT:-5050}"
PGADMIN_EMAIL="${PGADMIN_EMAIL:-admin@example.com}"
PGADMIN_PASSWORD="${PGADMIN_PASSWORD:-change_me_now}"
VOLUME_NAME="${VOLUME_NAME:-fred_macro_pgadmin_data}"

docker network create "${NETWORK_NAME}" >/dev/null 2>&1 || true
docker network connect "${NETWORK_NAME}" "${POSTGRES_CONTAINER}" >/dev/null 2>&1 || true

if docker ps -a --format '{{.Names}}' | grep -qx "${PGADMIN_CONTAINER}"; then
  docker start "${PGADMIN_CONTAINER}"
else
  docker volume create "${VOLUME_NAME}" >/dev/null
  docker run -d \
    --name "${PGADMIN_CONTAINER}" \
    --restart unless-stopped \
    --network "${NETWORK_NAME}" \
    -p "${TAILSCALE_IP}:${PGADMIN_PORT}:80" \
    -v "${VOLUME_NAME}:/var/lib/pgadmin" \
    -e PGADMIN_DEFAULT_EMAIL="${PGADMIN_EMAIL}" \
    -e PGADMIN_DEFAULT_PASSWORD="${PGADMIN_PASSWORD}" \
    "${PGADMIN_IMAGE}"
fi

docker ps --filter name="${PGADMIN_CONTAINER}"

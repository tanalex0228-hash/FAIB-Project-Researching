#!/usr/bin/env bash
set -euo pipefail

METABASE_CONTAINER="${METABASE_CONTAINER:-fred_macro_metabase}"
METABASE_IMAGE="${METABASE_IMAGE:-metabase/metabase:latest}"
NETWORK_NAME="${NETWORK_NAME:-fred_macro_net}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-fred_macro_postgres}"
TAILSCALE_IP="${TAILSCALE_IP:-100.72.157.21}"
METABASE_PORT="${METABASE_PORT:-3000}"
VOLUME_NAME="${VOLUME_NAME:-fred_macro_metabase_data}"

docker network create "${NETWORK_NAME}" >/dev/null 2>&1 || true
docker network connect "${NETWORK_NAME}" "${POSTGRES_CONTAINER}" >/dev/null 2>&1 || true

if docker ps -a --format '{{.Names}}' | grep -qx "${METABASE_CONTAINER}"; then
  docker start "${METABASE_CONTAINER}"
  docker network connect "${NETWORK_NAME}" "${METABASE_CONTAINER}" >/dev/null 2>&1 || true
else
  docker volume create "${VOLUME_NAME}" >/dev/null
  docker run -d \
    --name "${METABASE_CONTAINER}" \
    --restart unless-stopped \
    --network "${NETWORK_NAME}" \
    -p "${TAILSCALE_IP}:${METABASE_PORT}:3000" \
    -v "${VOLUME_NAME}:/metabase-data" \
    -e MB_DB_FILE=/metabase-data/metabase.db \
    "${METABASE_IMAGE}"
fi

docker network connect "${NETWORK_NAME}" "${POSTGRES_CONTAINER}" >/dev/null 2>&1 || true
docker network connect "${NETWORK_NAME}" "${METABASE_CONTAINER}" >/dev/null 2>&1 || true

docker ps --filter name="${METABASE_CONTAINER}"

#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-fred_macro_postgres}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-fred_macro}"
TAILSCALE_IP="${TAILSCALE_IP:-100.72.157.21}"
VOLUME_NAME="${VOLUME_NAME:-fred_macro_postgres_data}"

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  docker start "${CONTAINER_NAME}"
else
  docker volume create "${VOLUME_NAME}" >/dev/null
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -p 127.0.0.1:5432:5432 \
    -p "${TAILSCALE_IP}:5432:5432" \
    -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
    "${POSTGRES_IMAGE}" \
    -c shared_preload_libraries=pg_stat_statements \
    -c pg_stat_statements.track=all \
    -c log_connections=on \
    -c log_disconnections=on \
    -c log_line_prefix='%m [%p] user=%u db=%d app=%a client=%h '
fi

docker ps --filter name="${CONTAINER_NAME}"

#!/usr/bin/env bash
set -euo pipefail

CADDY_CONTAINER="${CADDY_CONTAINER:-fred_macro_caddy}"
CADDY_IMAGE="${CADDY_IMAGE:-caddy:2}"
NETWORK_NAME="${NETWORK_NAME:-fred_macro_net}"
PUBLIC_HOSTNAME="${PUBLIC_HOSTNAME:-}"
ACME_EMAIL="${ACME_EMAIL:-}"
CADDY_DATA_VOLUME="${CADDY_DATA_VOLUME:-fred_macro_caddy_data}"
CADDY_CONFIG_VOLUME="${CADDY_CONFIG_VOLUME:-fred_macro_caddy_config}"
CADDYFILE_DIR="${CADDYFILE_DIR:-.public_deploy}"
CADDYFILE_PATH="${CADDYFILE_DIR}/Caddyfile"

if [[ -z "${PUBLIC_HOSTNAME}" ]]; then
  echo "Missing PUBLIC_HOSTNAME."
  echo "Example:"
  echo "  sudo PUBLIC_HOSTNAME='metabase.example.com' ACME_EMAIL='you@example.com' $0"
  exit 1
fi

mkdir -p "${CADDYFILE_DIR}"

{
  if [[ -n "${ACME_EMAIL}" ]]; then
    echo "{"
    echo "    email ${ACME_EMAIL}"
    echo "}"
    echo
  fi
  echo "${PUBLIC_HOSTNAME} {"
  echo "    encode gzip zstd"
  echo "    reverse_proxy fred_macro_metabase:3000"
  echo "}"
} > "${CADDYFILE_PATH}"

docker network create "${NETWORK_NAME}" >/dev/null 2>&1 || true
docker network connect "${NETWORK_NAME}" fred_macro_metabase >/dev/null 2>&1 || true

if docker ps -a --format '{{.Names}}' | grep -qx "${CADDY_CONTAINER}"; then
  docker rm -f "${CADDY_CONTAINER}" >/dev/null
fi

docker volume create "${CADDY_DATA_VOLUME}" >/dev/null
docker volume create "${CADDY_CONFIG_VOLUME}" >/dev/null

docker run -d \
  --name "${CADDY_CONTAINER}" \
  --restart unless-stopped \
  --network "${NETWORK_NAME}" \
  -p 80:80 \
  -p 443:443 \
  -v "$(pwd)/${CADDYFILE_PATH}:/etc/caddy/Caddyfile:ro" \
  -v "${CADDY_DATA_VOLUME}:/data" \
  -v "${CADDY_CONFIG_VOLUME}:/config" \
  "${CADDY_IMAGE}"

docker ps --filter name="${CADDY_CONTAINER}"

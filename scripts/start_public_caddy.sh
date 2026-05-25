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
PUBLIC_HTTP_PORT="${PUBLIC_HTTP_PORT:-80}"
PUBLIC_HTTPS_PORT="${PUBLIC_HTTPS_PORT:-443}"

if [[ -z "${PUBLIC_HOSTNAME}" ]]; then
  echo "Missing PUBLIC_HOSTNAME."
  echo "Example:"
  echo "  sudo PUBLIC_HOSTNAME='metabase.example.com' ACME_EMAIL='you@example.com' $0"
  exit 1
fi

mkdir -p "${CADDYFILE_DIR}"

{
  echo "{"
  if [[ -n "${ACME_EMAIL}" ]]; then
    echo "    email ${ACME_EMAIL}"
  fi
  if [[ "${PUBLIC_HTTP_PORT}" != "80" ]]; then
    echo "    http_port ${PUBLIC_HTTP_PORT}"
  fi
  if [[ "${PUBLIC_HTTPS_PORT}" != "443" ]]; then
    echo "    https_port ${PUBLIC_HTTPS_PORT}"
  fi
  echo "}"
  echo
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
  -p "${PUBLIC_HTTP_PORT}:${PUBLIC_HTTP_PORT}" \
  -p "${PUBLIC_HTTPS_PORT}:${PUBLIC_HTTPS_PORT}" \
  -v "$(pwd)/${CADDYFILE_PATH}:/etc/caddy/Caddyfile:ro" \
  -v "${CADDY_DATA_VOLUME}:/data" \
  -v "${CADDY_CONFIG_VOLUME}:/config" \
  "${CADDY_IMAGE}"

docker ps --filter name="${CADDY_CONTAINER}"

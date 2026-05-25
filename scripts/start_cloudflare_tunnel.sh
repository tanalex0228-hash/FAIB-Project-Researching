#!/usr/bin/env bash
set -euo pipefail

CLOUDFLARED_CONTAINER="${CLOUDFLARED_CONTAINER:-fred_macro_cloudflared}"
CLOUDFLARED_IMAGE="${CLOUDFLARED_IMAGE:-cloudflare/cloudflared:latest}"
NETWORK_NAME="${NETWORK_NAME:-fred_macro_net}"
TUNNEL_TOKEN="${TUNNEL_TOKEN:-}"

if [[ -z "${TUNNEL_TOKEN}" ]]; then
  echo "Missing TUNNEL_TOKEN."
  echo "Create a Cloudflare Tunnel in the Cloudflare dashboard, add a public hostname,"
  echo "then run:"
  echo "  sudo TUNNEL_TOKEN='eyJ...' $0"
  exit 1
fi

docker network create "${NETWORK_NAME}" >/dev/null 2>&1 || true
docker network connect "${NETWORK_NAME}" fred_macro_metabase >/dev/null 2>&1 || true

if docker ps -a --format '{{.Names}}' | grep -qx "${CLOUDFLARED_CONTAINER}"; then
  docker rm -f "${CLOUDFLARED_CONTAINER}" >/dev/null
fi

docker run -d \
  --name "${CLOUDFLARED_CONTAINER}" \
  --restart unless-stopped \
  --network "${NETWORK_NAME}" \
  "${CLOUDFLARED_IMAGE}" \
  tunnel --no-autoupdate run --token "${TUNNEL_TOKEN}"

docker ps --filter name="${CLOUDFLARED_CONTAINER}"

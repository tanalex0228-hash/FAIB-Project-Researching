#!/usr/bin/env bash
set -euo pipefail

# Exposes Metabase on all server interfaces at :3000.
# Use this when your router forwards an external port to 192.168.50.206:3000.
METABASE_BIND_IP="${METABASE_BIND_IP:-0.0.0.0}" \
METABASE_PORT="${METABASE_PORT:-3000}" \
RECREATE_METABASE=1 \
"$(dirname "$0")/start_metabase_server.sh"

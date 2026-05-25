#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-fred_macro_postgres}"
POSTGRES_DB="${POSTGRES_DB:-fred_macro}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

docker cp scripts/setup_research_views.sql "${CONTAINER_NAME}:/tmp/setup_research_views.sql"
docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -f /tmp/setup_research_views.sql

echo "Research views are ready:"
echo "  research.monthly_macro_long"
echo "  research.monthly_macro_wide"

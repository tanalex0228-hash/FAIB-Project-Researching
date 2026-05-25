#!/usr/bin/env bash
set -euo pipefail

TEAM_PREFIX="${TEAM_PREFIX:-member}"
TEAM_SIZE="${TEAM_SIZE:-5}"
PGADMIN_EMAIL="${PGADMIN_EMAIL:-admin@example.com}"
PGADMIN_PASSWORD="${PGADMIN_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/')}"
CREDENTIAL_FILE="${CREDENTIAL_FILE:-team_credentials.local}"

chmod +x scripts/start_postgres_server.sh
chmod +x scripts/setup_usage_monitoring.sh
chmod +x scripts/create_research_users.sh
chmod +x scripts/start_metabase_server.sh
chmod +x scripts/start_pgadmin_server.sh

scripts/start_postgres_server.sh

if [[ -x ".venv/bin/python" ]]; then
  .venv/bin/python -m app.sync_fred
else
  python3 -m app.sync_fred
fi

scripts/setup_usage_monitoring.sh
scripts/setup_research_views.sh

user_specs=()
{
  echo "# Team credentials"
  echo "# Keep this file on the server owner machine only."
  echo "# Generated at: $(date -Iseconds)"
  echo
  echo "PGADMIN_URL=http://100.72.157.21:5050"
  echo "PGADMIN_EMAIL=${PGADMIN_EMAIL}"
  echo "PGADMIN_PASSWORD=${PGADMIN_PASSWORD}"
  echo
  echo "METABASE_URL=http://100.72.157.21:3000"
  echo
  echo "# PostgreSQL research accounts"
} > "${CREDENTIAL_FILE}"

for i in $(seq -f "%02g" 1 "${TEAM_SIZE}"); do
  username="${TEAM_PREFIX}${i}"
  password="$(openssl rand -base64 24 | tr -d '=+/')"
  user_specs+=("${username}=${password}")
  {
    echo "${username}_DATABASE_URL=postgresql+psycopg2://${username}:${password}@100.72.157.21:5432/fred_macro"
    echo "${username}_USERNAME=${username}"
    echo "${username}_PASSWORD=${password}"
    echo
  } >> "${CREDENTIAL_FILE}"
done

scripts/create_research_users.sh "${user_specs[@]}"

PGADMIN_EMAIL="${PGADMIN_EMAIL}" \
PGADMIN_PASSWORD="${PGADMIN_PASSWORD}" \
scripts/start_pgadmin_server.sh

scripts/start_metabase_server.sh

chmod 600 "${CREDENTIAL_FILE}"

echo "Team platform bootstrap complete."
echo "Credentials file: ${CREDENTIAL_FILE}"
echo "Metabase: http://100.72.157.21:3000"
echo "pgAdmin:  http://100.72.157.21:5050"

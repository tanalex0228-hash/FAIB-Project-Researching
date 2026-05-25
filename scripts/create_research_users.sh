#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-fred_macro_postgres}"
POSTGRES_DB="${POSTGRES_DB:-fred_macro}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

if [[ "$#" -lt 1 ]]; then
  echo "Usage: sudo $0 username=password [username=password ...]"
  exit 1
fi

for pair in "$@"; do
  username="${pair%%=*}"
  password="${pair#*=}"

  if [[ "${username}" == "${password}" || -z "${username}" || -z "${password}" ]]; then
    echo "Invalid user spec: ${pair}"
    exit 1
  fi

  if [[ ! "${username}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "Invalid username: ${username}"
    exit 1
  fi

  role_exists="$(
    docker exec "${CONTAINER_NAME}" \
      psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -tAc \
      "select 1 from pg_roles where rolname='${username}'"
  )"

  if [[ "${role_exists}" == "1" ]]; then
    docker exec "${CONTAINER_NAME}" \
      psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
      "alter role ${username} with login password '${password}' nosuperuser nocreatedb nocreaterole noinherit;"
  else
    docker exec "${CONTAINER_NAME}" \
      psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
      "create role ${username} login password '${password}' nosuperuser nocreatedb nocreaterole noinherit;"
  fi

  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
    "grant connect on database ${POSTGRES_DB} to ${username};"

  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
    "grant usage on schema public to ${username};"

  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
    "grant usage on schema research to ${username};"

  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
    "grant select on fred_series, macro_data, macro_features to ${username};"

  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
    "grant select on all tables in schema research to ${username};"

  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
    "alter role ${username} set statement_timeout = '10min';"

  echo "Research user is ready: ${username}"
done

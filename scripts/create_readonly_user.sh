#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-fred_macro_postgres}"
POSTGRES_DB="${POSTGRES_DB:-fred_macro}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
READER_USER="${READER_USER:-macro_reader}"
READER_PASSWORD="${READER_PASSWORD:-macro_reader_change_me}"

ROLE_EXISTS="$(
  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -tAc \
    "select 1 from pg_roles where rolname='${READER_USER}'"
)"

if [[ "${ROLE_EXISTS}" == "1" ]]; then
  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
    "alter role ${READER_USER} with login password '${READER_PASSWORD}';"
else
  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
    "create role ${READER_USER} login password '${READER_PASSWORD}';"
fi

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "grant connect on database ${POSTGRES_DB} to ${READER_USER};"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "grant usage on schema public to ${READER_USER};"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "grant usage on schema research to ${READER_USER};"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "grant select on all tables in schema public to ${READER_USER};"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "grant select on all tables in schema research to ${READER_USER};"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "alter default privileges in schema public grant select on tables to ${READER_USER};"

echo "Read-only user is ready: ${READER_USER}"

#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-fred_macro_postgres}"
POSTGRES_DB="${POSTGRES_DB:-fred_macro}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "alter system set shared_preload_libraries = 'pg_stat_statements';"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "alter system set pg_stat_statements.track = 'all';"

docker restart "${CONTAINER_NAME}" >/dev/null
sleep 5

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "create extension if not exists pg_stat_statements;"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "create schema if not exists admin;"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "create or replace view admin.user_query_usage as
   select
       r.rolname as username,
       d.datname as database_name,
       s.calls,
       s.rows,
       round(s.total_exec_time::numeric, 2) as total_exec_ms,
       round(s.mean_exec_time::numeric, 2) as mean_exec_ms,
       s.shared_blks_hit,
       s.shared_blks_read,
       s.temp_blks_written,
       left(s.query, 500) as query_sample
   from pg_stat_statements s
   join pg_roles r on r.oid = s.userid
   join pg_database d on d.oid = s.dbid
   where d.datname = '${POSTGRES_DB}'
   order by s.total_exec_time desc;"

docker exec "${CONTAINER_NAME}" \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c \
  "create or replace view admin.user_usage_summary as
   select
       username,
       count(*) as query_patterns,
       sum(calls) as total_calls,
       sum(rows) as total_rows_returned,
       round(sum(total_exec_ms), 2) as total_exec_ms,
       round(avg(mean_exec_ms), 2) as avg_mean_exec_ms,
       sum(shared_blks_read) as shared_blocks_read,
       sum(temp_blks_written) as temp_blocks_written
   from admin.user_query_usage
   group by username
   order by total_exec_ms desc;"

echo "Usage monitoring is ready. Admin views:"
echo "  admin.user_query_usage"
echo "  admin.user_usage_summary"

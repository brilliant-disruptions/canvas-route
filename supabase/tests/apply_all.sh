#!/usr/bin/env bash
# Applies every migration, in order, to a fresh Postgres database that mimics a new
# Supabase project (auth, storage, cron stubs; function bodies are checked, as on
# Supabase), then checks that every public table has RLS.
#
#   PGHOST=/var/run/postgresql PGUSER=postgres supabase/tests/apply_all.sh
#
# Needs Postgres 15+ with the contrib extensions (cube, earthdistance, pgcrypto).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
db="${DB:-canvasroute_migration_check}"
psql_q() { psql -q -X "$@"; }

psql_q -d postgres -c "drop database if exists $db" -c "create database $db" >/dev/null
psql_q -d "$db" -v ON_ERROR_STOP=1 -f "$here/supabase_platform.sql" >/dev/null 2>&1
psql_q -d postgres -c "alter database $db set search_path = public, extensions" >/dev/null

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for f in "$here"/../migrations/0*.sql; do
  # pg_cron isn't installable outside Supabase; cron.schedule is stubbed instead.
  sed -e 's/^create extension if not exists "pg_cron";/-- pg_cron stubbed/' "$f" > "$tmp"
  if ! out="$(psql_q -d "$db" -v ON_ERROR_STOP=1 -f "$tmp" 2>&1)"; then
    echo "FAIL $(basename "$f")"; echo "$out" | grep -A2 ERROR; exit 1
  fi
  echo "ok   $(basename "$f")"
done

no_rls="$(psql_q -d "$db" -At -c "select string_agg(c.relname, ', ') from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity")"
if [ -n "$no_rls" ]; then echo "FAIL tables without RLS: $no_rls"; exit 1; fi
echo "All migrations applied; every public table has RLS."

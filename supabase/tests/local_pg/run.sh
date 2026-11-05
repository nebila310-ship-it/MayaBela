#!/usr/bin/env bash
# Replays every migration into a scratch local database, then runs the
# role-by-role policy tests. Uses only a local Postgres (PGHOST/PGPORT/PGUSER
# as usual). Never point this at a Supabase project.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
db="${LOCAL_PG_TEST_DB:-mayabela_policy_test}"

export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"
psql_q() { psql -v ON_ERROR_STOP=1 -q -X "$@"; }

psql_q -d postgres -c "drop database if exists \"$db\";"
psql_q -d postgres -c "create database \"$db\";"
psql_q -d "$db" -c "create extension if not exists pgcrypto;"
psql_q -d "$db" -f "$here/00_supabase_stubs.sql"

for f in "$root"/supabase/migrations/*.sql; do
  # pg_net is a Supabase extension; the stub schema provides net.http_post.
  sed -e 's/^create extension if not exists pg_net;//' "$f" \
    | psql_q -d "$db" -f - >/dev/null \
    || { echo "migration failed: $(basename "$f")" >&2; exit 1; }
done
echo "Replayed $(ls "$root"/supabase/migrations/*.sql | wc -l) migrations into $db."

status=0
for t in "$here"/tests/*.sql; do
  echo "== $(basename "$t")"
  if ! psql -v ON_ERROR_STOP=1 -X -q -d "$db" -f "$t"; then
    status=1
  fi
done
exit $status

#!/usr/bin/env bash
# Builds the schema twice in local Postgres: once with every migration except
# the one named in $1, once with all of them. Runs matrix.sql on both and
# prints every role/collection outcome that differs.
# Usage: diff_matrix.sh 20261105120000_insa_permission_hardening.sql
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
target="${1:?migration file name to compare}"
out="${MATRIX_OUT_DIR:-$(mktemp -d)}"
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"

build() {
  local db="$1" skip="$2"
  psql -q -X -v ON_ERROR_STOP=1 -d postgres -c "drop database if exists \"$db\";"
  psql -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database \"$db\";"
  psql -q -X -v ON_ERROR_STOP=1 -d "$db" -c "create extension if not exists pgcrypto;"
  psql -q -X -v ON_ERROR_STOP=1 -d "$db" -f "$here/00_supabase_stubs.sql"
  for f in "$root"/supabase/migrations/*.sql; do
    [[ -n "$skip" && "$(basename "$f")" == "$skip" ]] && continue
    sed -e 's/^create extension if not exists pg_net;//' "$f" \
      | psql -q -X -v ON_ERROR_STOP=1 -d "$db" -f - >/dev/null
  done
  psql -q -X -v ON_ERROR_STOP=1 -d "$db" -f "$here/matrix.sql" > "$out/$db.txt"
}

build mayabela_matrix_before "$target"
build mayabela_matrix_after ""

total=$(wc -l < "$out/mayabela_matrix_after.txt")
changed=$(diff "$out/mayabela_matrix_before.txt" "$out/mayabela_matrix_after.txt" | grep -c '^>' || true)
echo "Outcomes compared: $total. Changed by $target: $changed."
echo "(role | collection | action | before -> after)"
paste -d'\t' "$out/mayabela_matrix_before.txt" "$out/mayabela_matrix_after.txt" \
  | awk -F'\t' '$1 != $2 {
      n = split($1, a, " \\| "); split($2, b, " \\| ");
      printf "%s | %s | %s | %s -> %s\n", a[1], a[2], a[3], a[4], b[4]
    }'

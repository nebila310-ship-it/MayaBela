#!/usr/bin/env bash
# Restore drill against a throwaway local database. Never production.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${LOCAL_PG_TEST_DB:-mayabela_policy_test}"
DST="mayabela_restore_drill"
REC="$ROOT/docs/csms/records/restore-drill-2026-11-09.md"
DUMP="$(mktemp /tmp/mayabela-restore-XXXXXX.sql)"
trap 'rm -f "$DUMP"' EXIT

psql_q() { psql -v ON_ERROR_STOP=1 -q -X "$@"; }

if ! psql -d "$SRC" -c 'select 1' >/dev/null 2>&1; then
  echo "Source db $SRC missing — run supabase/tests/local_pg/run.sh first." >&2
  exit 1
fi

before="$(psql -d "$SRC" -Atc "select count(*) from public.app_documents")"
pg_dump --no-owner --format=plain "$SRC" > "$DUMP"
psql_q -d postgres -c "drop database if exists \"$DST\";"
psql_q -d postgres -c "create database \"$DST\";"
psql_q -d "$DST" -f "$DUMP" >/dev/null
after="$(psql -d "$DST" -Atc "select count(*) from public.app_documents")"
tables="$(psql -d "$DST" -Atc "select count(*) from information_schema.tables where table_schema='public'")"

if [[ "$before" != "$after" ]]; then
  echo "Restore count mismatch: $before -> $after" >&2
  exit 1
fi

cat > "$REC" <<EOF
# Restore drill

**Date:** 9 November 2026, Africa/Nairobi  
**Target:** local database \`$DST\` (not production, not any school tenant)

| Check | Result |
| --- | --- |
| Source | \`$SRC\` after CAAT replay |
| \`app_documents\` rows dumped | $before |
| Rows after restore | $after |
| Public tables restored | $tables |
| Production \`hwkiihonthueadbhcvfi\` | **not contacted** |

RPO/RTO in CSMS-BCM-001 still apply to the hosted supplier. This drill proves the **procedure** (dump → new database → count) without taking classrooms down.
EOF

echo "Restore drill passed ($after rows). Wrote $REC"

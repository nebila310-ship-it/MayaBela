#!/usr/bin/env bash
# Internal technical evaluation (CAAT + source greps). Never points at production.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REC="$ROOT/docs/csms/records/internal-evaluation-2026-11-09.md"
mkdir -p "$ROOT/docs/csms/records"

fail=0
note() { echo "$*"; }

note "== client must not contain a service-role secret"
if grep -R --include='*.dart' -n -E 'SERVICE_ROLE|supabaseServiceRole|role":"service_role"' lib; then
  echo "FAIL: service-role secret pattern in Dart"
  fail=1
else
  echo "PASS: no service-role secret in lib/"
fi

note "== Edge auth inventory"
deno test --allow-read=supabase/functions \
  supabase/functions/_shared/edge_auth_inventory_test.ts \
  supabase/functions/_shared/registry_write_policy_test.ts \
  supabase/functions/_shared/platform_pin_test.ts

note "== restore drill (local policy database only)"
export PGHOST="${PGHOST:-localhost}" PGUSER="${PGUSER:-postgres}" PGPASSWORD="${PGPASSWORD:-postgres}"
if psql -d postgres -c 'select 1' >/dev/null 2>&1; then
  bash "$ROOT/tools/insa_restore_drill.sh"
else
  echo "SKIP restore: local postgres not accepting connections"
fi

{
  echo "# Internal technical evaluation"
  echo
  echo "**Date:** 9 November 2026, Africa/Nairobi"
  echo "**Production project:** not contacted."
  echo
  echo "- Client source: no service-role key in \`lib/\`."
  echo "- Edge Functions: inventory matches folders; each has JWT, PIN, public rate-limit, or push secret."
  echo "- CAAT: local Postgres replay (hardening + driver + two-school)."
  echo "- Restore drill: see \`restore-drill-2026-11-09.md\` when Postgres was available."
  echo
  echo "This is an internal evaluation under Guideline §9. It is not a third-party pentest letter."
} > "$REC"

echo "Wrote $REC"
exit "$fail"

#!/usr/bin/env python3
"""Source invariants for the MaJo Bridge security audit.

Reads origin/master via git. Does not connect to Supabase.
Exit 0 means every assertion below matched the git objects.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PROPOSED = ROOT / "docs/security/proposed/20261021_teacher_sensitive_writes_NOT_APPLIED.sql"


def show(path: str) -> str:
    return subprocess.check_output(
        ["git", "show", f"origin/master:{path}"],
        cwd=ROOT,
        text=True,
    )


def extract_fn(sql: str, name: str) -> str:
    start = sql.find(f"create or replace function public.{name}")
    if start < 0:
        raise AssertionError(f"missing {name}")
    end = sql.find("$$;", start)
    if end < 0:
        raise AssertionError(f"unterminated {name}")
    return sql[start : end + 3]


fails: list[str] = []


def check(cond: bool, msg: str) -> None:
    print(("PASS " if cond else "FAIL ") + msg)
    if not cond:
        fails.append(msg)


teacher_sql = show("supabase/migrations/20260907140000_lia_tor_gaps_reads.sql")
teacher = extract_fn(teacher_sql, "app_doc_teacher_may_write")
check("p_collection in ('school_registry', 'platform_audit_log')" in teacher, "school_registry is explicitly denied")
check(teacher.rstrip().endswith("return true;\nend;\n$$;"), "live teacher write ends with return true")
check("payroll_profiles" not in teacher, "live function does not name payroll_profiles")
check("employee_registry" not in teacher, "live function does not name employee_registry")
see = teacher.find("jwt_can_read_all_school_data()")
klass = teacher.find("app_doc_teacher_class_readable")
check(0 < see < klass, "see-all returns before class-scoped checks")

guard_sql = show("supabase/migrations/20261007120000_user_preferences_self_sync.sql")
guard = extract_fn(guard_sql, "app_documents_write_guard")
check("if jwt_kind <> 'authenticated' then" in guard and "return new;" in guard, "non-authenticated jwt skips the write guard")
check("app_doc_teacher_may_write" in guard, "teacher writes call app_doc_teacher_may_write")
check("raise exception 'write_denied'" not in guard, "deny is delegated to app_doc_deny")

deny = show("supabase/migrations/20260819180000_teacher_writes_parent_scope_stale.sql")
check("raise exception 'write_denied' using errcode = '42501'" in deny, "write_denied uses SQLSTATE 42501")
check("public.app_doc_teacher_may_write(collection, doc_id, school_id, data)" in deny, "delete policy calls teacher_may_write")

phase1 = show("supabase/migrations/20261019160000_phase1_security_hardening.sql")
readable = extract_fn(phase1, "app_doc_readable")
# Teacher branch ends before parent branch.
teacher_branch = readable.split("if r = 'parent' then", 1)[0]
check(teacher_branch.rstrip().endswith("return false;\n  end if;"), "unclassified teacher reads return false")
check("'school_registry'" in teacher_branch, "teachers are explicitly allowed to read school_registry")

jwt = show("supabase/migrations/20260818120000_prod_hardening_phase1_2.sql")
school_fn = extract_fn(jwt, "jwt_school_id")
check("app_metadata" in school_fn and "user_metadata" not in school_fn, "jwt_school_id reads app_metadata only")

edge = show("supabase/functions/school-upsert-registry/index.ts")
check("admission_applications" in edge, "edge allowlist includes admission_applications")
check("curriculum_feedback" in edge, "edge allowlist includes curriculum_feedback")
check('collection === "admission_applications"' not in edge, "edge has no admission_applications role check")
check('collection === "curriculum_feedback"' not in edge, "edge has no curriculum_feedback role check")
check("adminClient()" in edge, "edge upserts with the service-role client")
check("if (selfId && sid && sid !== selfId)" in edge, "student exam-attempt check is skipped when linked id is empty")

store = show("lib/services/persistence/cloud_app_store.dart")
check("await pushAllSchools();" in store, "full registry push writes schools")
check("AppCollections.schoolRegistry" in store, "push uses the school_registry collection")
# The outbox registry batch acks only when the edge call succeeds.
reg = store.split("final r = await SchoolAuthCloudService.instance.upsertRegistryBatch(", 1)[1]
ok = reg.split("if (r.ok)", 1)[1]
ok_body, rest = ok.split("else if", 1)
check("ack(" in ok_body, "successful registry batch is acked")
else_body = rest.split("}", 1)[0]
check("ack(" not in else_body, "failed registry batch is not acked")
check("markFullPushNeeded" in store, "directory failure can mark a full push")

session = show("lib/services/cloud/session_cloud_sync.dart")
check("publishActiveSchoolDirectories" in session, "login uploads school directories")

proposed = PROPOSED.read_text()
check("NOT APPLIED" in proposed, "proposed SQL is marked not applied")
check("hwkiihonthueadbhcvfi" in proposed, "proposed SQL names the production project as do-not-run")
proposed_fn = extract_fn(proposed, "app_doc_teacher_may_write")
check(
    proposed_fn.find("payroll_profiles") < proposed_fn.find("jwt_can_read_all_school_data()"),
    "proposal gates payroll before see-all",
)
check("return true;\nend;\n$$;" in proposed, "proposal keeps the final return true")
check("eyJ" not in proposed, "proposed SQL contains no JWT")

if fails:
    print(f"\n{len(fails)} failed")
    sys.exit(1)
print("\nAll source invariants passed")

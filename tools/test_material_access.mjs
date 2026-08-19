// Verifies paid-material entitlements are tamper-proof:
// - parents/students cannot create, modify, or delete material_access grants
// - teachers can grant and revoke
// Uses a synthetic school + temp accounts, cleans up afterwards.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const envText = readFileSync(resolve(process.cwd(), ".env.local"), "utf8");
const env = {};
for (const line of envText.split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+)\s*$/);
  if (m) env[m[1]] = m[2];
}
const URL_BASE = env.SUPABASE_URL;
const ANON = env.SUPABASE_ANON_KEY;
const SERVICE = env.SUPABASE_SERVICE_ROLE_KEY;

const SCHOOL = "e2e_matacc_school";
const PARENT = "e2e_matacc_parent";
const TEACHER = "e2e_matacc_teacher";
const PASS = "matacctest123";
const GRANT_ID = "lm-900__E2E-STU-1";

async function svc(path, opts = {}) {
  const res = await fetch(`${URL_BASE}${path}`, {
    ...opts,
    headers: {
      apikey: SERVICE,
      Authorization: `Bearer ${SERVICE}`,
      "Content-Type": "application/json",
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  return { status: res.status, body };
}

async function asUser(token, path, opts = {}) {
  const res = await fetch(`${URL_BASE}${path}`, {
    ...opts,
    headers: {
      apikey: ANON,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  return { status: res.status, body };
}

async function login(username, roleKey) {
  const res = await fetch(`${URL_BASE}/functions/v1/school-login`, {
    method: "POST",
    headers: { apikey: ANON, Authorization: `Bearer ${ANON}`, "Content-Type": "application/json" },
    body: JSON.stringify({ username, password: PASS, roleKey }),
  });
  const body = await res.json();
  return { status: res.status, token: body.access_token };
}

async function cleanup() {
  await svc(`/rest/v1/app_documents?school_id=eq.${SCHOOL}`, { method: "DELETE" });
  for (const u of [PARENT, TEACHER]) {
    await svc(`/rest/v1/app_documents?collection=eq.auth_secrets&doc_id=eq.${u}`, { method: "DELETE" });
    await svc(`/rest/v1/auth_rate_limits?bucket_key=like.login_${u}_*`, { method: "DELETE" });
  }
  const users = await svc(`/auth/v1/admin/users?page=1&per_page=1000`);
  for (const u of users.body?.users || []) {
    if (u.email?.startsWith(`${PARENT}@`) || u.email?.startsWith(`${TEACHER}@`)) {
      await svc(`/auth/v1/admin/users/${u.id}`, { method: "DELETE" });
    }
  }
}

function doc(collection, doc_id, data) {
  return {
    collection,
    doc_id,
    school_id: SCHOOL,
    data: { ...data, schoolId: SCHOOL },
    updated_at: new Date().toISOString(),
  };
}

let failures = 0;
function check(name, ok, detail = "") {
  console.log(`${ok ? "PASS" : "FAIL"} - ${name}${detail ? ` (${detail})` : ""}`);
  if (!ok) failures++;
}

async function main() {
  await cleanup();

  // Seed accounts + one paid material.
  await svc(`/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify([
      doc("app_auth_accounts", PARENT, { username: PARENT, roleKey: "parent", fullName: "MatAcc Parent", password: PASS }),
      doc("app_auth_accounts", TEACHER, { username: TEACHER, roleKey: "teacher", fullName: "MatAcc Teacher", password: PASS }),
      doc("learning_materials", "lm-900", {
        id: "lm-900", className: "Grade 1 A", subject: "Math",
        bookName: "Paid Book", materialName: "Unit 1", filePath: "x",
        teacherId: "T-1", teacherName: "T", postedAt: new Date().toISOString(),
        isFree: false, price: 150,
      }),
    ]),
  });

  const parent = await login(PARENT, "parent");
  const teacher = await login(TEACHER, "teacher");
  check("parent login", !!parent.token, `status ${parent.status}`);
  check("teacher login", !!teacher.token, `status ${teacher.status}`);
  if (!parent.token || !teacher.token) { await cleanup(); process.exit(1); }

  // 1. Parent tries to grant themselves access — must be silently skipped.
  await asUser(parent.token, `/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(doc("material_access", GRANT_ID, {
      materialId: "lm-900", studentId: "E2E-STU-1", grantedBy: "hacker",
    })),
  });
  let rows = await svc(`/rest/v1/app_documents?collection=eq.material_access&doc_id=eq.${GRANT_ID}&select=doc_id`);
  check("parent self-grant blocked", (rows.body?.length ?? 0) === 0);

  // 2. Teacher grants access — must persist.
  const grant = await asUser(teacher.token, `/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(doc("material_access", GRANT_ID, {
      materialId: "lm-900", studentId: "E2E-STU-1", grantedBy: TEACHER,
    })),
  });
  rows = await svc(`/rest/v1/app_documents?collection=eq.material_access&doc_id=eq.${GRANT_ID}&select=data`);
  check("teacher grant persists", rows.body?.length === 1, `write status ${grant.status}`);

  // 3. Parent tries to delete another student's grant — RLS delete policy
  //    limits deletes to admin/teacher.
  await asUser(parent.token, `/rest/v1/app_documents?collection=eq.material_access&doc_id=eq.${GRANT_ID}`, {
    method: "DELETE",
  });
  rows = await svc(`/rest/v1/app_documents?collection=eq.material_access&doc_id=eq.${GRANT_ID}&select=doc_id`);
  check("parent delete blocked", rows.body?.length === 1);

  // 4. Parent tries to tamper the material itself (flip isFree) — skipped.
  await asUser(parent.token, `/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(doc("learning_materials", "lm-900", {
      id: "lm-900", isFree: true,
    })),
  });
  rows = await svc(`/rest/v1/app_documents?collection=eq.learning_materials&doc_id=eq.lm-900&select=data`);
  check("parent cannot flip material to free", rows.body?.[0]?.data?.isFree === false);

  // 5. Teacher revokes — delete must work.
  await asUser(teacher.token, `/rest/v1/app_documents?collection=eq.material_access&doc_id=eq.${GRANT_ID}`, {
    method: "DELETE",
  });
  rows = await svc(`/rest/v1/app_documents?collection=eq.material_access&doc_id=eq.${GRANT_ID}&select=doc_id`);
  check("teacher revoke works", (rows.body?.length ?? 0) === 0);

  await cleanup();
  console.log(failures === 0 ? "\nRESULT: ALL PASS" : `\nRESULT: ${failures} FAILURE(S)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

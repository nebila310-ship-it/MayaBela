// Verifies the write-guard + RLS behavior with a real authenticated session.
// Creates a temp parent account in a synthetic school, logs in through
// school-login, then checks reads, allowed writes, denied writes, and the
// admin-account escalation path. Cleans up afterwards.
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

const SCHOOL = "e2e_guard_school";
const USER = "e2e_guard_parent";
const PASS = "guardtest123";

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
  return { status: res.status, body: text ? JSON.parse(text) : null };
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

async function cleanup() {
  await svc(`/rest/v1/app_documents?school_id=eq.${SCHOOL}`, { method: "DELETE" });
  await svc(`/rest/v1/app_documents?collection=eq.auth_secrets&doc_id=eq.${USER}`, { method: "DELETE" });
  await svc(`/rest/v1/auth_rate_limits?bucket_key=eq.login_${USER}_parent`, { method: "DELETE" });
  const users = await svc(`/auth/v1/admin/users?page=1&per_page=1000`);
  for (const u of users.body?.users || []) {
    if (u.email?.startsWith(`${USER}@`)) {
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

  // Seed: parent account + one grade report in the synthetic school.
  await svc(`/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify([
      doc("app_auth_accounts", USER, { username: USER, roleKey: "parent", fullName: "Guard Test", password: PASS }),
      doc("grade_reports", "e2e_grade_1", { studentName: "X", score: 90 }),
    ]),
  });

  const login = await fetch(`${URL_BASE}/functions/v1/school-login`, {
    method: "POST",
    headers: { apikey: ANON, Authorization: `Bearer ${ANON}`, "Content-Type": "application/json" },
    body: JSON.stringify({ username: USER, password: PASS, roleKey: "parent" }),
  });
  const loginBody = await login.json();
  check("parent login", login.status === 200 && !!loginBody.access_token, `status ${login.status}`);
  if (!loginBody.access_token) { await cleanup(); process.exit(1); }
  const token = loginBody.access_token;

  // 1. Read own-school data.
  const read = await asUser(token, `/rest/v1/app_documents?collection=eq.grade_reports&select=doc_id,data`);
  check("parent can read school grade_reports", read.status === 200 && read.body?.length === 1);

  // 2. Forbidden write: modify a grade. Must be silently skipped.
  await asUser(token, `/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(doc("grade_reports", "e2e_grade_1", { studentName: "X", score: 100, hacked: true })),
  });
  const gradeAfter = await svc(`/rest/v1/app_documents?collection=eq.grade_reports&doc_id=eq.e2e_grade_1&select=data`);
  check(
    "grade tampering silently skipped",
    gradeAfter.body?.[0]?.data?.score === 90 && !gradeAfter.body?.[0]?.data?.hacked,
    `score=${gradeAfter.body?.[0]?.data?.score}`,
  );

  // 3. Allowed write: conversations.
  const convWrite = await asUser(token, `/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(doc("conversations", "e2e_conv_1", { name: "test", messages: [] })),
  });
  const convAfter = await svc(`/rest/v1/app_documents?collection=eq.conversations&doc_id=eq.e2e_conv_1&select=doc_id`);
  check("parent conversation write persists", convAfter.body?.length === 1, `write status ${convWrite.status}`);

  // 4. Escalation attempt: create an admin account doc with a known password.
  await asUser(token, `/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(doc("app_auth_accounts", "e2e_fake_admin", {
      username: "e2e_fake_admin", roleKey: "admin", password: "ownedbyme1",
    })),
  });
  const fakeAdmin = await svc(`/rest/v1/app_documents?collection=eq.app_auth_accounts&doc_id=eq.e2e_fake_admin&select=doc_id`);
  check("admin account escalation blocked", (fakeAdmin.body?.length ?? 0) === 0);

  // 5. Parent may update own account doc, but role stays immutable and
  //    password fields are stripped.
  await asUser(token, `/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(doc("app_auth_accounts", USER, {
      username: USER, roleKey: "parent", fullName: "Renamed Guard Test", password: "plantedpw1",
    })),
  });
  const own = await svc(`/rest/v1/app_documents?collection=eq.app_auth_accounts&doc_id=eq.${USER}&select=data`);
  const ownData = own.body?.[0]?.data || {};
  check(
    "own profile update ok, password stripped",
    ownData.fullName === "Renamed Guard Test" && !("password" in ownData),
    `fullName=${ownData.fullName} hasPassword=${"password" in ownData}`,
  );

  // 6. Sanity: no null school_id rows remain (auth_secrets is server-only
  //    and intentionally school-less).
  const nulls = await svc(`/rest/v1/app_documents?school_id=is.null&collection=neq.auth_secrets&select=doc_id`);
  check("no null school_id rows remain", (nulls.body?.length ?? 0) === 0, `count=${nulls.body?.length}`);

  await cleanup();
  console.log(failures === 0 ? "\nRESULT: ALL PASS" : `\nRESULT: ${failures} FAILURE(S)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

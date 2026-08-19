// Transfer workflow (Phase D) end-to-end test.
//
// Verifies write-guard v5 against the live Supabase project:
//  1. registrar can create transfer_requests; forced to pending
//  2. academic admin can approve internal; approver stamped server-side
//  3. registrar cannot approve their own (self-approval off)
//  4. external transfers require school owner
//  5. forward-only status (approved cannot go back to pending)
//  6. plain teacher denied
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

const SCHOOL = "e2e_xfer_school";
const ADMIN = "e2e_xfer_admin";
const REG = "e2e_xfer_reg";
const ACAD = "e2e_xfer_acad";
const PLAIN = "e2e_xfer_plain";
const PASS = "xfertest1234";

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
  return { status: res.status, body: await res.json() };
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

function account(username, roleKey, staffRoles = []) {
  return doc("app_auth_accounts", username, {
    username, roleKey, fullName: `Xfer ${username}`, password: PASS,
    ...(staffRoles.length ? { staffRoles } : {}),
  });
}

function transfer(id, requestedBy, status = "pending", extra = {}) {
  return doc("transfer_requests", id, {
    id,
    kind: "internal",
    studentId: "STU-X1",
    studentName: "Test Student",
    fromGrade: "Grade 5",
    fromClassName: "Grade 5A",
    fromCampus: "Main Campus",
    toGrade: "Grade 5",
    toClassName: "Grade 5B",
    toCampus: "Main Campus",
    internalTarget: "section",
    reason: "E2E",
    requestedBy,
    requestedByName: requestedBy,
    createdAt: new Date().toISOString(),
    status,
    ...extra,
  });
}

async function upsertAs(token, docBody) {
  return asUser(token, `/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(docBody),
  });
}

async function readDocSvc(collection, docId) {
  const res = await svc(`/rest/v1/app_documents?collection=eq.${collection}&doc_id=eq.${docId}&select=data`);
  return res.body?.[0]?.data ?? null;
}

async function cleanup() {
  await svc(`/rest/v1/app_documents?school_id=eq.${SCHOOL}`, { method: "DELETE" });
  for (const u of [ADMIN, REG, ACAD, PLAIN]) {
    await svc(`/rest/v1/app_documents?collection=eq.auth_secrets&doc_id=eq.${u}`, { method: "DELETE" });
    await svc(`/rest/v1/auth_rate_limits?bucket_key=like.login_${u}_*`, { method: "DELETE" });
  }
  const users = await svc(`/auth/v1/admin/users?page=1&per_page=1000`);
  for (const u of users.body?.users || []) {
    if (u.email?.includes("e2e-xfer-school") || u.email?.startsWith("e2e_xfer_")) {
      await svc(`/auth/v1/admin/users/${u.id}`, { method: "DELETE" });
    }
  }
}

let failures = 0;
function check(name, ok, detail = "") {
  console.log(`${ok ? "PASS" : "FAIL"} - ${name}${detail ? ` (${detail})` : ""}`);
  if (!ok) failures++;
}

async function main() {
  await cleanup();

  await svc(`/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify([
      doc("school_registry", SCHOOL, {
        id: SCHOOL, name: "Xfer Test School", status: "active",
        settings: { allowSelfApproval: false },
      }),
      account(ADMIN, "admin"),
      account(REG, "teacher", ["registrar"]),
      account(ACAD, "teacher", ["academic_admin"]),
      account(PLAIN, "teacher"),
    ]),
  });

  const regToken = (await login(REG, "teacher")).body.access_token;
  const acadToken = (await login(ACAD, "teacher")).body.access_token;
  const adminToken = (await login(ADMIN, "admin")).body.access_token;
  const plainToken = (await login(PLAIN, "teacher")).body.access_token;
  if (!regToken || !acadToken || !adminToken || !plainToken) {
    console.error("login failed");
    await cleanup();
    process.exit(1);
  }

  await upsertAs(regToken, transfer("e2e_tr_1", REG));
  check("registrar can create transfer request", !!(await readDocSvc("transfer_requests", "e2e_tr_1")));

  await upsertAs(regToken, transfer("e2e_tr_pre", REG, "approved"));
  const pre = await readDocSvc("transfer_requests", "e2e_tr_pre");
  check("new docs forced to pending", pre?.status === "pending", `status=${pre?.status}`);

  await upsertAs(plainToken, transfer("e2e_tr_hack", PLAIN));
  check("plain teacher denied", !(await readDocSvc("transfer_requests", "e2e_tr_hack")));

  await upsertAs(regToken, transfer("e2e_tr_1", REG, "approved"));
  let tr1 = await readDocSvc("transfer_requests", "e2e_tr_1");
  check("registrar cannot approve (no approve_transfers)", tr1?.status === "pending", `status=${tr1?.status}`);

  await upsertAs(acadToken, transfer("e2e_tr_1", REG, "approved", { approvedBy: "forged" }));
  tr1 = await readDocSvc("transfer_requests", "e2e_tr_1");
  check("academic admin can approve internal", tr1?.status === "approved", `status=${tr1?.status}`);
  check("approver stamped server-side", tr1?.approvedBy === ACAD, `approvedBy=${tr1?.approvedBy}`);

  await upsertAs(adminToken, transfer("e2e_tr_1", REG, "pending"));
  tr1 = await readDocSvc("transfer_requests", "e2e_tr_1");
  check("approved cannot move back to pending", tr1?.status === "approved", `status=${tr1?.status}`);

  // External: only owner
  await upsertAs(regToken, transfer("e2e_tr_ext", REG, "pending", {
    kind: "external", externalOutcome: "transferred",
  }));
  await upsertAs(acadToken, transfer("e2e_tr_ext", REG, "approved", {
    kind: "external", externalOutcome: "transferred",
  }));
  let ext = await readDocSvc("transfer_requests", "e2e_tr_ext");
  check("academic cannot approve external", ext?.status === "pending", `status=${ext?.status}`);

  await upsertAs(adminToken, transfer("e2e_tr_ext", REG, "approved", {
    kind: "external", externalOutcome: "transferred",
  }));
  ext = await readDocSvc("transfer_requests", "e2e_tr_ext");
  check("owner can approve external", ext?.status === "approved", `status=${ext?.status}`);

  await cleanup();
  console.log(failures === 0 ? "\nRESULT: ALL PASS" : `\nRESULT: ${failures} FAILURE(S)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

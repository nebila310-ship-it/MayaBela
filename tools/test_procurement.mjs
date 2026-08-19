// Procurement workflow (Phase C) end-to-end test.
//
// Verifies the write-guard v4 against the live Supabase project:
//  1. procurement staff can create purchase requests; new docs from
//     non-owners are forced to status "pending" (no pre-approved inserts)
//  2. approval requires approve_purchase_requests (creator cannot approve)
//  3. the approver identity is stamped server-side
//  4. self-approval is blocked until the school enables allowSelfApproval
//  5. requests never move backwards (approved -> pending is skipped, even
//     for the owner) — protects against stale sync echoes / replays
//  6. fulfilment (approved -> received/issued) requires the store
//     permission and cannot skip the approval step
//  7. issue requests follow the same chain with their own permissions
//
// Creates everything in a synthetic school and cleans up afterwards.
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

const SCHOOL = "e2e_proc_school";
const ADMIN = "e2e_proc_admin";
const PROC = "e2e_proc_officer";
const STORE = "e2e_proc_store";
const VP = "e2e_proc_vp";
const MULTI = "e2e_proc_multi"; // procurement + vice_president (create+approve)
const PASS = "proctest1234";

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
  return { status: res.status, body };
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
    username, roleKey, fullName: `Proc ${username}`, password: PASS,
    ...(staffRoles.length ? { staffRoles } : {}),
  });
}

function purchase(id, requestedBy, status = "pending", extra = {}) {
  return doc("purchase_requests", id, {
    id,
    lines: [{ name: "Chalk Box", quantity: 10, unit: "box", estimatedUnitPrice: 45 }],
    reason: "E2E test",
    requestedBy,
    requestedByName: requestedBy,
    createdAt: new Date().toISOString(),
    status,
    ...extra,
  });
}

function issue(id, requestedBy, status = "pending", extra = {}) {
  return doc("issue_requests", id, {
    id,
    itemId: "inv-1",
    itemName: "Chalk Box",
    quantity: 3,
    purpose: "E2E test",
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

async function setSchool(settings) {
  await svc(`/rest/v1/app_documents?collection=eq.school_registry&doc_id=eq.${SCHOOL}`, {
    method: "PATCH",
    body: JSON.stringify({
      data: {
        id: SCHOOL, name: "Proc Test School", status: "active",
        settings, schoolId: SCHOOL,
      },
    }),
  });
}

async function cleanup() {
  await svc(`/rest/v1/app_documents?school_id=eq.${SCHOOL}`, { method: "DELETE" });
  for (const u of [ADMIN, PROC, STORE, VP, MULTI]) {
    await svc(`/rest/v1/app_documents?collection=eq.auth_secrets&doc_id=eq.${u}`, { method: "DELETE" });
    await svc(`/rest/v1/auth_rate_limits?bucket_key=like.login_${u}_*`, { method: "DELETE" });
  }
  const users = await svc(`/auth/v1/admin/users?page=1&per_page=1000`);
  for (const u of users.body?.users || []) {
    if (u.email?.includes("e2e-proc-school") || u.email?.startsWith("e2e_proc_")) {
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
        id: SCHOOL, name: "Proc Test School", status: "active",
        settings: { allowSelfApproval: false },
      }),
      account(ADMIN, "admin"),
      account(PROC, "teacher", ["procurement"]),
      account(STORE, "teacher", ["storekeeper"]),
      account(VP, "teacher", ["vice_president"]),
      account(MULTI, "teacher", ["procurement", "vice_president"]),
    ]),
  });

  const procToken = (await login(PROC, "teacher")).body.access_token;
  const storeToken = (await login(STORE, "teacher")).body.access_token;
  const vpToken = (await login(VP, "teacher")).body.access_token;
  const multiToken = (await login(MULTI, "teacher")).body.access_token;
  const adminToken = (await login(ADMIN, "admin")).body.access_token;
  if (!procToken || !storeToken || !vpToken || !multiToken || !adminToken) {
    console.error("login failed for a test account");
    await cleanup();
    process.exit(1);
  }

  // --- 1. Creation + forced pending status ---
  await upsertAs(procToken, purchase("e2e_pr_1", PROC));
  check("procurement can create purchase request", !!(await readDocSvc("purchase_requests", "e2e_pr_1")));

  await upsertAs(procToken, purchase("e2e_pr_preapproved", PROC, "approved", { approvedBy: VP }));
  const preApproved = await readDocSvc("purchase_requests", "e2e_pr_preapproved");
  check(
    "new docs are forced to pending (no pre-approved inserts)",
    preApproved?.status === "pending",
    `status=${preApproved?.status}`,
  );

  // --- 2. Approval permission ---
  await upsertAs(procToken, purchase("e2e_pr_1", PROC, "approved"));
  let pr1 = await readDocSvc("purchase_requests", "e2e_pr_1");
  check(
    "creator without approve permission cannot approve",
    pr1?.status === "pending",
    `status=${pr1?.status}`,
  );

  // --- 3. VP approves + server-stamped approver ---
  await upsertAs(vpToken, purchase("e2e_pr_1", PROC, "approved", { approvedBy: "forged_user" }));
  pr1 = await readDocSvc("purchase_requests", "e2e_pr_1");
  check("VP can approve", pr1?.status === "approved", `status=${pr1?.status}`);
  check(
    "approver identity is stamped server-side",
    pr1?.approvedBy === VP,
    `approvedBy=${pr1?.approvedBy}`,
  );

  // --- 4. Self-approval setting ---
  await upsertAs(multiToken, purchase("e2e_pr_self", MULTI));
  await upsertAs(multiToken, purchase("e2e_pr_self", MULTI, "approved"));
  let prSelf = await readDocSvc("purchase_requests", "e2e_pr_self");
  check(
    "self-approval blocked while setting is off",
    prSelf?.status === "pending",
    `status=${prSelf?.status}`,
  );

  await setSchool({ allowSelfApproval: true });
  await upsertAs(multiToken, purchase("e2e_pr_self", MULTI, "approved"));
  prSelf = await readDocSvc("purchase_requests", "e2e_pr_self");
  check(
    "self-approval allowed once the owner enables it",
    prSelf?.status === "approved",
    `status=${prSelf?.status}`,
  );
  await setSchool({ allowSelfApproval: false });

  // --- 5. Forward-only transitions ---
  await upsertAs(adminToken, purchase("e2e_pr_1", PROC, "pending"));
  pr1 = await readDocSvc("purchase_requests", "e2e_pr_1");
  check(
    "approved request cannot move back to pending (even for owner)",
    pr1?.status === "approved",
    `status=${pr1?.status}`,
  );

  // --- 6. Fulfilment rules ---
  await upsertAs(vpToken, purchase("e2e_pr_1", PROC, "received", { approvedBy: VP }));
  pr1 = await readDocSvc("purchase_requests", "e2e_pr_1");
  check(
    "VP (no receive_stock) cannot mark received",
    pr1?.status === "approved",
    `status=${pr1?.status}`,
  );

  await upsertAs(storeToken, purchase("e2e_pr_1", PROC, "received", { approvedBy: VP, receivedBy: STORE }));
  pr1 = await readDocSvc("purchase_requests", "e2e_pr_1");
  check(
    "storekeeper can mark approved request received",
    pr1?.status === "received",
    `status=${pr1?.status}`,
  );

  await upsertAs(storeToken, purchase("e2e_pr_skip", PROC));
  await upsertAs(storeToken, purchase("e2e_pr_skip", PROC, "received"));
  let prSkip = await readDocSvc("purchase_requests", "e2e_pr_skip");
  check(
    "fulfilment cannot skip approval (pending -> received blocked)",
    prSkip?.status === "pending",
    `status=${prSkip?.status}`,
  );

  // Rejected requests stay rejected: no flip to approved, no fulfilment.
  await upsertAs(vpToken, purchase("e2e_pr_skip", PROC, "rejected", { rejectionReason: "No budget" }));
  await upsertAs(vpToken, purchase("e2e_pr_skip", PROC, "approved"));
  prSkip = await readDocSvc("purchase_requests", "e2e_pr_skip");
  check(
    "rejected request cannot be flipped to approved",
    prSkip?.status === "rejected",
    `status=${prSkip?.status}`,
  );
  await upsertAs(storeToken, purchase("e2e_pr_skip", PROC, "received"));
  prSkip = await readDocSvc("purchase_requests", "e2e_pr_skip");
  check(
    "rejected request cannot be fulfilled",
    prSkip?.status === "rejected",
    `status=${prSkip?.status}`,
  );

  // --- 7. Issue request chain ---
  await upsertAs(storeToken, issue("e2e_ir_1", STORE));
  check("storekeeper can create issue request", !!(await readDocSvc("issue_requests", "e2e_ir_1")));

  await upsertAs(storeToken, issue("e2e_ir_1", STORE, "approved"));
  let ir1 = await readDocSvc("issue_requests", "e2e_ir_1");
  check(
    "storekeeper (no approve_issue_requests) cannot approve",
    ir1?.status === "pending",
    `status=${ir1?.status}`,
  );

  await upsertAs(procToken, issue("e2e_ir_1", STORE, "approved"));
  ir1 = await readDocSvc("issue_requests", "e2e_ir_1");
  check("procurement can approve issue request", ir1?.status === "approved", `status=${ir1?.status}`);
  check("issue approver stamped server-side", ir1?.approvedBy === PROC, `approvedBy=${ir1?.approvedBy}`);

  await upsertAs(procToken, issue("e2e_ir_1", STORE, "issued", { approvedBy: PROC }));
  ir1 = await readDocSvc("issue_requests", "e2e_ir_1");
  check(
    "procurement (no issue_stock) cannot mark issued",
    ir1?.status === "approved",
    `status=${ir1?.status}`,
  );

  await upsertAs(storeToken, issue("e2e_ir_1", STORE, "issued", { approvedBy: PROC, issuedBy: STORE }));
  ir1 = await readDocSvc("issue_requests", "e2e_ir_1");
  check("storekeeper can fulfil approved issue request", ir1?.status === "issued", `status=${ir1?.status}`);

  await cleanup();
  console.log(failures === 0 ? "\nRESULT: ALL PASS" : `\nRESULT: ${failures} FAILURE(S)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

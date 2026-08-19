// RBAC Phase A end-to-end test.
//
// Verifies against the live Supabase project:
//  1. school-login stamps staffRoles / permissions / claimsVersion into JWT
//  2. multi-role users get the union of their templates
//  3. permission-gated collections (issue_requests, buses) allow/deny writes
//  4. role grants require assign_roles; HR cannot grant, owner can
//  5. Full Access is owner-grantable only; self-role-edit is stripped
//  6. claimsVersion bump revokes stale JWTs for gated writes
//  7. school_audit_log is insert-only (no update, no delete)
//  8. inactive schools cannot sign in (school_blocked)
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

const SCHOOL = "e2e_rbac_school";
const ADMIN = "e2e_rbac_admin";
const HR = "e2e_rbac_hr";
const STORE = "e2e_rbac_store";
const PLAIN = "e2e_rbac_plain";
const PASS = "rbactest1234";

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

function jwtClaims(token) {
  const payload = token.split(".")[1];
  const json = Buffer.from(payload.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8");
  return JSON.parse(json).app_metadata || {};
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
    username, roleKey, fullName: `RBAC ${username}`, password: PASS,
    ...(staffRoles.length ? { staffRoles } : {}),
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
  for (const u of [ADMIN, HR, STORE, PLAIN]) {
    await svc(`/rest/v1/app_documents?collection=eq.auth_secrets&doc_id=eq.${u}`, { method: "DELETE" });
    await svc(`/rest/v1/auth_rate_limits?bucket_key=like.login_${u}_*`, { method: "DELETE" });
  }
  const users = await svc(`/auth/v1/admin/users?page=1&per_page=1000`);
  for (const u of users.body?.users || []) {
    if (u.email?.includes("e2e-rbac-school") || u.email?.startsWith("e2e_rbac_")) {
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

  // Seed: active school + owner + HR + multi-role store staff + plain teacher.
  await svc(`/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify([
      doc("school_registry", SCHOOL, { id: SCHOOL, name: "RBAC Test School", status: "active" }),
      account(ADMIN, "admin"),
      account(HR, "teacher", ["hr_admin"]),
      account(STORE, "teacher", ["procurement", "storekeeper"]),
      account(PLAIN, "teacher"),
    ]),
  });

  // --- 1+2. Claims for a multi-role staff member ---
  const storeLogin = await login(STORE, "teacher");
  check("multi-role staff login", storeLogin.status === 200 && !!storeLogin.body.access_token, `status ${storeLogin.status}`);
  if (!storeLogin.body.access_token) { await cleanup(); process.exit(1); }
  const storeToken = storeLogin.body.access_token;
  const claims = jwtClaims(storeToken);
  check(
    "JWT carries staffRoles",
    Array.isArray(claims.staffRoles) &&
      claims.staffRoles.includes("procurement") &&
      claims.staffRoles.includes("storekeeper"),
    JSON.stringify(claims.staffRoles),
  );
  check(
    "JWT permissions are the union of both roles",
    Array.isArray(claims.permissions) &&
      claims.permissions.includes("create_purchase_requests") &&
      claims.permissions.includes("issue_stock") &&
      !claims.permissions.includes("manage_staff_accounts"),
    `count=${claims.permissions?.length}`,
  );
  check("JWT carries claimsVersion", claims.claimsVersion === 0, `v=${claims.claimsVersion}`);
  check(
    "login response profile includes staffRoles",
    Array.isArray(storeLogin.body.profile?.staffRoles) &&
      storeLogin.body.profile.staffRoles.length === 2,
  );

  // --- 3. Gated collections ---
  await upsertAs(storeToken, doc("issue_requests", "e2e_issue_1", { item: "Notebooks", qty: 50, status: "PENDING" }));
  check("storekeeper can create issue_requests", !!(await readDocSvc("issue_requests", "e2e_issue_1")));

  const plainLogin = await login(PLAIN, "teacher");
  const plainToken = plainLogin.body.access_token;
  await upsertAs(plainToken, doc("issue_requests", "e2e_issue_hack", { item: "TVs", qty: 9 }));
  check("plain teacher denied on issue_requests", !(await readDocSvc("issue_requests", "e2e_issue_hack")));

  await upsertAs(plainToken, doc("buses", "e2e_bus_hack", { busNumber: "X" }));
  check("plain teacher denied on buses", !(await readDocSvc("buses", "e2e_bus_hack")));

  const adminLogin = await login(ADMIN, "admin");
  const adminToken = adminLogin.body.access_token;
  await upsertAs(adminToken, doc("buses", "e2e_bus_1", { busNumber: "B-01", capacity: 40 }));
  check("owner can create buses", !!(await readDocSvc("buses", "e2e_bus_1")));

  // --- 4. Role grants: HR (manage_staff_accounts, no assign_roles) ---
  const hrLogin = await login(HR, "teacher");
  const hrToken = hrLogin.body.access_token;
  await upsertAs(hrToken, account(PLAIN, "teacher", ["finance"]));
  const afterHrGrant = await readDocSvc("app_auth_accounts", PLAIN);
  check(
    "HR account update allowed but role grant stripped",
    afterHrGrant && (afterHrGrant.staffRoles ?? []).length === 0,
    JSON.stringify(afterHrGrant?.staffRoles),
  );

  // Owner grants finance to the plain teacher: persists + claimsVersion bump.
  await upsertAs(adminToken, account(PLAIN, "teacher", ["finance"]));
  const afterOwnerGrant = await readDocSvc("app_auth_accounts", PLAIN);
  check(
    "owner grant persists with claimsVersion bump",
    JSON.stringify(afterOwnerGrant?.staffRoles) === '["finance"]' && afterOwnerGrant?.claimsVersion === 1,
    `roles=${JSON.stringify(afterOwnerGrant?.staffRoles)} v=${afterOwnerGrant?.claimsVersion}`,
  );

  // --- 5. Full Access rules ---
  await upsertAs(hrToken, account(STORE, "teacher", ["procurement", "storekeeper", "full_access"]));
  const hrFullAccess = await readDocSvc("app_auth_accounts", STORE);
  check(
    "HR cannot grant Full Access",
    !(hrFullAccess?.staffRoles ?? []).includes("full_access"),
    JSON.stringify(hrFullAccess?.staffRoles),
  );

  await upsertAs(adminToken, account(HR, "teacher", ["hr_admin", "full_access"]));
  const ownerFullAccess = await readDocSvc("app_auth_accounts", HR);
  check(
    "owner can grant Full Access",
    (ownerFullAccess?.staffRoles ?? []).includes("full_access"),
    JSON.stringify(ownerFullAccess?.staffRoles),
  );

  // Self-edit: admin tries to give itself staff roles — stripped.
  await upsertAs(adminToken, account(ADMIN, "admin", ["full_access"]));
  const selfEdit = await readDocSvc("app_auth_accounts", ADMIN);
  check(
    "self role-edit is stripped even for owner",
    (selfEdit?.staffRoles ?? []).length === 0,
    JSON.stringify(selfEdit?.staffRoles),
  );

  // --- 6. Stale-JWT revocation ---
  // Owner changes the store user's roles (bump to v1). The store user's
  // original token still claims v0 + old permissions → gated writes denied.
  await upsertAs(adminToken, account(STORE, "teacher", ["finance"]));
  const storeAfter = await readDocSvc("app_auth_accounts", STORE);
  check("store roles changed by owner", storeAfter?.claimsVersion >= 1, `v=${storeAfter?.claimsVersion}`);
  await upsertAs(storeToken, doc("issue_requests", "e2e_issue_stale", { item: "Pens", qty: 5 }));
  check(
    "stale JWT loses gated write access after role change",
    !(await readDocSvc("issue_requests", "e2e_issue_stale")),
  );

  // --- 7. Audit log immutability ---
  await upsertAs(adminToken, doc("school_audit_log", "e2e_audit_1", {
    actor: ADMIN, role: "admin", action: "test_action", at: new Date().toISOString(),
  }));
  check("audit insert works", !!(await readDocSvc("school_audit_log", "e2e_audit_1")));

  await upsertAs(adminToken, doc("school_audit_log", "e2e_audit_1", {
    actor: ADMIN, role: "admin", action: "TAMPERED", at: new Date().toISOString(),
  }));
  const auditAfterUpdate = await readDocSvc("school_audit_log", "e2e_audit_1");
  check("audit update blocked (append-only)", auditAfterUpdate?.action === "test_action", auditAfterUpdate?.action);

  await asUser(adminToken, `/rest/v1/app_documents?collection=eq.school_audit_log&doc_id=eq.e2e_audit_1`, { method: "DELETE" });
  check("audit delete blocked", !!(await readDocSvc("school_audit_log", "e2e_audit_1")));

  // --- 8. Inactive school cannot sign in ---
  await svc(`/rest/v1/app_documents?collection=eq.school_registry&doc_id=eq.${SCHOOL}`, {
    method: "PATCH",
    body: JSON.stringify({ data: { id: SCHOOL, name: "RBAC Test School", status: "inactive", schoolId: SCHOOL } }),
  });
  const blockedLogin = await login(PLAIN, "teacher");
  check(
    "inactive school blocks login",
    blockedLogin.status === 403 && blockedLogin.body?.code === "school_blocked",
    `status ${blockedLogin.status} code=${blockedLogin.body?.code}`,
  );

  await cleanup();
  console.log(failures === 0 ? "\nRESULT: ALL PASS" : `\nRESULT: ${failures} FAILURE(S)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

// Buses (Phase E) + school audit (Phase F) end-to-end test.
//
// Verifies write-guard against the live Supabase project:
//  1. transport_admin can insert/update buses
//  2. plain teacher cannot write buses
//  3. school_audit_log accepts inserts from admin/teacher
//  4. school_audit_log rejects updates and deletes (append-only)
//  5. audit entries can carry before/after snapshots
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

const SCHOOL = "e2e_bus_school";
const ADMIN = "e2e_bus_admin";
const TRANSPORT = "e2e_bus_transport";
const PLAIN = "e2e_bus_plain";
const PASS = "bustest1234";

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

function jwtClaims(token) {
  const payload = token.split(".")[1];
  const json = Buffer.from(
    payload.replace(/-/g, "+").replace(/_/g, "/"),
    "base64",
  ).toString("utf8");
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
    username, roleKey, fullName: `Bus ${username}`, password: PASS,
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
  for (const u of [ADMIN, TRANSPORT, PLAIN]) {
    await svc(`/rest/v1/app_documents?collection=eq.auth_secrets&doc_id=eq.${u}`, { method: "DELETE" });
    await svc(`/rest/v1/auth_rate_limits?bucket_key=like.login_${u}_*`, { method: "DELETE" });
  }
  const users = await svc(`/auth/v1/admin/users?page=1&per_page=1000`);
  for (const u of users.body?.users || []) {
    if (u.email?.includes("e2e-bus-school") || u.email?.startsWith("e2e_bus_")) {
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
        id: SCHOOL, name: "Bus Test School", status: "active",
        settings: { allowSelfApproval: false },
      }),
      account(ADMIN, "admin"),
      account(TRANSPORT, "teacher", ["transport_admin"]),
      account(PLAIN, "teacher"),
    ]),
  });

  // Seed auth secrets the same way other e2e suites do (via school-login signup path
  // already handled by account password field consumed by edge function on first login).
  const adminLogin = await login(ADMIN, "admin");
  check("admin login", adminLogin.status === 200 && !!adminLogin.body?.access_token, adminLogin.body?.error);
  const transportLogin = await login(TRANSPORT, "teacher");
  check("transport login", transportLogin.status === 200 && !!transportLogin.body?.access_token, transportLogin.body?.error);
  const plainLogin = await login(PLAIN, "teacher");
  check("plain login", plainLogin.status === 200 && !!plainLogin.body?.access_token, plainLogin.body?.error);

  const adminToken = adminLogin.body.access_token;
  const transportToken = transportLogin.body.access_token;
  const plainToken = plainLogin.body.access_token;

  const claims = jwtClaims(transportToken);
  check(
    "transport JWT includes manage_buses",
    Array.isArray(claims.permissions) && claims.permissions.includes("manage_buses"),
    JSON.stringify(claims.permissions?.slice?.(0, 8) ?? claims.permissions),
  );

  // --- Buses ---
  await upsertAs(transportToken, doc("buses", "BUS-E2E-1", {
    busId: "BUS-E2E-1",
    busNumber: "Bus 1",
    plateNumber: "AA-11111",
    routeName: "Bole",
    capacity: 40,
    isActive: true,
  }));
  check("transport can create bus", !!(await readDocSvc("buses", "BUS-E2E-1")));

  await upsertAs(transportToken, doc("buses", "BUS-E2E-1", {
    busId: "BUS-E2E-1",
    busNumber: "Bus 1",
    plateNumber: "AA-22222",
    routeName: "Bole Updated",
    capacity: 45,
    assignedDriverId: "DRV-1001",
    isActive: true,
  }));
  const busAfter = await readDocSvc("buses", "BUS-E2E-1");
  check("transport can update bus", busAfter?.plateNumber === "AA-22222", busAfter?.plateNumber);
  check("bus capacity updated", busAfter?.capacity === 45, String(busAfter?.capacity));

  await upsertAs(plainToken, doc("buses", "BUS-E2E-DENIED", {
    busId: "BUS-E2E-DENIED",
    busNumber: "Bus X",
    plateNumber: "XX-00000",
    routeName: "Nope",
    capacity: 10,
    isActive: true,
  }));
  check("plain teacher cannot create bus", !(await readDocSvc("buses", "BUS-E2E-DENIED")));

  // --- School audit log ---
  await upsertAs(adminToken, doc("school_audit_log", "saudit-e2e-1", {
    id: "saudit-e2e-1",
    at: new Date().toISOString(),
    action: "bus_updated",
    actorId: ADMIN,
    actorName: "Owner",
    actorRole: "admin",
    entityType: "bus",
    entityId: "BUS-E2E-1",
    detail: "plate change",
    before: { plateNumber: "AA-11111" },
    after: { plateNumber: "AA-22222" },
  }));
  const audit = await readDocSvc("school_audit_log", "saudit-e2e-1");
  check("school audit insert works", !!audit);
  check("audit before snapshot persisted", audit?.before?.plateNumber === "AA-11111");
  check("audit after snapshot persisted", audit?.after?.plateNumber === "AA-22222");

  await upsertAs(transportToken, doc("school_audit_log", "saudit-e2e-2", {
    id: "saudit-e2e-2",
    at: new Date().toISOString(),
    action: "bus_created",
    actorId: TRANSPORT,
    entityType: "bus",
    entityId: "BUS-E2E-1",
  }));
  check("teacher can insert school audit", !!(await readDocSvc("school_audit_log", "saudit-e2e-2")));

  await upsertAs(adminToken, doc("school_audit_log", "saudit-e2e-1", {
    id: "saudit-e2e-1",
    at: new Date().toISOString(),
    action: "TAMPERED",
    before: { plateNumber: "HACKED" },
  }));
  const auditAfterTamper = await readDocSvc("school_audit_log", "saudit-e2e-1");
  check(
    "school audit update blocked",
    auditAfterTamper?.action === "bus_updated",
    auditAfterTamper?.action,
  );

  await asUser(
    adminToken,
    `/rest/v1/app_documents?collection=eq.school_audit_log&doc_id=eq.saudit-e2e-1`,
    { method: "DELETE" },
  );
  check("school audit delete blocked", !!(await readDocSvc("school_audit_log", "saudit-e2e-1")));

  await cleanup();
  console.log(`\n${failures === 0 ? "ALL PASSED" : `${failures} FAILED`}`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

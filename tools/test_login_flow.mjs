// End-to-end test of the school-login edge function.
// Creates a temporary account with a short legacy password (like migrated
// Firebase data), logs in through the deployed function, then cleans up.
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

const TEST_USER = "e2e_login_probe";
const TEST_PASSWORD = "1234"; // deliberately shorter than Supabase's 6-char minimum
const TEST_SCHOOL = "e2e_test_school";

async function rest(path, opts = {}) {
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

async function cleanup() {
  await rest(
    `/rest/v1/app_documents?collection=eq.app_auth_accounts&doc_id=eq.${TEST_USER}`,
    { method: "DELETE" },
  );
  await rest(
    `/rest/v1/app_documents?collection=eq.auth_secrets&doc_id=eq.${TEST_USER}`,
    { method: "DELETE" },
  );
  await rest(
    `/rest/v1/auth_rate_limits?bucket_key=eq.login_${TEST_USER}_admin`,
    { method: "DELETE" },
  );
  const users = await rest(`/auth/v1/admin/users?page=1&per_page=1000`);
  const match = (users.body?.users || []).find((u) =>
    u.email?.startsWith(`${TEST_USER}@`)
  );
  if (match) {
    await rest(`/auth/v1/admin/users/${match.id}`, { method: "DELETE" });
  }
}

async function main() {
  console.log("1. Cleaning any previous test data...");
  await cleanup();

  console.log("2. Creating test account (legacy-style, plaintext short password)...");
  const insert = await rest(`/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify({
      collection: "app_auth_accounts",
      doc_id: TEST_USER,
      school_id: TEST_SCHOOL,
      data: {
        username: TEST_USER,
        roleKey: "admin",
        schoolId: TEST_SCHOOL,
        fullName: "E2E Probe",
        password: TEST_PASSWORD,
      },
      updated_at: new Date().toISOString(),
    }),
  });
  if (insert.status >= 300) {
    console.error("Insert failed:", insert);
    process.exit(1);
  }

  console.log("3. Calling school-login edge function...");
  const login = await fetch(`${URL_BASE}/functions/v1/school-login`, {
    method: "POST",
    headers: {
      apikey: ANON,
      Authorization: `Bearer ${ANON}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      username: TEST_USER,
      password: TEST_PASSWORD,
      roleKey: "admin",
    }),
  });
  const loginBody = await login.json();
  console.log("   status:", login.status);

  let ok = false;
  if (login.status === 200 && loginBody.access_token && loginBody.refresh_token) {
    console.log("   got access_token + refresh_token");
    console.log("   profile:", JSON.stringify(loginBody.profile));

    console.log("4. Verifying the session token works against the API...");
    const who = await fetch(`${URL_BASE}/auth/v1/user`, {
      headers: { apikey: ANON, Authorization: `Bearer ${loginBody.access_token}` },
    });
    const whoBody = await who.json();
    console.log("   /auth/v1/user status:", who.status);
    console.log("   app_metadata:", JSON.stringify(whoBody.app_metadata));
    ok = who.status === 200 && whoBody.app_metadata?.role === "admin";
  } else {
    console.error("   LOGIN FAILED:", JSON.stringify(loginBody));
  }

  console.log("5. Cleaning up test data...");
  await cleanup();

  console.log(ok ? "\nRESULT: PASS" : "\nRESULT: FAIL");
  process.exit(ok ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

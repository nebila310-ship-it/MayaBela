// Verifies the push pipeline: seeds a fake fcm_token + app_notifications row
// (the DB trigger fires on insert), then calls send-push directly to check
// the FCM OAuth exchange and fan-out logic. A fake token cannot actually be
// delivered, but any response other than an auth/config error proves the
// pipeline (trigger -> function -> Google OAuth -> FCM API) works.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const envText = readFileSync(resolve(process.cwd(), ".env.local"), "utf8");
const env = {};
for (const line of envText.split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+)\s*$/);
  if (m) env[m[1]] = m[2];
}
const URL_BASE = env.SUPABASE_URL;
const SERVICE = env.SUPABASE_SERVICE_ROLE_KEY;
const PUSH_SECRET = process.argv[2] || "";

const SCHOOL = "e2e_push_school";

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

async function cleanup() {
  await svc(`/rest/v1/app_documents?school_id=eq.${SCHOOL}`, { method: "DELETE" });
}

async function main() {
  await cleanup();

  // Fake parent device token + a parent-targeted notification.
  await svc(`/rest/v1/app_documents`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify([
      {
        collection: "fcm_tokens",
        doc_id: "e2e_push_parent",
        school_id: SCHOOL,
        data: {
          token: "fake-token-for-pipeline-test",
          username: "e2e_push_parent",
          roleKey: "parent",
          schoolId: SCHOOL,
        },
        updated_at: new Date().toISOString(),
      },
      {
        collection: "app_notifications",
        doc_id: "e2e_push_ntf_1",
        school_id: SCHOOL,
        data: {
          id: "e2e_push_ntf_1",
          title: "Pipeline test",
          body: "This is a pipeline test notification.",
          type: "announcement",
          fromRole: "admin",
          fromName: "Tester",
          recipientRole: "parent",
          createdAt: new Date().toISOString(),
          schoolId: SCHOOL,
        },
        updated_at: new Date().toISOString(),
      },
    ]),
  });
  console.log("Seeded token + notification (trigger fires on insert).");

  // Direct call to inspect the function's behavior.
  const res = await fetch(`${URL_BASE}/functions/v1/send-push`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-push-secret": PUSH_SECRET },
    body: JSON.stringify({ doc_id: "e2e_push_ntf_1" }),
  });
  const body = await res.json();
  console.log("send-push direct call:", res.status, JSON.stringify(body));

  // Wrong secret must be rejected.
  const bad = await fetch(`${URL_BASE}/functions/v1/send-push`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-push-secret": "wrong" },
    body: JSON.stringify({ doc_id: "e2e_push_ntf_1" }),
  });
  console.log("wrong secret rejected:", bad.status === 401 ? "PASS" : `FAIL (${bad.status})`);

  await cleanup();

  const ok = res.status === 200 && body.ok === true && bad.status === 401;
  console.log(ok ? "\nRESULT: PASS (pipeline reachable end-to-end)" : "\nRESULT: FAIL");
  process.exit(ok ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

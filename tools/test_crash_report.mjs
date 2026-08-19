/**
 * Staging-only crash-report ping. Refuses production.
 *
 *   node tools/test_crash_report.mjs
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const PROD_REF = "hwkiihonthueadbhcvfi";

function loadEnvFile(filePath) {
  if (!existsSync(filePath)) return;
  for (const line of readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const i = trimmed.indexOf("=");
    if (i < 0) continue;
    const k = trimmed.slice(0, i).trim();
    const v = trimmed.slice(i + 1).trim();
    if (!process.env[k]) process.env[k] = v;
  }
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
loadEnvFile(resolve(root, ".env.staging"));

const URL_BASE = (process.env.STAGING_SUPABASE_URL || "").replace(/\/$/, "");
const ANON = process.env.STAGING_ANON_KEY || "";
const SERVICE = process.env.STAGING_SERVICE_ROLE_KEY || "";

if (!URL_BASE || !ANON || !SERVICE) {
  console.error("Set STAGING_SUPABASE_URL, STAGING_ANON_KEY, STAGING_SERVICE_ROLE_KEY");
  process.exit(2);
}
if (URL_BASE.includes(PROD_REF)) {
  console.error("Refusing to send crash reports against production.");
  process.exit(2);
}

async function main() {
  console.log("Crash-report ping against", URL_BASE);
  const marker = `drill-crash-${Date.now()}`;
  const posted = await fetch(`${URL_BASE}/functions/v1/client-crash-report`, {
    method: "POST",
    headers: {
      apikey: ANON,
      Authorization: `Bearer ${ANON}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: marker,
      stack: "restore-drill",
      release: "drill",
      platform: "script",
      role: "teacher",
      schoolId: "DRILL",
      fatal: false,
    }),
  });
  const body = await posted.json().catch(() => ({}));
  if (posted.status !== 200 || !body.id) {
    console.log(`FAIL  post crash report — status=${posted.status} ${JSON.stringify(body)}`);
    process.exit(1);
  }
  console.log(`PASS  post crash report — id=${body.id}`);

  const listed = await fetch(
    `${URL_BASE}/rest/v1/app_documents?collection=eq.client_crash_reports&doc_id=eq.${body.id}&select=doc_id,data`,
    {
      headers: {
        apikey: SERVICE,
        Authorization: `Bearer ${SERVICE}`,
      },
    },
  );
  const rows = await listed.json();
  const ok = Array.isArray(rows) && rows[0]?.data?.message === marker;
  console.log(
    `${ok ? "PASS" : "FAIL"}  service role can read stored report`,
  );

  await fetch(
    `${URL_BASE}/rest/v1/app_documents?collection=eq.client_crash_reports&doc_id=eq.${body.id}`,
    {
      method: "DELETE",
      headers: {
        apikey: SERVICE,
        Authorization: `Bearer ${SERVICE}`,
        Prefer: "return=minimal",
      },
    },
  );
  console.log(ok ? "\nRESULT: ALL PASS" : "\nRESULT: FAILURE");
  process.exit(ok ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

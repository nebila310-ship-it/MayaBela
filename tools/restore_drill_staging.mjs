/**
 * Staging-only restore drill. Refuses production.
 *
 * 1. Insert a canary app_documents row.
 * 2. Snapshot it.
 * 3. Delete it and confirm it is gone.
 * 4. Restore from the snapshot and confirm it is back.
 *
 * This is a logical (row) restore, which is what Free-plan projects can
 * rehearse. Point-in-Time Recovery is a paid Supabase add-on (Pro + Small
 * compute + PITR). Enable later at:
 *   https://supabase.com/dashboard/project/hwkiihonthueadbhcvfi/settings/addons?panel=pitr
 *
 *   node tools/restore_drill_staging.mjs
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const PROD_REF = "hwkiihonthueadbhcvfi";
const SCHOOL = "DRILL";
const DOC_ID = `restore-canary-${Date.now()}`;

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
const SERVICE = process.env.STAGING_SERVICE_ROLE_KEY || "";

if (!URL_BASE || !SERVICE) {
  console.error("Set STAGING_SUPABASE_URL and STAGING_SERVICE_ROLE_KEY");
  process.exit(2);
}
if (URL_BASE.includes(PROD_REF)) {
  console.error("Refusing to run restore drill against production.");
  process.exit(2);
}

async function rest(path, opts = {}) {
  const res = await fetch(`${URL_BASE}${path}`, {
    ...opts,
    headers: {
      apikey: SERVICE,
      Authorization: `Bearer ${SERVICE}`,
      "Content-Type": "application/json",
      Prefer: opts.prefer || "return=representation",
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: res.status, body };
}

function row() {
  return {
    collection: "restore_drill_canary",
    doc_id: DOC_ID,
    school_id: SCHOOL,
    data: {
      schoolId: SCHOOL,
      marker: "restore-drill",
      note: "safe to delete",
      at: new Date().toISOString(),
    },
    updated_at: new Date().toISOString(),
  };
}

async function countCanary() {
  const { status, body } = await rest(
    `/rest/v1/app_documents?collection=eq.restore_drill_canary&school_id=eq.${SCHOOL}&doc_id=eq.${DOC_ID}&select=doc_id`,
  );
  if (status >= 300) {
    throw new Error(`lookup failed ${status}: ${JSON.stringify(body)}`);
  }
  return Array.isArray(body) ? body.length : 0;
}

let failures = 0;
function check(name, ok, detail = "") {
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? ` — ${detail}` : ""}`);
  if (!ok) failures += 1;
}

async function cleanup() {
  await rest(
    `/rest/v1/app_documents?collection=eq.restore_drill_canary&school_id=eq.${SCHOOL}`,
    { method: "DELETE", prefer: "return=minimal" },
  );
}

async function main() {
  console.log("Restore drill against", URL_BASE);
  console.log("PITR: not available on Free plan. This drill is a logical row restore.");
  console.log(
    "Paid PITR (production, after Pro + Small compute): https://supabase.com/dashboard/project/hwkiihonthueadbhcvfi/settings/addons?panel=pitr",
  );
  await cleanup();

  const snapshot = row();
  const inserted = await rest(`/rest/v1/app_documents`, {
    method: "POST",
    prefer: "return=minimal",
    body: JSON.stringify(snapshot),
  });
  check("insert canary", inserted.status < 300, `status=${inserted.status}`);
  check("canary present after insert", (await countCanary()) === 1);

  const deleted = await rest(
    `/rest/v1/app_documents?collection=eq.restore_drill_canary&school_id=eq.${SCHOOL}&doc_id=eq.${DOC_ID}`,
    { method: "DELETE", prefer: "return=minimal" },
  );
  check("delete canary", deleted.status < 300, `status=${deleted.status}`);
  check("canary gone after delete", (await countCanary()) === 0);

  const restored = await rest(`/rest/v1/app_documents`, {
    method: "POST",
    prefer: "resolution=merge-duplicates,return=minimal",
    body: JSON.stringify(snapshot),
  });
  check("restore canary from snapshot", restored.status < 300, `status=${restored.status}`);
  check("canary present after restore", (await countCanary()) === 1);

  await cleanup();
  check("cleanup removed canary", (await countCanary()) === 0);

  console.log(failures === 0 ? "\nRESULT: ALL PASS" : `\nRESULT: ${failures} FAILURE(S)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch(async (e) => {
  console.error(e);
  try {
    await cleanup();
  } catch (_) {}
  process.exit(1);
});

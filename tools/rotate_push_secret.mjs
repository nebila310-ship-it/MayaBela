/**
 * Rotate the push fan-out secret.
 *
 * Sets the edge function secret PUSH_TRIGGER_SECRET and the matching
 * platform_secrets/push_trigger.pushSecret (server-only). The secret is never
 * printed or passed on a command line: the edge secret is set from a
 * temporary 0600 env file that is deleted afterwards.
 *
 * Usage (from repo root, with service role in env):
 *   node tools/rotate_push_secret.mjs --project-ref <ref> --apply
 *   node tools/rotate_push_secret.mjs --project-ref <ref> --out <file>
 *       (stores the DB value and writes the edge value to a 0600 file only)
 *
 * The production project additionally needs --confirm-production.
 * Pushes sent in the seconds between the two updates are rejected and not
 * retried, so run it in a quiet period.
 *
 * Required env:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 */
import { randomBytes } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
function loadEnvLocal() {
  const envPath = path.join(__dirname, "..", ".env.local");
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const i = trimmed.indexOf("=");
    if (i < 0) continue;
    const k = trimmed.slice(0, i).trim();
    const v = trimmed.slice(i + 1).trim();
    if (!process.env[k]) process.env[k] = v;
  }
}
loadEnvLocal();

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const PRODUCTION_REF = "hwkiihonthueadbhcvfi";
function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}
const projectRef = arg("--project-ref");
const apply = process.argv.includes("--apply");
const outFile = arg("--out");
if (!projectRef || (!apply && !outFile)) {
  console.error("Usage: --project-ref <ref> (--apply | --out <file>)");
  process.exit(1);
}
if (projectRef === PRODUCTION_REF && !process.argv.includes("--confirm-production")) {
  console.error("Refusing to rotate the production secret without --confirm-production.");
  process.exit(1);
}
if (!url.includes(projectRef)) {
  console.error("SUPABASE_URL does not belong to --project-ref; refusing.");
  process.exit(1);
}

const { createClient } = await import("@supabase/supabase-js");
const secret = randomBytes(32).toString("hex");
const sb = createClient(url, key, {
  auth: { autoRefreshToken: false, persistSession: false },
});

if (apply) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "push-secret-"));
  const envFile = path.join(dir, "secret.env");
  fs.writeFileSync(envFile, `PUSH_TRIGGER_SECRET=${secret}\n`, { mode: 0o600 });
  let r;
  try {
    r = spawnSync(
      "npx",
      ["supabase", "secrets", "set", "--env-file", envFile, "--project-ref", projectRef],
      { stdio: "inherit", shell: process.platform === "win32" },
    );
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  if (r.status !== 0) {
    console.error("Failed to set edge PUSH_TRIGGER_SECRET; database value left unchanged.");
    process.exit(r.status || 1);
  }
} else {
  fs.writeFileSync(outFile, `PUSH_TRIGGER_SECRET=${secret}\n`, { mode: 0o600, flag: "wx" });
}

const { error } = await sb.from("app_documents").upsert({
  collection: "platform_secrets",
  doc_id: "push_trigger",
  school_id: "__PLATFORM__",
  data: {
    pushSecret: secret,
    updatedAt: new Date().toISOString(),
  },
  updated_at: new Date().toISOString(),
}, { onConflict: "collection,school_id,doc_id" });

if (error) {
  console.error("Failed to upsert push secret:", error.message);
  process.exit(1);
}

if (apply) {
  console.log("Rotated push secret in edge secrets and platform_secrets.");
} else {
  console.log(`Stored new push secret in platform_secrets/push_trigger.`);
  console.log(`Edge value written to ${outFile} (mode 0600). Set it with:`);
  console.log(`  npx supabase secrets set --env-file ${outFile} --project-ref ${projectRef}`);
  console.log("Then delete the file.");
}

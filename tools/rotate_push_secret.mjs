/**
 * Rotate the push fan-out secret.
 *
 * Writes platform_secrets/push_trigger.pushSecret (server-only) and prints the
 * value to set as the edge function secret PUSH_TRIGGER_SECRET.
 *
 * Usage (from repo root, with service role in env):
 *   node tools/rotate_push_secret.mjs
 *
 * Required env:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 */
import { createClient } from "@supabase/supabase-js";
import { randomBytes } from "node:crypto";
import fs from "node:fs";
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

const secret = randomBytes(32).toString("hex");
const sb = createClient(url, key, {
  auth: { autoRefreshToken: false, persistSession: false },
});

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

const apply = process.argv.includes("--apply");
if (apply) {
  const r = spawnSync(
    "npx",
    [
      "supabase",
      "secrets",
      "set",
      `PUSH_TRIGGER_SECRET=${secret}`,
      "--project-ref",
      "hwkiihonthueadbhcvfi",
    ],
    { stdio: "inherit", shell: true },
  );
  if (r.status !== 0) {
    console.error("Failed to set edge PUSH_TRIGGER_SECRET");
    process.exit(r.status || 1);
  }
  console.log("Rotated push secret in platform_secrets and edge secrets.");
  process.exit(0);
}

console.log("Stored new push secret in platform_secrets/push_trigger");
console.log("");
console.log("Now set the matching edge secret:");
console.log("  npx supabase secrets set PUSH_TRIGGER_SECRET=<printed-by-this-script> --project-ref hwkiihonthueadbhcvfi");
console.log("");
console.log(`PUSH_TRIGGER_SECRET=${secret}`);
console.log("");
console.log("Or re-run with --apply to set the edge secret automatically.");

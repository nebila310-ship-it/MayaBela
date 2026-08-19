/**
 * Delete auth accounts + secrets for inactive MAL838 staff so phones can be reused.
 */
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { createClient } = require("@supabase/supabase-js");

const __dirname = dirname(fileURLToPath(import.meta.url));
function loadEnvLocal() {
  const envPath = resolve(__dirname, "..", ".env.local");
  for (const line of readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith("#") || !t.includes("=")) continue;
    const i = t.indexOf("=");
    const k = t.slice(0, i).trim();
    let v = t.slice(i + 1).trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    if (!process.env[k]) process.env[k] = v;
  }
}
loadEnvLocal();

const sb = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

const schoolId = "MAL838";
const phones = ["0975959566", "0919839010"];

async function del(collection, docId) {
  const { error } = await sb
    .from("app_documents")
    .delete()
    .eq("collection", collection)
    .eq("doc_id", docId);
  console.log("delete", collection, docId, error || "ok");
}

for (const phone of phones) {
  const ids = [phone, `${schoolId}__${phone}`];
  for (const id of ids) {
    await del("app_auth_accounts", id);
    await del("auth_secrets", id);
  }
}

console.log("done");

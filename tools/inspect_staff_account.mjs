/**
 * Look up a school auth account by school + phone and print staffRoles.
 * Loads ../.env.local for SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY.
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

const schoolId = (process.argv[2] || "MAL838").trim().toUpperCase();
const phone = String(process.argv[3] || "910101010").replace(/\D/g, "").replace(/^251/, "");
const username = phone.length === 9 ? phone : phone.slice(-9);
const docId = `${schoolId}__${username}`;

const sb = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

const { data, error } = await sb
  .from("app_documents")
  .select("doc_id, school_id, data, updated_at")
  .eq("collection", "app_auth_accounts")
  .or(`doc_id.eq.${docId},doc_id.eq.${username}`)
  .limit(10);

if (error) {
  console.error(error);
  process.exit(1);
}

console.log(JSON.stringify({ lookup: { schoolId, username, docId }, rows: data }, null, 2));

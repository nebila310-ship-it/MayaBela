/**
 * Find auth accounts for MAL838 that match inactive teachers (orphaned logins).
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
const { data: auth } = await sb
  .from("app_documents")
  .select("doc_id, school_id, data")
  .eq("collection", "app_auth_accounts")
  .eq("school_id", schoolId);

const { data: tea } = await sb
  .from("app_documents")
  .select("doc_id, data")
  .eq("collection", "teacher_registry")
  .eq("school_id", schoolId);

const inactivePhones = new Set();
for (const t of tea || []) {
  if (t.data?.isActive === false) {
    const phone = String(t.data.phone || t.data.loginUsername || "")
      .replace(/\D/g, "")
      .replace(/^251/, "");
    const local = phone.length === 9 ? `0${phone}` : phone.length === 10 ? phone : "";
    if (local) inactivePhones.add(local);
    console.log("inactive", t.doc_id, t.data.fullName, t.data.phone, t.data.loginUsername);
  }
}

console.log("\ninactive phones", [...inactivePhones]);
console.log("\nauth accounts matching inactive phones:");
for (const a of auth || []) {
  const phone = String(a.data?.phone || a.data?.username || "");
  const digits = phone.replace(/\D/g, "");
  const local =
    digits.length === 9
      ? `0${digits}`
      : digits.startsWith("0")
        ? digits
        : digits.length === 10
          ? digits
          : phone;
  if (inactivePhones.has(local) || inactivePhones.has(phone)) {
    console.log("ORPHAN AUTH", a.doc_id, a.data?.fullName, a.data?.username, a.data?.roleKey);
  }
}

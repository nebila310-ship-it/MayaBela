/**
 * Diagnose MAL838 admin/staff login readiness.
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

const ids = [
  "0912798279",
  "MAL838__0912798279",
  "0910101010",
  "MAL838__0910101010",
  "0977441122",
  "MAL838__0977441122",
];

const { data: secrets, error } = await sb
  .from("app_documents")
  .select("doc_id, school_id, data")
  .eq("collection", "auth_secrets")
  .in("doc_id", ids);

console.log("=== secrets for key accounts ===");
console.log(
  JSON.stringify(
    {
      error,
      secrets: (secrets || []).map((r) => ({
        doc_id: r.doc_id,
        school_id: r.school_id,
        hasHash: !!r.data?.passwordHash,
      })),
    },
    null,
    2,
  ),
);

const { data: allSecrets } = await sb
  .from("app_documents")
  .select("doc_id, school_id")
  .eq("collection", "auth_secrets")
  .eq("school_id", "MAL838")
  .limit(100);
console.log("\n=== all MAL838 secrets ===");
console.log((allSecrets || []).map((r) => r.doc_id));

const { data: bad } = await sb
  .from("app_documents")
  .select("doc_id, school_id, data")
  .eq("collection", "app_auth_accounts")
  .eq("school_id", "MAL838")
  .limit(100);

const mismatches = (bad || []).filter((r) => {
  const sid = String(r.data?.schoolId || "").trim().toUpperCase();
  return sid && sid !== String(r.school_id || "").trim().toUpperCase();
});
console.log("\n=== school_id column vs data.schoolId mismatches ===");
console.log(
  JSON.stringify(
    mismatches.map((r) => ({
      doc_id: r.doc_id,
      column: r.school_id,
      dataSchoolId: r.data?.schoolId,
      roleKey: r.data?.roleKey,
      fullName: r.data?.fullName,
      username: r.data?.username,
    })),
    null,
    2,
  ),
);

// Probe school-login for owner
const url = `${process.env.SUPABASE_URL}/functions/v1/school-login`;
async function tryLogin(label, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.SUPABASE_ANON_KEY}`,
      apikey: process.env.SUPABASE_ANON_KEY,
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  console.log(`\n=== login ${label} status=${res.status} ===`);
  console.log(text.slice(0, 500));
}

await tryLogin("owner Welcome12!", {
  username: "0912798279",
  password: "Welcome12!",
  roleKey: "admin",
  schoolId: "MAL838",
});

await tryLogin("owner Welcome1", {
  username: "0912798279",
  password: "Welcome1",
  roleKey: "admin",
  schoolId: "MAL838",
});

await tryLogin("staff 0910101010 Welcome12!", {
  username: "0910101010",
  password: "Welcome12!",
  roleKey: "teacher",
  schoolId: "MAL838",
});

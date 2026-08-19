/**
 * Broader search for MAL838 / phone 910101010 in app_documents.
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

async function q(label, filter) {
  const { data, error } = await filter;
  console.log("\n===", label, "===");
  if (error) console.error(error);
  else console.log(JSON.stringify(data, null, 2));
}

await q(
  "auth by school_id MAL838",
  sb
    .from("app_documents")
    .select("doc_id, school_id, data")
    .eq("collection", "app_auth_accounts")
    .eq("school_id", "MAL838")
    .limit(50),
);

await q(
  "auth phone contains 910101010",
  sb
    .from("app_documents")
    .select("doc_id, school_id, data")
    .eq("collection", "app_auth_accounts")
    .filter("data->>phone", "ilike", "%910101010%")
    .limit(20),
);

await q(
  "auth username 910101010",
  sb
    .from("app_documents")
    .select("doc_id, school_id, data")
    .eq("collection", "app_auth_accounts")
    .filter("data->>username", "eq", "910101010")
    .limit(20),
);

await q(
  "teacher_registry school MAL838",
  sb
    .from("app_documents")
    .select("doc_id, school_id, data")
    .eq("collection", "teacher_registry")
    .eq("school_id", "MAL838")
    .limit(50),
);

await q(
  "teacher_registry phone 910101010",
  sb
    .from("app_documents")
    .select("doc_id, school_id, data")
    .eq("collection", "teacher_registry")
    .filter("data->>phone", "ilike", "%910101010%")
    .limit(20),
);

await q(
  "school_registry MAL838",
  sb
    .from("app_documents")
    .select("doc_id, school_id, data")
    .eq("collection", "school_registry")
    .or("doc_id.eq.MAL838,doc_id.ilike.MAL838")
    .limit(5),
);

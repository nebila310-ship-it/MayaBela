/**
 * Recompute staffPermissions for librarian accounts from the updated catalog
 * (no view_students → no Attendance / Transfers in sidebar).
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

const LIBRARIAN_PERMS = [
  "manage_learning_materials",
  "manage_material_access",
  // baseline
  "view_reports",
  "view_audit_log",
  "access_support",
  "view_system_health",
];

const sb = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

const { data, error } = await sb
  .from("app_documents")
  .select("doc_id, school_id, data")
  .eq("collection", "app_auth_accounts")
  .limit(500);

if (error) {
  console.error(error);
  process.exit(1);
}

let updated = 0;
for (const row of data || []) {
  const roles = Array.isArray(row.data?.staffRoles) ? row.data.staffRoles : [];
  if (!roles.includes("librarian")) continue;
  // Only pure librarian (or librarian-only bundles) get the stripped perms.
  // If they also hold other roles, leave alone.
  const onlyLibrarian =
    roles.length === 1 || roles.every((r) => r === "librarian");
  if (!onlyLibrarian && roles.some((r) => r !== "librarian")) {
    // Recompute as union is complex here — skip multi-role accounts.
    if (roles.length > 1) {
      console.log("skip multi-role", row.doc_id, roles);
      continue;
    }
  }

  const next = {
    ...row.data,
    staffPermissions: LIBRARIAN_PERMS,
    updatedAt: new Date().toISOString(),
  };
  const { error: upErr } = await sb
    .from("app_documents")
    .update({ data: next, updated_at: new Date().toISOString() })
    .eq("collection", "app_auth_accounts")
    .eq("doc_id", row.doc_id);
  console.log(row.doc_id, upErr || "updated");
  if (!upErr) updated++;
}

console.log("done, updated", updated);

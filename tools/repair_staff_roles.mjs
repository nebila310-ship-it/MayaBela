/**
 * Repair auth accounts whose staffRoles were wiped but teacher_registry
 * still has them. Also prefer copying roles from legacy phone-only docs.
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

const ROLE_PERMS = {
  student_affairs: [
    "view_students",
    "manage_students",
    "manage_parent_links",
    "create_transfers",
    "message_parents",
    "send_announcements",
  ],
  section_director: [
    "manage_classes",
    "manage_subjects",
    "assign_teachers",
    "manage_timetables",
    "view_all_grades",
    "approve_grades",
    "approve_transfers",
    "manage_learning_materials",
    "manage_material_access",
    "view_students",
    "view_staff",
  ],
  librarian: ["manage_learning_materials", "view_students"],
  procurement: [
    "view_inventory",
    "create_purchase_requests",
    "approve_purchase_requests",
    "manage_suppliers",
    "enter_purchased_items",
    "approve_issue_requests",
    "receive_stock",
    "issue_stock",
    "adjust_stock",
    "create_issue_requests",
  ],
  registrar: [
    "view_students",
    "manage_students",
    "manage_parent_links",
    "create_transfers",
    "promote_students",
  ],
  accountant: [
    "manage_fees",
    "record_payments",
    "view_finance_reports",
    "view_students",
  ],
  human_resource: ["view_staff", "manage_staff_accounts", "assign_roles"],
  transport_admin: [
    "view_transport",
    "manage_buses",
    "manage_drivers",
    "assign_student_transport",
    "view_students",
  ],
  storekeeper: [
    "view_inventory",
    "receive_stock",
    "issue_stock",
    "adjust_stock",
    "create_issue_requests",
  ],
  vice_president: [
    "view_students",
    "view_staff",
    "view_inventory",
    "view_transport",
    "view_all_grades",
    "view_finance_reports",
    "view_all_departments",
    "approve_transfers",
    "approve_grades",
    "approve_purchase_requests",
    "approve_issue_requests",
  ],
};

const sb = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

const { data: teachers, error: tErr } = await sb
  .from("app_documents")
  .select("doc_id, school_id, data")
  .eq("collection", "teacher_registry");
if (tErr) throw tErr;

let fixed = 0;
for (const t of teachers || []) {
  const roles = Array.isArray(t.data?.staffRoles) ? t.data.staffRoles : [];
  if (!roles.length) continue;
  const schoolId = String(t.school_id || t.data.schoolId || "").toUpperCase();
  const username = String(t.data.loginUsername || t.data.phone || "")
    .trim()
    .toLowerCase();
  if (!schoolId || !username) continue;

  const perms = [
    ...new Set(roles.flatMap((r) => ROLE_PERMS[r] || [])),
  ];
  const docIds = [`${schoolId}__${username}`, username];

  for (const docId of docIds) {
    const { data: row } = await sb
      .from("app_documents")
      .select("doc_id, data")
      .eq("collection", "app_auth_accounts")
      .eq("doc_id", docId)
      .maybeSingle();
    if (!row) continue;
    const existing = Array.isArray(row.data?.staffRoles)
      ? row.data.staffRoles
      : [];
    if (existing.length > 0) continue;

    const next = {
      ...row.data,
      staffRoles: roles,
      staffPermissions: perms,
      updatedAt: new Date().toISOString(),
    };
    const { error } = await sb.from("app_documents").upsert({
      collection: "app_auth_accounts",
      doc_id: docId,
      school_id: schoolId,
      data: next,
      updated_at: new Date().toISOString(),
    });
    if (error) {
      console.error("fail", docId, error.message);
    } else {
      fixed++;
      console.log("fixed", docId, "->", roles.join(","));
    }
  }
}
console.log("done, fixed", fixed);

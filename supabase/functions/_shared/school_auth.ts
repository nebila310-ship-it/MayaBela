import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export const ROLES = new Set(["admin", "teacher", "parent", "driver", "student"]);
export const MIN_PASSWORD_LENGTH = 10;
export const BCRYPT_ROUNDS = 12;
export const LOGIN_RATE_LIMIT = 8;
export const LOGIN_RATE_WINDOW_MS = 15 * 60 * 1000;
/** Owner-console calls after a valid PIN (list/create/update/logo). */
export const PLATFORM_AUTHED_RATE_LIMIT = 120;
export const PLATFORM_AUTHED_RATE_WINDOW_MS = 15 * 60 * 1000;
/** PIN checks on owner endpoints, before verify. */
export const PLATFORM_PIN_CHECK_LIMIT = 60;
export const ACCESS_CLAIM_CAP = 30;

// ---------------------------------------------------------------------------
// RBAC catalog — mirror of lib/services/rbac/staff_permissions.dart.
// Keep the three copies (Dart / this file / rbac migration SQL) in sync.
// ---------------------------------------------------------------------------

export const ALL_PERMISSIONS: string[] = [
  // Students & registrar
  "view_students",
  "manage_students",
  "manage_parent_links",
  "create_transfers",
  "approve_transfers",
  "promote_students",
  // Academic
  "manage_classes",
  "manage_subjects",
  "assign_teachers",
  "manage_timetables",
  "view_all_grades",
  "view_all_school_data",
  "approve_grades",
  "manage_learning_materials",
  "manage_material_access",
  // Staff / HR
  "view_staff",
  "manage_staff_accounts",
  "assign_roles",
  // Procurement
  "create_purchase_requests",
  "approve_purchase_requests",
  "manage_suppliers",
  "enter_purchased_items",
  "approve_issue_requests",
  "view_inventory",
  // Store
  "receive_stock",
  "issue_stock",
  "adjust_stock",
  "create_issue_requests",
  // Finance
  "manage_fees",
  "record_payments",
  "view_finance_reports",
  // Transport
  "manage_buses",
  "manage_drivers",
  "assign_student_transport",
  "view_transport",
  // Communication
  "send_announcements",
  "message_parents",
  // Oversight & shared baseline
  "view_all_departments",
  "view_reports",
  "view_audit_log",
  "access_support",
  "view_system_health",
  // Quality Assurance
  "manage_qa_findings",
  // Settings
  "manage_school_settings",
  "manage_campuses",
];

const BASELINE: string[] = [
  "view_reports",
  "view_audit_log",
  "access_support",
  "view_system_health",
];

function withBaseline(perms: string[]): string[] {
  return [...new Set([...perms, ...BASELINE])];
}

/** Legacy / EDUABA aliases map onto the current catalog. */
export const STAFF_ROLE_ALIASES: Record<string, string> = {
  academic_admin: "section_director",
  hr_admin: "human_resource",
  finance: "accountant",
  vice_principal: "vice_president",
  finance_manager: "accountant",
  transport_head: "transport_admin",
};

const LEADERSHIP = withBaseline([
  "view_students",
  "view_staff",
  "view_inventory",
  "view_transport",
  "view_all_grades",
  "view_all_school_data",
  "view_finance_reports",
  "view_all_departments",
  "approve_transfers",
  "approve_grades",
  "approve_purchase_requests",
  "approve_issue_requests",
  "send_announcements",
  "access_support",
  "message_parents",
  "manage_staff_accounts",
  "assign_teachers",
  "manage_classes",
]);

export const STAFF_ROLE_PERMISSIONS: Record<string, string[]> = {
  full_access: ALL_PERMISSIONS,
  school_board: withBaseline([
    "view_students",
    "view_staff",
    "view_all_grades",
    "view_all_school_data",
    "view_finance_reports",
    "view_all_departments",
    "view_reports",
    "view_audit_log",
  ]),
  general_manager: LEADERSHIP,
  deputy_general_manager: LEADERSHIP,
  principal: withBaseline([
    "view_students",
    "view_staff",
    "view_all_grades",
    "view_all_school_data",
    "approve_grades",
    "approve_transfers",
    "manage_classes",
    "manage_subjects",
    "manage_timetables",
    "send_announcements",
    "message_parents",
    "access_support",
    "view_transport",
  ]),
  quality_assurance: withBaseline([
    "view_students",
    "view_staff",
    "view_all_grades",
    "view_all_school_data",
    "view_all_departments",
    "view_audit_log",
    "view_reports",
    "manage_qa_findings",
    "access_support",
  ]),
  vice_president: withBaseline([
    "view_students",
    "view_staff",
    "view_inventory",
    "view_transport",
    "view_all_grades",
    "view_all_school_data",
    "view_finance_reports",
    "view_all_departments",
    "approve_transfers",
    "approve_grades",
    "approve_purchase_requests",
    "approve_issue_requests",
    "send_announcements",
    "manage_learning_materials",
    "manage_material_access",
    "access_support",
    "message_parents",
    "assign_teachers",
    "manage_classes",
  ]),
  section_director: withBaseline([
    "manage_classes",
    "manage_subjects",
    "assign_teachers",
    "manage_timetables",
    "view_all_grades",
    "view_all_school_data",
    "approve_grades",
    "create_transfers",
    "manage_students",
    "manage_learning_materials",
    "manage_material_access",
    "view_students",
    "view_staff",
    "view_transport",
    "assign_student_transport",
    "manage_parent_links",
    "access_support",
    "message_parents",
  ]),
  student_affairs: withBaseline([
    "view_students",
    "view_all_school_data",
    "manage_students",
    "manage_parent_links",
    "create_transfers",
    "message_parents",
    "send_announcements",
  ]),
  registrar: withBaseline([
    "view_students",
    "view_all_school_data",
    "manage_students",
    "manage_parent_links",
    "create_transfers",
    "promote_students",
    "message_parents",
    "access_support",
  ]),
  accountant: withBaseline([
    "manage_fees",
    "record_payments",
    "view_finance_reports",
    "view_students",
    "view_all_school_data",
    "approve_purchase_requests",
    "view_inventory",
    "view_transport",
    "message_parents",
    "access_support",
  ]),
  human_resource: withBaseline([
    "view_staff",
    "manage_staff_accounts",
    "view_transport",
    "manage_buses",
    "manage_drivers",
    "assign_student_transport",
    "view_students",
    "view_all_school_data",
    "access_support",
    "message_parents",
  ]),
  librarian: withBaseline([
    "manage_learning_materials",
    "manage_material_access",
  ]),
  procurement: withBaseline([
    "create_purchase_requests",
    "manage_suppliers",
    "enter_purchased_items",
    "approve_issue_requests",
    "view_inventory",
  ]),
  storekeeper: withBaseline([
    "receive_stock",
    "issue_stock",
    "adjust_stock",
    "create_issue_requests",
    "view_inventory",
  ]),
  transport_admin: withBaseline([
    "manage_buses",
    "manage_drivers",
    "assign_student_transport",
    "view_transport",
    "view_students",
    "view_all_school_data",
    "message_parents",
    "access_support",
  ]),
  staffs: withBaseline([
    "view_staff",
    "access_support",
  ]),
  // Legacy keys (same bundles as their aliases).
  academic_admin: withBaseline([
    "manage_classes",
    "manage_subjects",
    "assign_teachers",
    "manage_timetables",
    "view_all_grades",
    "view_all_school_data",
    "approve_grades",
    "approve_transfers",
    "manage_learning_materials",
    "manage_material_access",
    "view_students",
    "view_staff",
    "view_transport",
    "assign_student_transport",
    "manage_parent_links",
    "access_support",
    "message_parents",
  ]),
  hr_admin: withBaseline([
    "view_staff",
    "manage_staff_accounts",
    "view_transport",
    "manage_buses",
    "manage_drivers",
    "assign_student_transport",
    "view_students",
    "view_all_school_data",
    "access_support",
    "message_parents",
  ]),
  finance: withBaseline([
    "manage_fees",
    "record_payments",
    "view_finance_reports",
    "view_students",
    "view_all_school_data",
    "approve_purchase_requests",
    "view_inventory",
    "view_transport",
    "message_parents",
    "access_support",
  ]),
};

/** Only the school owner (admin account) may grant these roles. */
export const OWNER_ONLY_ROLES = new Set(["full_access"]);

export function canonicalizeStaffRole(key: string): string {
  const k = String(key || "").trim().toLowerCase();
  return STAFF_ROLE_ALIASES[k] || k;
}

export function normalizeStaffRoles(raw: unknown): string[] {
  const out: string[] = [];
  for (const value of Array.isArray(raw) ? raw : []) {
    const key = canonicalizeStaffRole(String(value || ""));
    if (!key) continue;
    // Built-in catalog or school custom roles (custom_*).
    if (
      (STAFF_ROLE_PERMISSIONS[key] || key.startsWith("custom_")) &&
      !out.includes(key)
    ) {
      out.push(key);
    }
  }
  return out;
}

export function permissionsForRoles(roleKeys: string[]): string[] {
  const out = new Set<string>();
  for (const key of roleKeys) {
    for (const perm of STAFF_ROLE_PERMISSIONS[key] || []) out.add(perm);
  }
  return [...out];
}

export function permissionsFromProfile(profile: Record<string, unknown>): string[] {
  const stamped = profile.staffPermissions;
  if (Array.isArray(stamped) && stamped.length > 0) {
    return [
      ...new Set(
        stamped
          .map((p) => String(p || "").trim())
          .filter((p) => p && ALL_PERMISSIONS.includes(p)),
      ),
    ];
  }
  return permissionsForRoles(normalizeStaffRoles(profile.staffRoles));
}

export function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export function normalizeUsername(value: unknown): string {
  return String(value || "").trim().toLowerCase();
}

export function normalizeEmail(value: unknown): string | null {
  const email = String(value || "").trim().toLowerCase();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  return email;
}

export function uniqueStrings(values: unknown, cap = ACCESS_CLAIM_CAP): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of (values as unknown[]) || []) {
    const value = String(raw || "").trim();
    if (!value) continue;
    const key = value.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(value);
    if (out.length >= cap) break;
  }
  return out;
}

/** Platform-owned rows (PIN, push secret) live under this school_id. */
export const PLATFORM_SCHOOL_ID = "__PLATFORM__";

export function resolveDocSchoolId(
  collection: string,
  docId: string,
  schoolId?: string | null,
): string | null {
  const sid = String(schoolId || "").trim().toUpperCase();
  if (sid) return sid;
  const fromDoc = String(docId || "").trim().toUpperCase();
  if (collection === "platform_secrets" || collection === "platform_audit_log") {
    return PLATFORM_SCHOOL_ID;
  }
  if (collection === "school_registry" && fromDoc) {
    return fromDoc;
  }
  return null;
}

export async function getDoc(
  sb: SupabaseClient,
  collection: string,
  docId: string,
  schoolId?: string | null,
): Promise<Record<string, unknown> | null> {
  const sid = resolveDocSchoolId(collection, docId, schoolId);
  let q = sb
    .from("app_documents")
    .select("data")
    .eq("collection", collection)
    .eq("doc_id", docId);
  if (sid) q = q.eq("school_id", sid);
  const { data, error } = await q.maybeSingle();
  if (error) throw error;
  return data?.data ? { ...(data.data as Record<string, unknown>) } : null;
}

export async function upsertDoc(
  sb: SupabaseClient,
  collection: string,
  docId: string,
  data: Record<string, unknown>,
  schoolId?: string | null,
): Promise<void> {
  const sid = resolveDocSchoolId(
    collection,
    docId,
    (typeof data.schoolId === "string" && data.schoolId.trim()) || schoolId,
  );
  if (!sid) {
    throw new Error(`school_id required to upsert ${collection}/${docId}`);
  }
  const { error } = await sb.from("app_documents").upsert(
    {
      collection,
      doc_id: docId,
      school_id: sid,
      data,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "collection,school_id,doc_id" },
  );
  if (error) throw error;
}

export async function deleteDoc(
  sb: SupabaseClient,
  collection: string,
  docId: string,
  schoolId?: string | null,
): Promise<void> {
  const id = String(docId || "").trim();
  if (!id) return;
  const sid = resolveDocSchoolId(collection, docId, schoolId);
  let q = sb
    .from("app_documents")
    .delete()
    .eq("collection", collection)
    .eq("doc_id", id);
  if (sid) q = q.eq("school_id", sid);
  const { error } = await q;
  if (error) throw error;
}

/** Remove login docs + password secrets so a phone can be registered again. */
export async function deleteAccountAndSecrets(
  sb: SupabaseClient,
  username: string,
  schoolId: string,
): Promise<{ deletedAccountIds: string[]; deletedSecretIds: string[] }> {
  const key = normalizeUsername(username);
  const sid = String(schoolId || "").trim().toUpperCase();
  const accountIds = new Set<string>([
    key,
    ...(sid ? [accountDocId(sid, key)] : []),
  ]);
  const secretIds = new Set<string>(accountIds);

  // Also catch legacy rows keyed only by phone when school-scoped id differs.
  for (const id of [...accountIds]) {
    const existing = await getDoc(sb, "app_auth_accounts", id, sid);
    if (!existing) continue;
    const phone = String(existing.phone || "").trim();
    if (phone) {
      const phoneKey = normalizeUsername(phone);
      accountIds.add(phoneKey);
      secretIds.add(phoneKey);
      if (sid) {
        accountIds.add(accountDocId(sid, phoneKey));
        secretIds.add(accountDocId(sid, phoneKey));
      }
    }
  }

  const deletedAccountIds: string[] = [];
  const deletedSecretIds: string[] = [];
  for (const id of accountIds) {
    await deleteDoc(sb, "app_auth_accounts", id, sid);
    deletedAccountIds.push(id);
  }
  for (const id of secretIds) {
    await deleteDoc(sb, "auth_secrets", id, sid);
    deletedSecretIds.push(id);
  }
  return { deletedAccountIds, deletedSecretIds };
}

export async function queryDocs(
  sb: SupabaseClient,
  collection: string,
  filters: Array<{ column: string; op: string; value: unknown }> = [],
  limit = 50,
): Promise<Array<{ id: string; data: Record<string, unknown> }>> {
  // Prefer JSON filters via RPC-less postgrest: filter school_id when present.
  let q = sb.from("app_documents").select("doc_id, data, school_id").eq(
    "collection",
    collection,
  );
  for (const f of filters) {
    if (f.column === "schoolId" && f.op === "eq") {
      q = q.eq("school_id", String(f.value));
    }
  }
  q = q.limit(limit);
  const { data, error } = await q;
  if (error) throw error;

  let rows = (data || []).map((row) => ({
    id: row.doc_id as string,
    data: { ...(row.data as Record<string, unknown>) },
  }));

  for (const f of filters) {
    if (f.column === "schoolId") continue;
    rows = rows.filter((r) => {
      const v = r.data[f.column];
      if (f.op === "eq") return v === f.value;
      return true;
    });
  }
  return rows;
}

export function profileFromAccount(
  username: string,
  data: Record<string, unknown>,
) {
  return {
    username: (data.username as string) || username,
    roleKey: data.roleKey as string,
    email: (data.email as string) || null,
    phone: (data.phone as string) || null,
    schoolId: (data.schoolId as string) || null,
    fullName: (data.fullName as string) || null,
    linkedStudentIds: (data.linkedStudentIds as string[]) || [],
    linkedTeacherId: (data.linkedTeacherId as string) || null,
    linkedAdminId: (data.linkedAdminId as string) || null,
    linkedDriverId: (data.linkedDriverId as string) || null,
    linkedStudentId: (data.linkedStudentId as string) || null,
    assignedClass: (data.assignedClass as string) || "",
    assignedClassNames: Array.isArray(data.assignedClassNames)
      ? (data.assignedClassNames as string[])
      : [],
    classAssignments: Array.isArray(data.classAssignments)
      ? data.classAssignments
      : [],
    mustChangePassword: !!data.mustChangePassword,
    staffRoles: normalizeStaffRoles(data.staffRoles),
    staffPermissions: Array.isArray(data.staffPermissions)
      ? data.staffPermissions.map((p) => String(p || "")).filter(Boolean)
      : [],
    claimsVersion: Number(data.claimsVersion) || 0,
  };
}

export function claimsFor(profile: Record<string, unknown>) {
  const staffRoles = normalizeStaffRoles(profile.staffRoles);
  return {
    role: profile.roleKey,
    // Always uppercase so RLS school_id checks match client writes.
    schoolId: String(profile.schoolId || "").trim().toUpperCase(),
    username: normalizeUsername(profile.username),
    linkedStudentId: profile.linkedStudentId || "",
    linkedTeacherId: profile.linkedTeacherId || "",
    linkedDriverId: profile.linkedDriverId || "",
    linkedStudentIds: uniqueStrings(profile.linkedStudentIds || []),
    linkedClassNames: uniqueStrings(profile.linkedClassNames || []),
    linkedStudentNames: uniqueStrings(profile.linkedStudentNames || []),
    assignedClassNames: uniqueStrings(profile.assignedClassNames || []),
    // RBAC: combined permission set of all staff roles. The admin (school
    // owner) role is treated as all-permissions directly in SQL/UI, so its
    // claims stay small.
    staffRoles,
    permissions: permissionsFromProfile(profile),
    claimsVersion: Number(profile.claimsVersion) || 0,
  };
}

/**
 * Blocks login for schools that are inactive, suspended, or past their
 * subscription expiry. Platform-owner management happens outside RBAC, so
 * nobody (including the school admin) can sign in to a blocked school.
 */
export async function assertSchoolAccessible(
  sb: SupabaseClient,
  schoolId: string,
): Promise<Record<string, unknown> | null> {
  const school = await getDoc(sb, "school_registry", schoolId);
  if (!school) return null; // Legacy schools without a registry doc stay usable.
  const status = String(school.status || "active").toLowerCase();
  if (status !== "active") {
    throw new Error("school_blocked");
  }
  const expiresRaw = school.subscriptionExpiresAt;
  if (typeof expiresRaw === "string" && expiresRaw) {
    const expires = Date.parse(expiresRaw);
    if (!Number.isNaN(expires) && Date.now() > expires) {
      throw new Error("school_blocked");
    }
  }
  return school;
}

export function syntheticEmail(username: string, schoolId: string): string {
  const u = normalizeUsername(username).replace(/[^a-z0-9._+-]/g, "_");
  // Domain labels only allow letters, digits, and interior hyphens.
  const s = String(schoolId || "school")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 63) || "school";
  return `${u}@${s}.mayabela.local`;
}

export function clientIp(req: Request): string {
  return (
    req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-real-ip") ||
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    "unknown"
  );
}

export async function assertNotRateLimited(
  sb: SupabaseClient,
  bucketKey: string,
  limit: number = LOGIN_RATE_LIMIT,
  windowMs: number = LOGIN_RATE_WINDOW_MS,
): Promise<void> {
  const { data, error } = await sb.rpc("auth_rate_limit_hit", {
    p_bucket_key: bucketKey,
    p_limit: limit,
    p_window_ms: windowMs,
  });
  if (error) throw error;
  if (data !== true) {
    throw new Error("rate_limited");
  }
}

export async function assertPlatformOwnerCallAllowed(
  sb: SupabaseClient,
  req: Request,
): Promise<void> {
  const ip = clientIp(req);
  await assertNotRateLimited(
    sb,
    `platform_pin_check_${ip}`,
    PLATFORM_PIN_CHECK_LIMIT,
    PLATFORM_AUTHED_RATE_WINDOW_MS,
  );
}

export async function assertPlatformAuthedRateLimit(
  sb: SupabaseClient,
  req: Request,
  operation: string,
): Promise<void> {
  await assertNotRateLimited(
    sb,
    `${operation}_${clientIp(req)}`,
    PLATFORM_AUTHED_RATE_LIMIT,
    PLATFORM_AUTHED_RATE_WINDOW_MS,
  );
}

export async function verifySecret(
  plain: string,
  secretData: Record<string, unknown> | null,
  legacyPassword: unknown,
): Promise<boolean> {
  if (secretData && typeof secretData.passwordHash === "string") {
    return await bcryptCompare(plain, secretData.passwordHash as string);
  }
  if (legacyPassword == null || legacyPassword === "") return false;
  if (
    typeof legacyPassword === "string" &&
    legacyPassword.startsWith("sha256:")
  ) {
    return await verifyLegacySha256(plain, legacyPassword);
  }
  return plain === legacyPassword;
}

async function verifyLegacySha256(plain: string, stored: string): Promise<boolean> {
  const body = stored.slice("sha256:".length);
  const parts = body.split(":");
  if (parts.length !== 2) return false;
  const enc = new TextEncoder();
  const digest = await crypto.subtle.digest(
    "SHA-256",
    enc.encode(`${parts[0]}::${plain}`),
  );
  const hex = [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return hex === parts[1];
}

// bcryptjs is CommonJS: its API lives on the default export when loaded via esm.sh.
import bcryptModule from "https://esm.sh/bcryptjs@2.4.3";

// deno-lint-ignore no-explicit-any
const bcrypt: any = (bcryptModule as any).default ?? bcryptModule;

export async function bcryptHash(plain: string): Promise<string> {
  return bcrypt.hashSync(plain, BCRYPT_ROUNDS);
}

export async function bcryptCompare(plain: string, hash: string): Promise<boolean> {
  return bcrypt.compareSync(plain, hash);
}

export async function upsertSecret(
  sb: SupabaseClient,
  username: string,
  plainPassword: string,
  schoolId?: string | null,
): Promise<void> {
  const passwordHash = await bcryptHash(plainPassword);
  const sid = String(schoolId || "").trim().toUpperCase();
  const key = normalizeUsername(username);
  const docId = sid ? accountDocId(sid, key) : key;
  const existing = await loadSecret(sb, key, sid, docId);
  await upsertDoc(sb, "auth_secrets", docId, {
    ...(existing || {}),
    passwordHash,
    username: key,
    schoolId: sid || null,
    updatedAt: new Date().toISOString(),
  }, sid || null);
}

export async function loadSecret(
  sb: SupabaseClient,
  username: string,
  schoolId?: string | null,
  accountDocIdHint?: string | null,
): Promise<Record<string, unknown> | null> {
  const key = normalizeUsername(username);
  const sid = String(schoolId || "").trim().toUpperCase();
  if (accountDocIdHint) {
    const byHint = await getDoc(sb, "auth_secrets", accountDocIdHint, sid || null);
    if (byHint) return byHint;
  }
  if (sid) {
    const composite = await getDoc(sb, "auth_secrets", accountDocId(sid, key), sid);
    if (composite) return composite;
  }
  return await getDoc(sb, "auth_secrets", key);
}

function generateSessionPassword(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return "Sx1!" + btoa(String.fromCharCode(...bytes)).replace(/[+/=]/g, "x");
}

function claimsEqual(
  prev: Record<string, unknown> | null | undefined,
  next: Record<string, unknown>,
): boolean {
  if (!prev) return false;
  const keys = [
    "role",
    "schoolId",
    "username",
    "linkedStudentId",
    "linkedTeacherId",
    "linkedDriverId",
    "claimsVersion",
  ];
  for (const key of keys) {
    if (String(prev[key] ?? "") !== String(next[key] ?? "")) return false;
  }
  const listKeys = [
    "linkedStudentIds",
    "linkedClassNames",
    "linkedStudentNames",
    "assignedClassNames",
    "staffRoles",
    "permissions",
  ];
  for (const key of listKeys) {
    const a = uniqueStrings(prev[key] || []).slice().sort().join("\n");
    const b = uniqueStrings(next[key] || []).slice().sort().join("\n");
    if (a !== b) return false;
  }
  return true;
}

async function persistAuthBinding(
  sb: SupabaseClient,
  username: string,
  schoolId: string,
  binding: { authUserId: string; sessionPassword: string },
  existing?: Record<string, unknown> | null,
): Promise<void> {
  const sid = String(schoolId || "").trim().toUpperCase();
  const key = normalizeUsername(username);
  const docId = sid ? accountDocId(sid, key) : key;
  const current = existing || await loadSecret(sb, key, sid, docId);
  if (
    current &&
    current.authUserId === binding.authUserId &&
    current.sessionPassword === binding.sessionPassword
  ) {
    return;
  }
  await upsertDoc(sb, "auth_secrets", docId, {
    ...(current || {}),
    username: key,
    schoolId: sid || null,
    authUserId: binding.authUserId,
    sessionPassword: binding.sessionPassword,
    updatedAt: new Date().toISOString(),
  }, sid || null);
}

/**
 * Ensures a GoTrue user exists and returns a password that can be used with
 * signInWithPassword. The school password is never used for Auth.
 *
 * Warm path (typical login): reuse stored authUserId + sessionPassword and
 * skip Auth admin writes when claims are unchanged.
 */
export async function ensureAuthUser(
  sb: SupabaseClient,
  username: string,
  _password: string,
  profile: Record<string, unknown>,
  options: {
    secret?: Record<string, unknown> | null;
    forceRotate?: boolean;
    /** Skip Auth admin I/O when a session binding already exists (login hot path). */
    reuseSession?: boolean;
  } = {},
): Promise<{
  email: string;
  claims: Record<string, unknown>;
  sessionPassword: string;
  authUserId: string;
}> {
  const claims = claimsFor(profile);
  const schoolId = String(profile.schoolId || "").trim().toUpperCase();
  const email = syntheticEmail(username, schoolId);
  const secret = options.secret === undefined
    ? await loadSecret(sb, username, schoolId)
    : options.secret;
  let authUserId = String(secret?.authUserId || "").trim();
  let sessionPassword = String(secret?.sessionPassword || "");

  if (
    authUserId &&
    sessionPassword &&
    !options.forceRotate &&
    options.reuseSession
  ) {
    return { email, claims, sessionPassword, authUserId };
  }

  if (!authUserId) {
    const found = await findAuthUserByEmail(sb, email);
    if (found) authUserId = found.id;
  }
  if (!authUserId) {
    const extra = String(profile.email || "").trim().toLowerCase();
    if (extra && extra !== email) {
      const byReal = await findAuthUserByEmail(sb, extra);
      if (byReal) authUserId = byReal.id;
    }
  }

  if (!sessionPassword || options.forceRotate) {
    sessionPassword = generateSessionPassword();
  }

  const userMeta = {
    fullName: profile.fullName,
    username,
  };

  if (authUserId) {
    const shouldSetPassword = options.forceRotate || !secret?.sessionPassword;
    if (!shouldSetPassword) {
      const { data } = await sb.auth.admin.getUserById(authUserId);
      if (!claimsEqual(data.user?.app_metadata as Record<string, unknown>, claims)) {
        const { error } = await sb.auth.admin.updateUserById(authUserId, {
          app_metadata: claims,
          user_metadata: userMeta,
          email_confirm: true,
        });
        if (error) throw error;
      }
      await persistAuthBinding(
        sb,
        username,
        schoolId,
        { authUserId, sessionPassword },
        secret,
      );
      return { email, claims, sessionPassword, authUserId };
    }
    const { error } = await sb.auth.admin.updateUserById(authUserId, {
      password: sessionPassword,
      app_metadata: claims,
      user_metadata: userMeta,
      email_confirm: true,
    });
    if (error) throw error;
  } else {
    const { data, error } = await sb.auth.admin.createUser({
      email,
      password: sessionPassword,
      email_confirm: true,
      app_metadata: claims,
      user_metadata: userMeta,
    });
    if (error) {
      const already = /already (been )?registered|email_exists|already exists/i
        .test(error.message || "");
      const raced = await findAuthUserByEmail(sb, email);
      if (!raced) {
        if (already) {
          throw new Error(
            "This admin email is already on the account. Try logging in with the password you just saved.",
          );
        }
        throw error;
      }
      authUserId = raced.id;
      const { error: updErr } = await sb.auth.admin.updateUserById(authUserId, {
        password: sessionPassword,
        app_metadata: claims,
        user_metadata: userMeta,
        email_confirm: true,
      });
      if (updErr) throw updErr;
    } else if (!data.user) {
      throw new Error("Failed to create auth user.");
    } else {
      authUserId = data.user.id;
    }
  }

  await persistAuthBinding(
    sb,
    username,
    schoolId,
    { authUserId, sessionPassword },
    secret,
  );
  return { email, claims, sessionPassword, authUserId };
}

async function findAuthUserByEmail(
  sb: SupabaseClient,
  email: string,
): Promise<{ id: string } | null> {
  const target = email.trim().toLowerCase();
  if (!target) return null;

  const url = (Deno.env.get("SUPABASE_URL") || "").replace(/\/$/, "");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (url && key) {
    const res = await fetch(
      `${url}/auth/v1/admin/users?email=${encodeURIComponent(target)}&page=1&per_page=50`,
      { headers: { Authorization: `Bearer ${key}`, apikey: key } },
    );
    if (res.ok) {
      const body = await res.json();
      const users = Array.isArray(body?.users)
        ? body.users
        : Array.isArray(body)
        ? body
        : [];
      const hit = users.find((u: { email?: string; id?: string }) =>
        (u.email || "").toLowerCase() === target
      );
      if (hit?.id) return { id: String(hit.id) };
    }
  }

  for (let page = 1; page <= 25; page++) {
    const { data, error } = await sb.auth.admin.listUsers({
      page,
      perPage: 200,
    });
    if (error) break;
    const users = data?.users || [];
    const hit = users.find((u) => (u.email || "").toLowerCase() === target);
    if (hit?.id) return { id: hit.id };
    if (users.length < 200) break;
  }
  return null;
}

export function classNamesFromTeacherData(data: Record<string, unknown> | null): string[] {
  const names: string[] = [];
  if (!data) return names;
  if (typeof data.assignedClass === "string") {
    for (const part of data.assignedClass.split(",")) names.push(part.trim());
  }
  if (Array.isArray(data.assignedClassNames)) {
    names.push(...(data.assignedClassNames as string[]));
  }
  if (Array.isArray(data.classAssignments)) {
    for (const row of data.classAssignments as Array<Record<string, unknown>>) {
      if (row?.className) names.push(String(row.className));
    }
  }
  return uniqueStrings(names);
}

export async function enrichAccessProfile(
  sb: SupabaseClient,
  profile: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const enriched: Record<string, unknown> = {
    ...profile,
    linkedStudentIds: uniqueStrings(profile.linkedStudentIds || []),
    linkedClassNames: uniqueStrings(profile.linkedClassNames || []),
    linkedStudentNames: uniqueStrings(profile.linkedStudentNames || []),
    assignedClassNames: uniqueStrings(profile.assignedClassNames || []),
  };

  const username = normalizeUsername(enriched.username);
  const schoolId = String(enriched.schoolId || "").trim();
  const roleKey = enriched.roleKey;

  if (roleKey === "parent" && username) {
    const ids = new Set(
      ((enriched.linkedStudentIds as string[]) || []).map((id) =>
        String(id).trim().toUpperCase()
      ),
    );
    const hasClassNames =
      ((enriched.linkedClassNames as string[]) || []).length > 0;
    // Skip a full parent_link_requests scan when the account already has
    // linked students (typical after first successful login).
    if (ids.size === 0) {
      const links = await queryDocs(sb, "parent_link_requests", [
        { column: "schoolId", op: "eq", value: schoolId },
      ], 200);
      for (const doc of links) {
        if (doc.data.parentUsername !== username) continue;
        if (doc.data.status !== "approved") continue;
        const studentId = String(doc.data.studentId || "").trim().toUpperCase();
        if (studentId) ids.add(studentId);
      }
    }
    enriched.linkedStudentIds = uniqueStrings([...ids]);

    if (!hasClassNames || !((enriched.linkedStudentNames as string[]) || []).length) {
      const classNames = new Set<string>(
        (enriched.linkedClassNames as string[]) || [],
      );
      const studentNames = new Set<string>(
        (enriched.linkedStudentNames as string[]) || [],
      );
      for (const studentId of enriched.linkedStudentIds as string[]) {
        const stu = await getDoc(sb, "student_registry", studentId, schoolId);
        if (!stu) continue;
        if (schoolId && stu.schoolId && stu.schoolId !== schoolId) continue;
        if (stu.className) classNames.add(String(stu.className).trim());
        const fullName = String(stu.fullName || stu.name || "").trim();
        if (fullName) studentNames.add(fullName);
      }
      enriched.linkedClassNames = uniqueStrings([...classNames]);
      enriched.linkedStudentNames = uniqueStrings([...studentNames]);
    }
  }

  if (roleKey === "teacher") {
    const names = new Set<string>(
      ((enriched.assignedClassNames as string[]) || []).map((n) => String(n).trim()),
    );
    for (const name of classNamesFromTeacherData(profile)) {
      if (name) names.add(name);
    }
    const teacherId = String(enriched.linkedTeacherId || "").trim().toUpperCase();
    if (teacherId) {
      const tea = await getDoc(sb, "teacher_registry", teacherId, schoolId);
      if (tea && (!schoolId || !tea.schoolId || tea.schoolId === schoolId)) {
        for (const name of classNamesFromTeacherData(tea)) {
          if (name) names.add(name);
        }
      }
    }
    enriched.assignedClassNames = uniqueStrings([...names]);
  }

  if (roleKey === "student" && enriched.linkedStudentId) {
    enriched.linkedStudentIds = uniqueStrings([enriched.linkedStudentId]);
  }

  return enriched;
}

export async function findAccountDoc(
  sb: SupabaseClient,
  identifier: string,
  roleKey: string,
  schoolId?: string | null,
): Promise<{ id: string; data: Record<string, unknown> } | null> {
  const key = normalizeUsername(identifier);
  const sid = String(schoolId || "").trim().toUpperCase();

  const roleOk = (data: Record<string, unknown>) =>
    !roleKey || data.roleKey === roleKey;

  // Prefer school-scoped account ids: SCHOOLID__username
  if (sid) {
    const compositeId = accountDocId(sid, key);
    const composite = await getDoc(sb, "app_auth_accounts", compositeId, sid);
    if (composite && roleOk(composite)) {
      return { id: compositeId, data: composite };
    }

    const inSchool = await queryDocs(
      sb,
      "app_auth_accounts",
      [{ column: "schoolId", op: "eq", value: sid }],
      500,
    );
    for (const doc of inSchool) {
      const uname = normalizeUsername(doc.data.username || doc.id);
      if (uname === key && roleOk(doc.data)) {
        return { id: doc.id, data: doc.data };
      }
      if (normalizeEmail(doc.data.email) === key && roleOk(doc.data)) {
        return { id: doc.id, data: doc.data };
      }
      if (
        roleKey === "student" &&
        String(doc.data.linkedStudentId || "").toUpperCase() ===
          String(identifier).trim().toUpperCase()
      ) {
        return { id: doc.id, data: doc.data };
      }
    }

    // Legacy global phone doc — only if it belongs to this school.
    const legacy = await getDoc(sb, "app_auth_accounts", key, sid);
    if (
      legacy &&
      roleOk(legacy) &&
      String(legacy.schoolId || "").trim().toUpperCase() === sid
    ) {
      return { id: key, data: legacy };
    }
    return null;
  }

  const direct = await getDoc(sb, "app_auth_accounts", key);
  if (direct && roleOk(direct)) {
    return { id: key, data: direct };
  }

  const snap = await queryDocs(sb, "app_auth_accounts", [], 500);
  for (const doc of snap) {
    const data = doc.data;
    const uname = normalizeUsername(data.username || doc.id);
    if (uname === key && roleOk(data)) {
      return { id: doc.id, data };
    }
    if (normalizeEmail(data.email) === key && roleOk(data)) {
      return { id: doc.id, data };
    }
  }

  if (roleKey === "student") {
    const studentId = String(identifier).trim().toUpperCase();
    for (const doc of snap) {
      if (String(doc.data.linkedStudentId || "").toUpperCase() === studentId) {
        return { id: doc.id, data: doc.data };
      }
    }
  }

  return null;
}

export async function findAccountByEmail(
  sb: SupabaseClient,
  schoolId: string,
  email: string,
  roleKey?: string | null,
): Promise<{ id: string; data: Record<string, unknown> } | null> {
  const target = normalizeEmail(email);
  const sid = String(schoolId || "").trim().toUpperCase();
  if (!target || !sid) return null;

  const inSchool = await queryDocs(
    sb,
    "app_auth_accounts",
    [{ column: "schoolId", op: "eq", value: sid }],
    500,
  );
  for (const doc of inSchool) {
    if (normalizeEmail(doc.data.email) !== target) continue;
    if (roleKey && doc.data.roleKey !== roleKey) continue;
    return { id: doc.id, data: doc.data };
  }
  return null;
}

/** School-scoped account document id (avoids cross-school phone collisions). */
export function accountDocId(schoolId: string, username: string): string {
  const sid = String(schoolId || "").trim().toUpperCase();
  const key = normalizeUsername(username);
  return `${sid}__${key}`;
}

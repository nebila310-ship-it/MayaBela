/**
 * Resolve the signed-in caller of an edge function from its Supabase JWT.
 * Authorization data comes from app_metadata only (server-written).
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export type Caller = {
  userId: string;
  role: string;
  schoolId: string;
  username: string;
  permissions: string[];
};

export function callerFromAppMetadata(
  userId: string,
  meta: Record<string, unknown> | null | undefined,
): Caller {
  const m = meta || {};
  return {
    userId,
    role: String(m.role || "").trim(),
    schoolId: String(m.schoolId || "").trim().toUpperCase(),
    username: String(m.username || "").trim().toLowerCase(),
    permissions: Array.isArray(m.permissions)
      ? (m.permissions as unknown[]).map((p) => String(p))
      : [],
  };
}

/** School staff (admin or any staff role) of the given school. */
export function isSchoolStaffOf(caller: Caller | null, schoolId: string): boolean {
  if (!caller) return false;
  const sid = String(schoolId || "").trim().toUpperCase();
  if (!sid || caller.schoolId !== sid) return false;
  return caller.role === "admin" || caller.role === "teacher";
}

export async function resolveCaller(req: Request): Promise<Caller | null> {
  const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return null;
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    anon || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
  const { data, error } = await client.auth.getUser(jwt);
  if (error || !data.user) return null;
  return callerFromAppMetadata(
    data.user.id,
    data.user.app_metadata as Record<string, unknown>,
  );
}

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  deleteAccountAndSecrets,
  normalizeUsername,
} from "../_shared/school_auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const username = normalizeUsername(body?.username);
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();

    if (!username || !schoolId) {
      return errorResponse(
        "username and schoolId are required.",
        400,
        "invalid",
      );
    }

    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      anon || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        global: {
          headers: jwt ? { Authorization: `Bearer ${jwt}` } : {},
        },
      },
    );

    const { data: userData, error: userErr } = jwt
      ? await authClient.auth.getUser(jwt)
      : await authClient.auth.getUser();
    const caller = userData.user;
    const meta = (caller?.app_metadata || {}) as Record<string, unknown>;
    const callerRole = String(meta.role || "").trim();
    const callerSchool = String(meta.schoolId || "").trim().toUpperCase();
    const callerPerms = Array.isArray(meta.permissions)
      ? (meta.permissions as unknown[]).map((p) => String(p))
      : [];
    const canManageStaff =
      !!caller &&
      callerSchool === schoolId &&
      (callerRole === "admin" ||
        callerPerms.includes("manage_staff_accounts"));

    if (!canManageStaff) {
      return errorResponse(
        !caller
          ? `Admin sign-in required (no cloud session${userErr ? `: ${userErr.message}` : ""}).`
          : `Permission denied (role=${callerRole || "none"}, school=${callerSchool || "none"}).`,
        403,
        "denied",
      );
    }

    const sb = adminClient();
    const result = await deleteAccountAndSecrets(sb, username, schoolId);
    return jsonResponse({
      ok: true,
      ...result,
    });
  } catch (e) {
    return errorResponse(
      e instanceof Error ? e.message : String(e),
      500,
      "server",
    );
  }
});

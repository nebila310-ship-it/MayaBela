import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  MIN_PASSWORD_LENGTH,
  accountDocId,
  adminClient,
  findAccountDoc,
  loadSecret,
  normalizeUsername,
  upsertSecret,
  verifySecret,
} from "../_shared/school_auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const authHeader = req.headers.get("Authorization") || "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData } = await userClient.auth.getUser();
    const user = userData.user;
    if (!user) return errorResponse("Sign in required.", 401, "unauthenticated");

    const meta = (user.app_metadata || {}) as Record<string, unknown>;
    const body = await req.json();
    const newPassword = body?.newPassword;
    if (typeof newPassword !== "string" || newPassword.length < MIN_PASSWORD_LENGTH) {
      return errorResponse(
        `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
        400,
        "invalid",
      );
    }

    const callerUsername = normalizeUsername(meta.username);
    const targetUsername = normalizeUsername(body?.username || meta.username);
    const callerSchool = String(meta.schoolId || "").trim().toUpperCase();
    const isSelf = targetUsername === callerUsername;
    const isAdmin = meta.role === "admin" && !!callerSchool;
    if (!isSelf && !isAdmin) {
      return errorResponse("Cannot change another user's password.", 403, "denied");
    }

    const sb = adminClient();
    const found = await findAccountDoc(
      sb,
      targetUsername,
      String(meta.role || ""),
      callerSchool || null,
    );
    if (!found) return errorResponse("Account not found.", 404, "not_found");
    const account = found.data;
    const accountSchool = String(account.schoolId || "").trim().toUpperCase();
    if (isAdmin && !isSelf && accountSchool !== callerSchool) {
      return errorResponse("Cross-school password reset denied.", 403, "denied");
    }

    if (isSelf && body?.currentPassword) {
      const secret = await loadSecret(
        sb,
        targetUsername,
        accountSchool,
        found.id,
      );
      const ok = await verifySecret(
        body.currentPassword,
        secret,
        account.password,
      );
      if (!ok) {
        return errorResponse("Current password is incorrect.", 403, "denied");
      }
    }

    await upsertSecret(sb, targetUsername, newPassword, accountSchool);
    account.mustChangePassword = false;
    account.updatedAt = new Date().toISOString();
    delete account.password;
    delete account.passwordHash;
    const docId = accountSchool
      ? accountDocId(accountSchool, targetUsername)
      : targetUsername;
    await sb.from("app_documents").upsert({
      collection: "app_auth_accounts",
      doc_id: docId,
      school_id: accountSchool || null,
      data: account,
      updated_at: new Date().toISOString(),
    }, { onConflict: "collection,school_id,doc_id" });

    return jsonResponse({ ok: true });
  } catch (e) {
    console.error(e);
    return errorResponse(String(e?.message || e), 500);
  }
});

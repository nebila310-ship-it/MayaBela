import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  accountDocId,
  adminClient,
  claimsFor,
  enrichAccessProfile,
  ensureAuthUser,
  findAccountDoc,
  getDoc,
  normalizeUsername,
  profileFromAccount,
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
    if (!user) return errorResponse("Sign in required.", 401);

    const meta = (user.app_metadata || {}) as Record<string, unknown>;
    const body = await req.json().catch(() => ({}));
    const callerUsername = normalizeUsername(meta.username);
    const targetUsername = normalizeUsername(body?.username || meta.username);
    const isSelf = targetUsername === callerUsername;
    const schoolId = String(meta.schoolId || "").trim().toUpperCase();
    const isAdmin = meta.role === "admin" && !!schoolId;
    if (!isSelf && !isAdmin) {
      return errorResponse("Cannot refresh another user's access claims.", 403);
    }

    const sb = adminClient();
    // Prefer school-scoped account ids (SCHOOL__username); fall back to legacy.
    let account: Record<string, unknown> | null = null;
    let accountId = targetUsername;
    if (schoolId) {
      // Empty roleKey = match any role (admin may refresh another account).
      const found = await findAccountDoc(
        sb,
        targetUsername,
        isSelf ? String(meta.role || "") : "",
        schoolId,
      );
      if (found) {
        account = found.data;
        accountId = found.id;
      } else {
        const scoped = await getDoc(
          sb,
          "app_auth_accounts",
          accountDocId(schoolId, targetUsername),
          schoolId,
        );
        if (scoped) {
          account = scoped;
          accountId = accountDocId(schoolId, targetUsername);
        }
      }
    }
    if (!account) {
      account = await getDoc(sb, "app_auth_accounts", targetUsername, schoolId);
      accountId = targetUsername;
    }
    if (!account) return errorResponse("Account not found.", 404);

    const accountSchool = String(account.schoolId || schoolId || "")
      .trim()
      .toUpperCase();
    if (isAdmin && !isSelf && accountSchool !== schoolId) {
      return errorResponse("Cross-school access denied.", 403);
    }

    const profile = profileFromAccount(targetUsername, account);
    const accessProfile = await enrichAccessProfile(
      sb,
      profile as Record<string, unknown>,
    );

    let refresh_token: string | null = null;
    let access_token: string | null = null;
    if (isSelf) {
      // Re-apply metadata and mint a fresh session so the client JWT includes
      // role + schoolId without requiring a full sign-out.
      const { email, sessionPassword } = await ensureAuthUser(
        sb,
        targetUsername,
        "refresh",
        accessProfile,
      );
      const { data: sessionData, error: sessionError } = await sb.auth
        .signInWithPassword({
          email,
          password: sessionPassword,
        });
      if (sessionError || !sessionData.session) {
        // Fallback: metadata is updated; client can refreshSession().
        await sb.auth.admin.updateUserById(user.id, {
          app_metadata: claimsFor(accessProfile),
        }).catch(() => null);
      } else {
        refresh_token = sessionData.session.refresh_token;
        access_token = sessionData.session.access_token;
      }
    }

    return jsonResponse({
      ok: true,
      refresh_token,
      access_token,
      profile: {
        ...profileFromAccount(targetUsername, account),
        id: accountId,
        linkedStudentIds: accessProfile.linkedStudentIds,
        linkedClassNames: accessProfile.linkedClassNames,
        linkedStudentNames: accessProfile.linkedStudentNames,
        assignedClassNames: accessProfile.assignedClassNames,
      },
    });
  } catch (e) {
    console.error(e);
    return errorResponse(String(e?.message || e), 500);
  }
});

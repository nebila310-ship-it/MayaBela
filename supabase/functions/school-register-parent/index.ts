import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  MIN_PASSWORD_LENGTH,
  accountDocId,
  adminClient,
  assertNotRateLimited,
  ensureAuthUser,
  getDoc,
  normalizeEmail,
  normalizeUsername,
  profileFromAccount,
  upsertSecret,
} from "../_shared/school_auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const username = normalizeUsername(body?.username || body?.phone);
    const password = body?.password;
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    const phone = body?.phone || null;
    const fullName = body?.fullName || null;
    const email = normalizeEmail(body?.email);

    if (!username || !schoolId) {
      return errorResponse("username/phone and schoolId are required.", 400);
    }
    if (!email) {
      return errorResponse("A valid email is required.", 400, "invalid_email");
    }
    if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH) {
      return errorResponse(
        `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
        400,
      );
    }

    const sb = adminClient();
    await assertNotRateLimited(sb, `register_${username}_${schoolId}`);

    const school = await getDoc(sb, "school_registry", schoolId);
    if (!school) return errorResponse("School not found.", 404, "not_found");

    const existingComposite = await getDoc(
      sb,
      "app_auth_accounts",
      accountDocId(schoolId, username),
    );
    const legacy = await getDoc(sb, "app_auth_accounts", username, schoolId);
    const legacySameSchool = legacy &&
        String(legacy.schoolId || "").trim().toUpperCase() === schoolId
      ? legacy
      : null;
    if (existingComposite || legacySameSchool) {
      return errorResponse("Account already exists.", 409, "exists");
    }

    await upsertSecret(sb, username, password, schoolId);
    // Never trust client-supplied student links at registration time.
    // Links are granted only after an approved parent_link_request / staff action.
    const profile = {
      username,
      roleKey: "parent",
      schoolId,
      email,
      phone,
      fullName,
      linkedStudentIds: [] as string[],
      mustChangePassword: false,
      updatedAt: new Date().toISOString(),
    };
    await sb.from("app_documents").upsert({
      collection: "app_auth_accounts",
      doc_id: accountDocId(schoolId, username),
      school_id: schoolId,
      data: profile,
      updated_at: new Date().toISOString(),
    }, { onConflict: "collection,school_id,doc_id" });
    await ensureAuthUser(sb, username, password, profile);

    return jsonResponse({
      ok: true,
      profile: profileFromAccount(username, profile),
    });
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse("Too many attempts. Try again later.", 429);
    }
    console.error(e);
    return errorResponse(msg, 500);
  }
});

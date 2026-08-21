import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  MIN_PASSWORD_LENGTH,
  accountDocId,
  adminClient,
  ensureAuthUser,
  enrichAccessProfile,
  getDoc,
  normalizeEmail,
  normalizeUsername,
  profileFromAccount,
  upsertDoc,
  upsertSecret,
} from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";

/**
 * Platform-owner school onboarding.
 * Uses the service role so create works without a school-scoped JWT
 * (owner console has none). Requires plaintext owner PIN.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const sb = adminClient();
    await authorizePlatformOwner(sb, req, body?.ownerPin);

    const schoolRaw = body?.school;
    if (!schoolRaw || typeof schoolRaw !== "object") {
      return errorResponse("school payload is required.", 400, "invalid");
    }
    const school = { ...(schoolRaw as Record<string, unknown>) };
    const schoolId = String(school.id || body?.schoolId || "")
      .trim()
      .toUpperCase();
    const name = String(school.name || "").trim();
    if (!schoolId || schoolId.length < 3) {
      return errorResponse("Invalid school id.", 400, "invalid");
    }
    if (!name) {
      return errorResponse("School name is required.", 400, "invalid");
    }

    const already = await getDoc(sb, "school_registry", schoolId);
    if (already) {
      return errorResponse(
        `School ID ${schoolId} already exists in cloud.`,
        409,
        "school_exists",
      );
    }

    const username = normalizeUsername(body?.adminUsername);
    const password = body?.password;
    const fullName = String(body?.adminFullName || "").trim();
    const phone = String(body?.adminPhone || "").trim();
    const email = normalizeEmail(body?.adminEmail);

    if (!username) {
      return errorResponse("adminUsername is required.", 400, "invalid");
    }
    if (!email) {
      return errorResponse("A valid admin email is required.", 400, "invalid_email");
    }
    if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH) {
      return errorResponse(
        `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
        400,
        "password_too_short",
      );
    }

    const now = new Date().toISOString();
    school.id = schoolId;
    school.name = name;
    school.updatedAt = now;
    if (!school.registeredAt) school.registeredAt = now;
    if (!school.status) school.status = "active";
    if (phone) school.adminContactPhone = phone;
    if (fullName) school.adminFullName = fullName;
    delete school.adminInitialPassword;
    delete school.password;
    delete school.passwordHash;

    await upsertDoc(sb, "school_registry", schoolId, school, schoolId);

    const docId = accountDocId(schoolId, username);
    const profile = {
      username,
      roleKey: "admin",
      schoolId,
      email: email,
      phone: phone || null,
      fullName: fullName || null,
      linkedStudentIds: [],
      linkedTeacherId: null,
      linkedAdminId: null,
      linkedDriverId: null,
      linkedStudentId: null,
      mustChangePassword: !!body?.mustChangePassword,
      staffRoles: [],
      staffPermissions: [],
      claimsVersion: 0,
      updatedAt: now,
    };

    await upsertSecret(sb, username, password, schoolId);

    const { error: accountErr } = await sb.from("app_documents").upsert({
      collection: "app_auth_accounts",
      doc_id: docId,
      school_id: schoolId,
      data: profile,
      updated_at: now,
    }, { onConflict: "collection,school_id,doc_id" });
    if (accountErr) {
      // Best-effort rollback so a half-created school is not left dangling.
      try {
        await sb
          .from("app_documents")
          .delete()
          .eq("collection", "school_registry")
          .eq("doc_id", schoolId);
      } catch (_) {
        /* ignore */
      }
      return errorResponse(
        `Admin account save failed: ${accountErr.message}`,
        500,
        "invalid",
      );
    }

    const accessProfile = await enrichAccessProfile(sb, profile);
    try {
      await ensureAuthUser(sb, username, password, accessProfile);
    } catch (authErr) {
      return errorResponse(
        `Auth user failed: ${String((authErr as Error)?.message || authErr)}`,
        500,
        "invalid",
      );
    }

    return jsonResponse({
      ok: true,
      schoolId,
      school,
      profile: profileFromAccount(username, profile),
    });
  } catch (e) {
    const msg = String((e as Error)?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse(
        "Too many attempts. Try again later.",
        429,
        "rate_limited",
      );
    }
    if (msg.includes("owner_pin")) {
      return errorResponse("Owner PIN required.", 401, "unauthorized");
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

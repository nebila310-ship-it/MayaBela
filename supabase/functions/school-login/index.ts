import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  ROLES,
  accountDocId,
  adminClient,
  assertNotRateLimited,
  assertSchoolAccessible,
  ensureAuthUser,
  enrichAccessProfile,
  ethiopianLoginKey,
  findAccountDoc,
  loadSecret,
  normalizeUsername,
  permissionsForRoles,
  permissionsFromProfile,
  profileFromAccount,
  upsertSecret,
  verifySecret,
  normalizeStaffRoles,
} from "../_shared/school_auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const usernameInput = body?.username;
    const password = body?.password;
    const roleKey = body?.roleKey;
    const schoolIdInput = String(body?.schoolId || "").trim().toUpperCase();

    if (!usernameInput || !password || !roleKey) {
      return errorResponse(
        "username, password, and roleKey are required.",
        400,
        "invalid",
      );
    }
    if (!ROLES.has(roleKey)) {
      return errorResponse("Invalid role.", 400, "invalid");
    }
    // Staff/admin/parent/driver must pick the school — otherwise a shared phone
    // can open another school's teacher dashboard. Students must also scope to
    // a school to prevent cross-tenant username collisions.
    if (!schoolIdInput) {
      return errorResponse("School ID is required.", 400, "school_mismatch");
    }

    const sb = adminClient();
    await assertNotRateLimited(
      sb,
      `login_${normalizeUsername(usernameInput)}_${roleKey}_${schoolIdInput || "none"}`,
    );

    const found = await findAccountDoc(
      sb,
      usernameInput,
      roleKey,
      schoolIdInput || null,
    );
    if (!found) {
      return errorResponse("Invalid credentials.", 401, "invalid");
    }

    const storedUsername = String(found.data.username || "").trim();
    const username = ethiopianLoginKey(storedUsername) ||
      normalizeUsername(storedUsername || found.id);
    const profile = profileFromAccount(username, found.data);
    const profileSchoolId = String(profile.schoolId || "").trim().toUpperCase();

    if (!profileSchoolId) {
      return errorResponse("Account is missing schoolId.", 400, "invalid");
    }
    if (schoolIdInput && schoolIdInput !== profileSchoolId) {
      return errorResponse(
        "School ID does not match this account.",
        403,
        "school_mismatch",
      );
    }
    if (profile.roleKey !== roleKey) {
      return errorResponse("Role mismatch.", 403, "invalid");
    }

    const schoolDoc = await assertSchoolAccessible(sb, profileSchoolId);

    const secret = await loadSecret(sb, username, profileSchoolId, found.id);
    const ok = await verifySecret(password, secret, found.data.password);
    if (!ok) {
      return errorResponse("Invalid credentials.", 401, "invalid");
    }

    if (!secret?.passwordHash) {
      await upsertSecret(sb, username, password, profileSchoolId);
    }

    const staffRoles = normalizeStaffRoles(found.data.staffRoles);
    const scopedDocId = accountDocId(profileSchoolId, username);
    const needsAccountRewrite = found.id !== scopedDocId ||
      found.data.password != null ||
      found.data.passwordHash != null ||
      String(found.data.schoolId || "").trim().toUpperCase() !== profileSchoolId ||
      normalizeUsername(found.data.username) !== username;

    const cleaned = { ...found.data };
    delete cleaned.password;
    delete cleaned.passwordHash;
    cleaned.username = username;
    cleaned.schoolId = profileSchoolId;
    cleaned.staffRoles = staffRoles;
    cleaned.staffPermissions = permissionsForRoles(staffRoles);
    cleaned.updatedAt = new Date().toISOString();

    if (needsAccountRewrite) {
      await sb.from("app_documents").upsert({
        collection: "app_auth_accounts",
        doc_id: scopedDocId,
        school_id: profileSchoolId,
        data: cleaned,
        updated_at: new Date().toISOString(),
      }, { onConflict: "collection,school_id,doc_id" });
    }

    const accessProfile = await enrichAccessProfile(sb, {
      ...(profile as Record<string, unknown>),
      schoolId: profileSchoolId,
      staffRoles,
    });

    const bindSecret = secret?.passwordHash
      ? secret
      : await loadSecret(sb, username, profileSchoolId, found.id);

    async function mintSession(forceRotate: boolean) {
      const { email, sessionPassword } = await ensureAuthUser(
        sb,
        username,
        password,
        accessProfile,
        { secret: bindSecret, forceRotate, reuseSession: !forceRotate },
      );
      return await sb.auth.signInWithPassword({ email, password: sessionPassword });
    }

    let sessionResult = await mintSession(false);
    if (sessionResult.error || !sessionResult.data.session) {
      sessionResult = await mintSession(true);
    }
    if (sessionResult.error || !sessionResult.data.session) {
      return errorResponse(
        sessionResult.error?.message || "Failed to create session.",
        500,
        "invalid",
      );
    }

    const school = schoolDoc
      ? { ...schoolDoc, id: profileSchoolId }
      : {
        id: profileSchoolId,
        name: profileSchoolId,
        status: "active",
      };

    return jsonResponse({
      access_token: sessionResult.data.session.access_token,
      refresh_token: sessionResult.data.session.refresh_token,
      profile: {
        ...profileFromAccount(username, cleaned),
        schoolId: profileSchoolId,
        staffRoles,
        staffPermissions: permissionsFromProfile({
          ...cleaned,
          staffRoles,
          staffPermissions: cleaned.staffPermissions,
        }),
        linkedStudentIds: accessProfile.linkedStudentIds,
        linkedClassNames: accessProfile.linkedClassNames,
        linkedStudentNames: accessProfile.linkedStudentNames,
        assignedClassNames: accessProfile.assignedClassNames,
      },
      school,
    });
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse(
        "Too many attempts. Try again later.",
        429,
        "rate_limited",
      );
    }
    if (msg.includes("school_blocked")) {
      return errorResponse(
        "This school is currently inactive. Contact EduAba support.",
        403,
        "school_blocked",
      );
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

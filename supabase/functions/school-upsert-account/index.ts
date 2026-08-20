import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  ALL_PERMISSIONS,
  MIN_PASSWORD_LENGTH,
  OWNER_ONLY_ROLES,
  ROLES,
  accountDocId,
  adminClient,
  ensureAuthUser,
  enrichAccessProfile,
  getDoc,
  normalizeStaffRoles,
  normalizeEmail,
  normalizeUsername,
  permissionsForRoles,
  profileFromAccount,
  queryDocs,
  upsertSecret,
} from "../_shared/school_auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const username = normalizeUsername(body?.username);
    const roleKey = body?.roleKey;
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    const password = body?.password;

    if (!username || !roleKey || !schoolId) {
      return errorResponse(
        "username, roleKey, and schoolId are required.",
        400,
        "invalid",
      );
    }
    if (!ROLES.has(roleKey)) {
      return errorResponse("Invalid role.", 400, "invalid");
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
    const callerUsername = normalizeUsername(meta.username);
    const isAdminCaller =
      !!caller && callerRole === "admin" && callerSchool === schoolId;
    const canManageStaff =
      isAdminCaller ||
      (!!caller &&
        callerSchool === schoolId &&
        callerPerms.includes("manage_staff_accounts"));
    const canAssignRoles =
      isAdminCaller ||
      (!!caller &&
        callerSchool === schoolId &&
        callerPerms.includes("assign_roles"));

    const sb = adminClient();
    if (!canManageStaff) {
      if (roleKey !== "admin") {
        const jwtHint = !caller
          ? (String(userErr?.message || "").toLowerCase().includes("sub")
            ? "cloud JWT invalid/expired (missing sub). Sign out, sign in as Admin, wait for Ready, then try again."
            : `Admin sign-in required (no cloud session${userErr ? `: ${userErr.message}` : ""}). Sign out, sign in as Admin, wait for Ready, then try again.`)
          : `Admin authentication required (role=${callerRole || "none"}, school=${callerSchool || "none"}, target=${schoolId}).`;
        return errorResponse(jwtHint, 403, "denied");
      }
      const admins = await queryDocs(sb, "app_auth_accounts", [
        { column: "schoolId", op: "eq", value: schoolId },
      ], 500);
      const hasAdmin = admins.some((a) => a.data.roleKey === "admin");
      if (hasAdmin) {
        return errorResponse(
          "Admin authentication required to create another admin.",
          403,
          "denied",
        );
      }
      if (!password) {
        return errorResponse(
          "password is required for bootstrap admin.",
          400,
          "invalid",
        );
      }
    }

    const docId = accountDocId(schoolId, username);

    if (password) {
      if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH) {
        return errorResponse(
          `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
          400,
          "password_too_short",
        );
      }
      await upsertSecret(sb, username, password, schoolId);
    }

    const existing =
      (await getDoc(sb, "app_auth_accounts", docId, schoolId)) ||
      (
        await (async () => {
          const legacy = await getDoc(sb, "app_auth_accounts", username, schoolId);
          if (
            legacy &&
            String(legacy.schoolId || "").trim().toUpperCase() === schoolId
          ) {
            return legacy;
          }
          return null;
        })()
      );

    let staffRoles = normalizeStaffRoles(existing?.staffRoles);
    let staffPermissions: string[] = Array.isArray(existing?.staffPermissions)
      ? (existing!.staffPermissions as unknown[]).map((p) => String(p))
      : permissionsForRoles(staffRoles);
    const oldClaimsVersion = Number(existing?.claimsVersion) || 0;
    let rolesChanged = false;

    if (Object.prototype.hasOwnProperty.call(body, "staffRoles")) {
      // manage_staff_accounts may assign normal staff roles; full_access stays
      // owner-only. assign_roles is the broader grant used by custom RBAC.
      const canSetRoles = canAssignRoles || canManageStaff;
      if (!canSetRoles) {
        return errorResponse(
          "Not allowed to change staff roles.",
          403,
          "denied",
        );
      }
      if (callerUsername && callerUsername === username && !isAdminCaller) {
        return errorResponse(
          "Cannot change your own staff roles.",
          403,
          "denied",
        );
      }
      const nextRoles = Array.isArray(body.staffRoles)
        ? normalizeStaffRoles(body.staffRoles)
        : [];
      for (const role of nextRoles) {
        if (OWNER_ONLY_ROLES.has(role) && !isAdminCaller) {
          return errorResponse(
            "Only the school owner may grant Full Access.",
            403,
            "denied",
          );
        }
      }
      const prev = [...staffRoles].sort().join(",");
      const next = [...nextRoles].sort().join(",");
      rolesChanged = prev !== next;
      staffRoles = nextRoles;
      if (Array.isArray(body.staffPermissions)) {
        staffPermissions = [
          ...new Set(
            (body.staffPermissions as unknown[])
              .map((p) => String(p || "").trim())
              .filter((p) => p && ALL_PERMISSIONS.includes(p)),
          ),
        ];
      } else {
        staffPermissions = permissionsForRoles(staffRoles);
      }
    } else if (
      (canAssignRoles || canManageStaff) &&
      Array.isArray(body.staffPermissions)
    ) {
      staffPermissions = [
        ...new Set(
          (body.staffPermissions as unknown[])
            .map((p) => String(p || "").trim())
            .filter((p) => p && ALL_PERMISSIONS.includes(p)),
        ),
      ];
    }

    const claimsVersion = rolesChanged ? oldClaimsVersion + 1 : oldClaimsVersion;

    let email = existing?.email || null;
    if (roleKey !== "student") {
      const nextEmail = normalizeEmail(body.email) ??
        normalizeEmail(existing?.email);
      if (!nextEmail) {
        return errorResponse("A valid email is required.", 400, "invalid_email");
      }
      email = nextEmail;
    } else if (Object.prototype.hasOwnProperty.call(body, "email")) {
      email = normalizeEmail(body.email);
    }

    const profile = {
      username,
      roleKey,
      schoolId,
      email,
      phone: body.phone || null,
      fullName: body.fullName || null,
      linkedStudentIds: body.linkedStudentIds || existing?.linkedStudentIds ||
        [],
      linkedTeacherId: body.linkedTeacherId || existing?.linkedTeacherId ||
        null,
      linkedAdminId: body.linkedAdminId || existing?.linkedAdminId || null,
      linkedDriverId: body.linkedDriverId || existing?.linkedDriverId || null,
      linkedStudentId: body.linkedStudentId || existing?.linkedStudentId ||
        null,
      mustChangePassword: !!body.mustChangePassword,
      staffRoles,
      staffPermissions,
      claimsVersion,
      updatedAt: new Date().toISOString(),
    };

    const { error: upsertErr } = await sb.from("app_documents").upsert({
      collection: "app_auth_accounts",
      doc_id: docId,
      school_id: schoolId,
      data: profile,
      updated_at: new Date().toISOString(),
    }, { onConflict: "collection,school_id,doc_id" });
    if (upsertErr) {
      return errorResponse(
        `Account save failed: ${upsertErr.message}`,
        500,
        "invalid",
      );
    }

    let teacherSynced = false;
    const rawTeacher = body?.teacherRecord;
    if (canManageStaff && rawTeacher && typeof rawTeacher === "object") {
      const teacher = { ...(rawTeacher as Record<string, unknown>) };
      delete teacher.initialPassword;
      delete teacher._docId;
      if (!(canAssignRoles || canManageStaff)) {
        delete teacher.staffRoles;
      } else {
        teacher.staffRoles = staffRoles;
      }
      const teacherId = String(teacher.teacherId || "").trim().toUpperCase();
      if (teacherId) {
        teacher.teacherId = teacherId;
        teacher.schoolId = schoolId;
        teacher.updatedAt = new Date().toISOString();
        const { error: teacherErr } = await sb.from("app_documents").upsert({
          collection: "teacher_registry",
          doc_id: teacherId,
          school_id: schoolId,
          data: teacher,
          updated_at: new Date().toISOString(),
        }, { onConflict: "collection,school_id,doc_id" });
        if (teacherErr) {
          return errorResponse(
            `Staff directory save failed: ${teacherErr.message}`,
            500,
            "teacher_sync_failed",
          );
        }
        teacherSynced = true;
      }
    }

    const accessProfile = await enrichAccessProfile(sb, profile);
    if (password) {
      try {
        await ensureAuthUser(sb, username, password, accessProfile);
      } catch (authErr) {
        return errorResponse(
          `Auth user failed: ${String((authErr as Error)?.message || authErr)}`,
          500,
          "invalid",
        );
      }
    } else if (rolesChanged && existing) {
      try {
        await ensureAuthUser(sb, username, "refresh", accessProfile);
      } catch (_) {
        // Non-fatal: next login / refresh-claims will restamp metadata.
      }
    }

    return jsonResponse({
      ok: true,
      teacherSynced,
      profile: profileFromAccount(username, profile),
    });
  } catch (e) {
    console.error(e);
    return errorResponse(String((e as Error)?.message || e), 500, "invalid");
  }
});

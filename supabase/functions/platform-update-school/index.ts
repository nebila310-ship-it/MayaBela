import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  MIN_PASSWORD_LENGTH,
  accountDocId,
  adminClient,
  ensureAuthUser,
  enrichAccessProfile,
  getDoc,
  normalizeUsername,
  queryDocs,
  upsertDoc,
  upsertSecret,
} from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";

/**
 * Platform-owner school profile update.
 * Service role + plaintext owner PIN (owner console has no school JWT).
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
    const patch = { ...(schoolRaw as Record<string, unknown>) };
    const schoolId = String(patch.id || body?.schoolId || "")
      .trim()
      .toUpperCase();
    if (!schoolId || schoolId.length < 3) {
      return errorResponse("Invalid school id.", 400, "invalid");
    }

    const existing = await getDoc(sb, "school_registry", schoolId);
    if (!existing) {
      return errorResponse(
        `School ${schoolId} is not in cloud yet. Recreate it from Onboard school.`,
        404,
        "not_found",
      );
    }

    const now = new Date().toISOString();
    const merged: Record<string, unknown> = {
      ...existing,
      ...patch,
      id: schoolId,
      updatedAt: now,
    };
    const name = String(merged.name || "").trim();
    if (!name) {
      return errorResponse("School name is required.", 400, "invalid");
    }
    merged.name = name;

    await upsertDoc(sb, "school_registry", schoolId, merged, schoolId);

    // Optional admin password reset from owner console.
    const password = body?.adminPassword ?? body?.password;
    if (password != null && password !== "") {
      if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH) {
        return errorResponse(
          `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
          400,
          "password_too_short",
        );
      }

      let username = normalizeUsername(
        body?.adminUsername || merged.adminContactPhone || "",
      );
      if (!username) {
        const admins = await queryDocs(sb, "app_auth_accounts", [
          { column: "schoolId", op: "eq", value: schoolId },
        ], 50);
        const admin = admins.find((a) => a.data.roleKey === "admin");
        username = normalizeUsername(admin?.data.username || admin?.id || "");
      }
      if (!username) {
        return errorResponse(
          "No admin account found to update password.",
          400,
          "no_admin",
        );
      }

      const docId = accountDocId(schoolId, username);
      const account = (await getDoc(sb, "app_auth_accounts", docId, schoolId)) ||
        (await getDoc(sb, "app_auth_accounts", username, schoolId)) ||
        {};
      const profile = {
        ...account,
        username,
        roleKey: "admin",
        schoolId,
        email: account.email || merged.adminEmail || null,
        phone: account.phone || merged.adminContactPhone || null,
        fullName: account.fullName || merged.adminFullName || null,
        updatedAt: now,
      };
      await upsertSecret(sb, username, password, schoolId);
      await upsertDoc(sb, "app_auth_accounts", docId, profile, schoolId);
      const accessProfile = await enrichAccessProfile(sb, profile);
      try {
        await ensureAuthUser(sb, username, password, accessProfile, {
          forceRotate: true,
        });
      } catch (authErr) {
        const msg = String((authErr as Error)?.message || authErr);
        if (!/already (been )?registered|email_exists/i.test(msg)) {
          throw authErr;
        }
        // School password is already stored. Login can use it even if Auth
        // already has this email.
      }

      // Never persist plaintext admin passwords on school_registry.
      delete merged.adminInitialPassword;
      delete merged.password;
      delete merged.passwordHash;
      await upsertDoc(sb, "school_registry", schoolId, merged, schoolId);
    }

    // Scrub secrets from response.
    const safe = { ...merged };
    delete safe.adminInitialPassword;
    delete safe.password;
    delete safe.passwordHash;
    return jsonResponse({ ok: true, schoolId, school: safe });
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

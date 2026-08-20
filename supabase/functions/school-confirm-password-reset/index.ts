import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  MIN_PASSWORD_LENGTH,
  accountDocId,
  adminClient,
  assertNotRateLimited,
  bcryptCompare,
  deleteDoc,
  findAccountByEmail,
  getDoc,
  normalizeEmail,
  normalizeUsername,
  upsertSecret,
} from "../_shared/school_auth.ts";

const MAX_ATTEMPTS = 5;

function resetDocId(schoolId: string, email: string): string {
  return `${schoolId}__${email}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    const email = normalizeEmail(body?.email);
    const code = String(body?.code || "").trim();
    const newPassword = body?.newPassword;
    const roleKey = String(body?.roleKey || "").trim() || null;

    if (!schoolId || !email || !code) {
      return errorResponse(
        "School ID, email, and code are required.",
        400,
        "invalid",
      );
    }
    if (typeof newPassword !== "string" || newPassword.length < MIN_PASSWORD_LENGTH) {
      return errorResponse(
        `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
        400,
        "password_too_short",
      );
    }

    const sb = adminClient();
    await assertNotRateLimited(sb, `reset_confirm_${schoolId}_${email}`);

    const reset = await getDoc(
      sb,
      "password_reset_codes",
      resetDocId(schoolId, email),
      schoolId,
    );
    if (!reset) {
      return errorResponse("Invalid or expired reset code.", 400, "invalid_code");
    }

    const expiresAt = Date.parse(String(reset.expiresAt || ""));
    if (!Number.isFinite(expiresAt) || Date.now() > expiresAt) {
      await deleteDoc(
        sb,
        "password_reset_codes",
        resetDocId(schoolId, email),
        schoolId,
      );
      return errorResponse("Reset code expired.", 400, "expired");
    }

    const attempts = Number(reset.attempts) || 0;
    if (attempts >= MAX_ATTEMPTS) {
      await deleteDoc(
        sb,
        "password_reset_codes",
        resetDocId(schoolId, email),
        schoolId,
      );
      return errorResponse("Too many attempts. Request a new code.", 429, "rate_limited");
    }

    const hash = String(reset.codeHash || "");
    const ok = hash ? await bcryptCompare(code, hash) : false;
    if (!ok) {
      reset.attempts = attempts + 1;
      await sb.from("app_documents").upsert({
        collection: "password_reset_codes",
        doc_id: resetDocId(schoolId, email),
        school_id: schoolId,
        data: reset,
        updated_at: new Date().toISOString(),
      }, { onConflict: "collection,school_id,doc_id" });
      return errorResponse("Invalid or expired reset code.", 400, "invalid_code");
    }

    const found = await findAccountByEmail(sb, schoolId, email, roleKey);
    const username = normalizeUsername(
      found?.data.username || reset.username,
    );
    if (!username) {
      return errorResponse("Account not found.", 404, "not_found");
    }

    await upsertSecret(sb, username, newPassword, schoolId);
    if (found) {
      const account = { ...found.data };
      account.mustChangePassword = false;
      account.updatedAt = new Date().toISOString();
      delete account.password;
      delete account.passwordHash;
      const docId = accountDocId(schoolId, username);
      await sb.from("app_documents").upsert({
        collection: "app_auth_accounts",
        doc_id: docId,
        school_id: schoolId,
        data: account,
        updated_at: new Date().toISOString(),
      }, { onConflict: "collection,school_id,doc_id" });
    }

    await deleteDoc(
      sb,
      "password_reset_codes",
      resetDocId(schoolId, email),
      schoolId,
    );
    return jsonResponse({ ok: true });
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse(
        "Too many attempts. Try again later.",
        429,
        "rate_limited",
      );
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

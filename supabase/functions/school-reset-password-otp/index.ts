import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  MIN_PASSWORD_LENGTH,
  accountDocId,
  adminClient,
  assertNotRateLimited,
  bcryptCompare,
  deleteDoc,
  ethiopianLoginKey,
  findAccountByPhone,
  getDoc,
  toE164Ethiopian,
  upsertDoc,
  upsertSecret,
} from "../_shared/school_auth.ts";

const OTP_COLLECTION = "auth_otp_challenges";
const MAX_ATTEMPTS = 5;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    const phoneInput = String(body?.phone || body?.username || "").trim();
    const otp = String(body?.otp || body?.code || "").trim();
    const newPassword = body?.newPassword;

    if (!schoolId) {
      return errorResponse("School ID is required.", 400, "school_mismatch");
    }
    if (!toE164Ethiopian(phoneInput)) {
      return errorResponse("Enter a valid Ethiopian mobile number.", 400, "invalid_phone");
    }
    if (!/^\d{6}$/.test(otp)) {
      return errorResponse("Invalid OTP.", 400, "invalid_otp");
    }
    if (typeof newPassword !== "string" || newPassword.length < MIN_PASSWORD_LENGTH) {
      return errorResponse(
        `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
        400,
        "password_too_short",
      );
    }

    const sb = adminClient();
    const phoneKey = ethiopianLoginKey(phoneInput);
    await assertNotRateLimited(sb, `otp_verify_${schoolId}_${phoneKey}`);

    const docId = `${schoolId}__${phoneKey}`;
    const challenge = await getDoc(sb, OTP_COLLECTION, docId, schoolId);
    if (!challenge) {
      return errorResponse("Invalid or expired OTP.", 400, "invalid_otp");
    }

    const expiresAt = Date.parse(String(challenge.expiresAt || ""));
    if (!expiresAt || expiresAt < Date.now()) {
      await deleteDoc(sb, OTP_COLLECTION, docId, schoolId);
      return errorResponse("OTP expired. Request a new code.", 400, "expired");
    }

    const attempts = Number(challenge.attempts || 0);
    if (attempts >= MAX_ATTEMPTS) {
      await deleteDoc(sb, OTP_COLLECTION, docId, schoolId);
      return errorResponse("Too many attempts. Request a new code.", 429, "too_many_attempts");
    }

    const hash = String(challenge.otpHash || "");
    const match = hash ? await bcryptCompare(otp, hash) : false;
    if (!match) {
      await upsertDoc(sb, OTP_COLLECTION, docId, {
        ...challenge,
        attempts: attempts + 1,
      }, schoolId);
      return errorResponse("Invalid OTP.", 400, "invalid_otp");
    }

    const found = await findAccountByPhone(sb, phoneInput, schoolId);
    if (!found) {
      await deleteDoc(sb, OTP_COLLECTION, docId, schoolId);
      return errorResponse("No registered account found.", 404, "not_found");
    }

    const username = String(found.data.username || found.id).trim();
    await upsertSecret(sb, username, newPassword, schoolId);

    const account = { ...found.data };
    account.mustChangePassword = false;
    account.updatedAt = new Date().toISOString();
    delete account.password;
    delete account.passwordHash;
    await upsertDoc(
      sb,
      "app_auth_accounts",
      found.id || accountDocId(schoolId, username),
      account,
      schoolId,
    );
    await deleteDoc(sb, OTP_COLLECTION, docId, schoolId);

    return jsonResponse({ ok: true });
  } catch (e) {
    const message = String((e as { message?: string })?.message || e);
    if (message === "rate_limited") {
      return errorResponse("Too many attempts. Wait a few minutes.", 429, "rate_limited");
    }
    console.error(e);
    return errorResponse(message, 500);
  }
});

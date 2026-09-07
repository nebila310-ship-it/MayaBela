import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  assertNotRateLimited,
  bcryptHash,
  ethiopianLoginKey,
  findAccountByPhone,
  toE164Ethiopian,
  upsertDoc,
} from "../_shared/school_auth.ts";
import { sendSms, smsGatewayConfigured } from "../_shared/sms_gateway.ts";

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_COLLECTION = "auth_otp_challenges";

function sixDigitOtp(): string {
  const bytes = new Uint8Array(4);
  crypto.getRandomValues(bytes);
  const n = (bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3]) >>> 0;
  return String(100000 + (n % 900000));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    const phoneInput = String(body?.phone || body?.username || "").trim();

    if (!schoolId) {
      return errorResponse("School ID is required.", 400, "school_mismatch");
    }
    const e164 = toE164Ethiopian(phoneInput);
    if (!e164) {
      return errorResponse("Enter a valid Ethiopian mobile number.", 400, "invalid_phone");
    }

    if (!smsGatewayConfigured()) {
      return errorResponse(
        "Paid SMS gateway is not configured.",
        503,
        "sms_gateway_required",
      );
    }

    const sb = adminClient();
    const phoneKey = ethiopianLoginKey(phoneInput);
    await assertNotRateLimited(sb, `otp_send_${schoolId}_${phoneKey}`);

    const found = await findAccountByPhone(sb, phoneInput, schoolId);
    if (!found) {
      return errorResponse("No registered account found.", 404, "not_found");
    }

    const username = String(found.data.username || found.id).trim();
    const roleKey = String(found.data.roleKey || "").trim();
    const otp = sixDigitOtp();
    const expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString();
    const docId = `${schoolId}__${phoneKey}`;

    await upsertDoc(sb, OTP_COLLECTION, docId, {
      username,
      roleKey,
      schoolId,
      phone: e164,
      otpHash: await bcryptHash(otp),
      expiresAt,
      attempts: 0,
      createdAt: new Date().toISOString(),
    }, schoolId);

    const sent = await sendSms(
      e164,
      `MayaBela code: ${otp}. It expires in 10 minutes. Do not share it.`,
    );
    if (!sent.ok) {
      return errorResponse(
        sent.error || "SMS could not be sent.",
        sent.error === "sms_gateway_required" ? 503 : 502,
        sent.error === "sms_gateway_required" ? "sms_gateway_required" : "sms_failed",
      );
    }

    return jsonResponse({
      ok: true,
      e164Phone: e164,
      provider: sent.provider,
    });
  } catch (e) {
    const message = String((e as { message?: string })?.message || e);
    if (message === "rate_limited") {
      return errorResponse("Too many attempts. Wait a few minutes.", 429, "rate_limited");
    }
    console.error(e);
    return errorResponse(message, 500);
  }
});

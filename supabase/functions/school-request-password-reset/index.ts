import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { assertMailConfigured, sendPlainEmail } from "../_shared/mailer.ts";
import {
  adminClient,
  assertNotRateLimited,
  bcryptHash,
  findAccountByEmail,
  normalizeEmail,
  normalizeUsername,
  upsertDoc,
  deleteDoc,
} from "../_shared/school_auth.ts";

const RESET_TTL_MS = 15 * 60 * 1000;

function resetDocId(schoolId: string, email: string): string {
  return `${schoolId}__${email}`;
}

function sixDigitCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    const email = normalizeEmail(body?.email);
    const roleKey = String(body?.roleKey || "").trim() || null;

    if (!schoolId || !email) {
      return errorResponse("School ID and email are required.", 400, "invalid");
    }

    // Fail before lookup so a missing mailbox config cannot reveal whether
    // the address is enrolled (unknown → {ok:true}, known → 503).
    try {
      assertMailConfigured();
    } catch (e) {
      const msg = String((e as { message?: string })?.message || e);
      if (msg.includes("mail_not_configured")) {
        return errorResponse(
          "Email sending is not configured on the server.",
          503,
          "mail_not_configured",
        );
      }
      throw e;
    }

    const sb = adminClient();
    await assertNotRateLimited(sb, `reset_request_${schoolId}_${email}`);

    const found = await findAccountByEmail(sb, schoolId, email, roleKey);
    if (!found || found.data.roleKey === "student") {
      return jsonResponse({ ok: true });
    }

    const code = sixDigitCode();
    const username = normalizeUsername(found.data.username || found.id);
    await upsertDoc(sb, "password_reset_codes", resetDocId(schoolId, email), {
      schoolId,
      email,
      username,
      roleKey: found.data.roleKey,
      accountId: found.id,
      codeHash: await bcryptHash(code),
      attempts: 0,
      expiresAt: new Date(Date.now() + RESET_TTL_MS).toISOString(),
    }, schoolId);

    try {
      await sendPlainEmail({
        to: email,
        subject: "MayaBela password reset code",
        text:
          `Your MayaBela password reset code is ${code}.\n\n` +
          `School ID: ${schoolId}\n` +
          `This code expires in 15 minutes. If you did not request it, ignore this email.`,
      });
    } catch (sendErr) {
      // Same {ok:true} as an unknown email so a send failure cannot enumerate.
      console.error("password reset mail failed", sendErr);
      try {
        await deleteDoc(
          sb,
          "password_reset_codes",
          resetDocId(schoolId, email),
          schoolId,
        );
      } catch (_) {
        /* ignore */
      }
    }

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
    if (msg.includes("mail_not_configured") || msg.includes("mail_send_failed")) {
      return errorResponse(
        "Email sending is not configured on the server.",
        503,
        "mail_not_configured",
      );
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

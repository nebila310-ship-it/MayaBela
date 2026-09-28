import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { loadMailSecrets, sendPasswordResetEmail } from "../_shared/mailer.ts";
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

    if (!schoolId || !email) {
      return errorResponse("School ID and email are required.", 400, "invalid");
    }

    const sb = adminClient();
    await assertNotRateLimited(sb, `reset_request_${schoolId}_${email}`);

    const found = await findAccountByEmail(sb, schoolId, email);
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

    const mail = await loadMailSecrets(sb);
    try {
      const via = await sendPasswordResetEmail(sb, {
        to: email,
        schoolId,
        username,
        code,
        mail,
      });
      return jsonResponse({ ok: true, via });
    } catch (sendErr) {
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
      return errorResponse(
        "Email sending is not configured on the server.",
        503,
        "mail_not_configured",
      );
    }
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

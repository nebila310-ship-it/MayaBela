import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  PLATFORM_SCHOOL_ID,
  upsertDoc,
} from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";
import {
  isMailReady,
  loadMailSecrets,
  mailSecretsFromDoc,
  mailStatusPublic,
  mergeMailSecrets,
  sendPlainEmail,
} from "../_shared/mailer.ts";

function trim(value: unknown): string {
  return String(value ?? "").trim();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const sb = adminClient();
    await authorizePlatformOwner(sb, req, body?.ownerPin);

    const action = trim(body?.action || "status").toLowerCase();
    const existing = await loadMailSecrets(sb);

    if (action === "status") {
      return jsonResponse({ ok: true, ...mailStatusPublic(existing) });
    }

    if (action === "save") {
      const incoming = mailSecretsFromDoc({
        from: body?.from ?? body?.mailFrom,
        mailFrom: body?.mailFrom,
        smtpHost: body?.smtpHost,
        smtpPort: body?.smtpPort,
        smtpUser: body?.smtpUser,
        smtpPass: body?.smtpPass,
        smtpSecure: body?.smtpSecure,
        resendApiKey: body?.resendApiKey,
      });
      // Blank secrets keep the stored key so the owner can change From only.
      const merged = mergeMailSecrets(incoming, existing);
      if (!merged.from) {
        return errorResponse(
          "From address is required (e.g. MayaBela <onboarding@resend.dev>).",
          400,
          "invalid",
        );
      }
      if (!isMailReady(merged)) {
        return errorResponse(
          "Add a Resend API key, or SMTP host + user + password.",
          400,
          "mail_not_configured",
        );
      }
      await upsertDoc(
        sb,
        "platform_secrets",
        "mail",
        {
          from: merged.from,
          smtpHost: merged.smtpHost || null,
          smtpPort: merged.smtpPort || "587",
          smtpUser: merged.smtpUser || null,
          smtpPass: merged.smtpPass || null,
          smtpSecure: merged.smtpSecure || null,
          resendApiKey: merged.resendApiKey || null,
          updatedAt: new Date().toISOString(),
        },
        PLATFORM_SCHOOL_ID,
      );
      return jsonResponse({ ok: true, ...mailStatusPublic(merged) });
    }

    if (action === "test") {
      if (!isMailReady(existing)) {
        return errorResponse(
          "Save a From address and Resend key (or SMTP) first.",
          400,
          "mail_not_configured",
        );
      }
      const to = trim(body?.to).toLowerCase();
      if (!to || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) {
        return errorResponse("Enter a valid test email.", 400, "invalid_email");
      }
      try {
        await sendPlainEmail({
          to,
          subject: "MayaBela mail test",
          text:
            "Password-reset email is working. You can ignore this message.",
        }, existing);
      } catch (sendErr) {
        console.error("mail test failed", sendErr);
        return errorResponse(
          "Could not send. Check the From address and API key / SMTP.",
          502,
          "mail_send_failed",
        );
      }
      return jsonResponse({ ok: true, ...mailStatusPublic(existing) });
    }

    return errorResponse("Unknown action.", 400, "invalid");
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

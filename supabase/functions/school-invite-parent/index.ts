import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  assertNotRateLimited,
  getDoc,
} from "../_shared/school_auth.ts";
import { isMailReady, loadMailSecrets, sendPlainEmail } from "../_shared/mailer.ts";

function clip(value: unknown, max: number): string {
  return String(value ?? "").trim().slice(0, max);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const schoolId = clip(body?.schoolId, 24).toUpperCase();
    const email = clip(body?.email, 120).toLowerCase();
    const studentId = clip(body?.studentId, 24).toUpperCase();
    const studentName = clip(body?.studentName, 120);
    const dateOfBirth = clip(body?.dateOfBirth, 32);
    const message = clip(body?.message, 4000);

    if (!schoolId || !email || !email.includes("@") || !studentId) {
      return errorResponse(
        "schoolId, email, and studentId are required.",
        400,
        "invalid",
      );
    }

    const sb = adminClient();
    await assertNotRateLimited(sb, `parent_invite_${schoolId}_${email}`);
    const school = await getDoc(sb, "school_registry", schoolId);
    if (!school) return errorResponse("School not found.", 404, "not_found");

    const text = message ||
      `Welcome. ${studentName || "Your child"} is enrolled.\n` +
        `School ID: ${schoolId}\nStudent ID: ${studentId}\n` +
        (dateOfBirth ? `Date of birth: ${dateOfBirth}\n` : "") +
        `Register as Parent using the Student ID and date of birth.`;

    const mail = await loadMailSecrets(sb);
    if (!isMailReady(mail)) {
      return jsonResponse({ ok: true, via: "skipped" });
    }
    await sendPlainEmail({
      to: email,
      subject: `Parent invite — ${studentName || studentId} (${schoolId})`,
      text,
    }, mail);
    return jsonResponse({ ok: true, via: "email" });
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse("Too many invites. Try later.", 429, "rate_limited");
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

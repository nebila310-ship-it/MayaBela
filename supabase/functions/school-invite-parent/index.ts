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

function ensureInviteLink(message: string, inviteUrl: string): string {
  if (!message) return "";
  if (
    message.includes(inviteUrl) ||
    message.includes("role=parent") ||
    message.includes("majobridge.com") ||
    message.includes("mayabela.pages.dev")
  ) {
    return message;
  }
  return `${message}\n\nRegister here:\n${inviteUrl}`;
}

function inviteHtml(opts: {
  schoolName: string;
  inviteUrl: string;
  text: string;
}): string {
  const escaped = opts.text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
  const linked = escaped.replace(
    /(https?:\/\/[^\s<]+)/g,
    '<a href="$1">$1</a>',
  );
  return (
    `<p style="font-size:18px;font-weight:700">Welcome to ${opts.schoolName}!</p>` +
    `<p><a href="${opts.inviteUrl}" style="display:inline-block;padding:10px 16px;` +
    `background:#1d4ed8;color:#ffffff;text-decoration:none;border-radius:8px">` +
    `Register as a parent</a></p>` +
    `<p>${linked.replace(/\n/g, "<br/>")}</p>`
  );
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
    const requestedSchoolName = clip(body?.schoolName, 120);
    const dateOfBirth = clip(body?.dateOfBirth, 32);
    const message = clip(body?.message, 4000);
    const html = clip(body?.html, 12000);

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

    const dobParam = (() => {
      const raw = String(dateOfBirth || "").trim();
      const iso = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
      if (iso) return `${iso[3]}/${iso[2]}/${iso[1]}`;
      const slash = raw.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
      if (slash) {
        return `${slash[1].padStart(2, "0")}/${slash[2].padStart(2, "0")}/${slash[3]}`;
      }
      return raw;
    })();
    const inviteUrl =
      `https://majobridge.com/?role=parent&school=${encodeURIComponent(schoolId)}` +
      `&student=${encodeURIComponent(studentId)}` +
      (dobParam ? `&dob=${encodeURIComponent(dobParam)}` : "");
    const schoolName = requestedSchoolName ||
      String(school.name ?? school.schoolName ?? "").trim() ||
      schoolId;
    const defaultText =
      `Welcome to ${schoolName}!\n\n` +
      `Dear parent,\n\n` +
      `We are so happy to welcome ${studentName || "your child"} into the ${schoolName} family. ` +
      `Please tap the link below to register as a parent:\n\n${inviteUrl}\n\n` +
      `School ID: ${schoolId}\nStudent ID: ${studentId}\n` +
      (dateOfBirth ? `Date of birth: ${dateOfBirth}\n` : "") +
      `\nWith warm regards,\n${schoolName}`;
    const text = ensureInviteLink(message, inviteUrl) || defaultText;
    const htmlBody = html.includes(inviteUrl)
      ? html
      : inviteHtml({ schoolName, inviteUrl, text });

    const mail = await loadMailSecrets(sb);
    if (!isMailReady(mail)) {
      return jsonResponse({ ok: true, via: "skipped" });
    }
    await sendPlainEmail({
      to: email,
      subject: `Welcome to ${schoolName}`,
      text,
      html: htmlBody,
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

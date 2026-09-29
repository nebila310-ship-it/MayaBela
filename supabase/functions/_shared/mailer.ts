import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  findAuthUserByEmail,
  getDoc,
  loadSecret,
  PLATFORM_SCHOOL_ID,
  syntheticEmail,
} from "./school_auth.ts";

export type MailPayload = {
  to: string;
  subject: string;
  text: string;
  html?: string;
};

export type MailSecrets = {
  from: string;
  smtpHost: string;
  smtpPort: string;
  smtpUser: string;
  smtpPass: string;
  smtpSecure: string;
  resendApiKey: string;
};

function trim(value: unknown): string {
  return String(value ?? "").trim();
}

const emptySecrets = (): MailSecrets => ({
  from: "",
  smtpHost: "",
  smtpPort: "587",
  smtpUser: "",
  smtpPass: "",
  smtpSecure: "",
  resendApiKey: "",
});

export function mailSecretsFromEnv(): MailSecrets {
  return {
    from: trim(Deno.env.get("MAIL_FROM") || Deno.env.get("SMTP_FROM")),
    smtpHost: trim(Deno.env.get("SMTP_HOST")),
    smtpPort: trim(Deno.env.get("SMTP_PORT") || "587"),
    smtpUser: trim(Deno.env.get("SMTP_USER")),
    smtpPass: Deno.env.get("SMTP_PASS") || "",
    smtpSecure: trim(Deno.env.get("SMTP_SECURE")),
    resendApiKey: trim(Deno.env.get("RESEND_API_KEY")),
  };
}

export function mailSecretsFromDoc(
  doc: Record<string, unknown> | null,
): MailSecrets {
  if (!doc) return emptySecrets();
  return {
    from: trim(doc.from || doc.mailFrom),
    smtpHost: trim(doc.smtpHost),
    smtpPort: trim(doc.smtpPort || "587"),
    smtpUser: trim(doc.smtpUser),
    smtpPass: String(doc.smtpPass ?? ""),
    smtpSecure: trim(doc.smtpSecure),
    resendApiKey: trim(doc.resendApiKey),
  };
}

export function mergeMailSecrets(
  primary: MailSecrets,
  fallback: MailSecrets,
): MailSecrets {
  const pick = (a: string, b: string) => (a.trim() ? a : b);
  return {
    from: pick(primary.from, fallback.from),
    smtpHost: pick(primary.smtpHost, fallback.smtpHost),
    smtpPort: pick(primary.smtpPort, fallback.smtpPort) || "587",
    smtpUser: pick(primary.smtpUser, fallback.smtpUser),
    smtpPass: pick(primary.smtpPass, fallback.smtpPass),
    smtpSecure: pick(primary.smtpSecure, fallback.smtpSecure),
    resendApiKey: pick(primary.resendApiKey, fallback.resendApiKey),
  };
}

export function isMailReady(secrets: MailSecrets): boolean {
  if (!secrets.from) return false;
  if (secrets.smtpHost) return !!(secrets.smtpUser && secrets.smtpPass);
  return !!secrets.resendApiKey;
}

export function mailStatusPublic(secrets: MailSecrets): {
  configured: boolean;
  from: string;
  hasResend: boolean;
  hasSmtp: boolean;
} {
  return {
    configured: isMailReady(secrets),
    from: secrets.from,
    hasResend: !!secrets.resendApiKey,
    hasSmtp: !!(secrets.smtpHost && secrets.smtpUser && secrets.smtpPass),
  };
}

export async function loadMailSecrets(
  sb: SupabaseClient,
): Promise<MailSecrets> {
  const env = mailSecretsFromEnv();
  if (isMailReady(env)) return env;
  const doc = await getDoc(sb, "platform_secrets", "mail", PLATFORM_SCHOOL_ID);
  return mergeMailSecrets(env, mailSecretsFromDoc(doc));
}

/** Throws `mail_not_configured` when SMTP/Resend is not ready. */
export function assertMailConfigured(secrets: MailSecrets = mailSecretsFromEnv()): void {
  if (!isMailReady(secrets)) throw new Error("mail_not_configured");
}

function resetEmailText(opts: {
  schoolId: string;
  code: string;
}): string {
  return (
    `Your MayaBela password reset code is ${opts.code}.\n\n` +
    `School ID: ${opts.schoolId}\n` +
    `This code expires in 15 minutes. If you did not request it, ignore this email.`
  );
}

function resetEmailHtml(opts: { schoolId: string; code: string }): string {
  return (
    `<p>Your MayaBela password reset code is:</p>` +
    `<p style="font-size:28px;letter-spacing:4px;font-weight:700">${opts.code}</p>` +
    `<p>School ID: ${opts.schoolId}<br/>This code expires in 15 minutes.</p>` +
    `<p>If you did not request it, ignore this email.</p>`
  );
}

export function smtpHostBlocked(host: string): boolean {
  const h = host.trim().toLowerCase();
  return (
    h.includes("gmail.com") ||
    h.includes("google.com") ||
    h.includes("googlemail.com")
  );
}

async function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  let timer: number | undefined;
  const timeout = new Promise<T>((_, reject) => {
    timer = setTimeout(() => reject(new Error(label)), ms);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}

export async function sendPlainEmail(
  payload: MailPayload,
  secrets: MailSecrets = mailSecretsFromEnv(),
): Promise<void> {
  assertMailConfigured(secrets);
  // HTTPS APIs work from Edge Functions. Consumer SMTP (Gmail) is blocked
  // and hangs until the browser reports "Failed to fetch".
  if (secrets.resendApiKey) {
    await sendViaResend(secrets.resendApiKey, secrets.from, payload);
    return;
  }
  if (secrets.smtpHost) {
    if (smtpHostBlocked(secrets.smtpHost)) {
      throw new Error("smtp_blocked");
    }
    await withTimeout(sendViaSmtp(secrets, payload), 8000, "smtp_timeout");
    return;
  }
  throw new Error("mail_not_configured");
}

/**
 * Send a password-reset email. Prefers Resend/SMTP; otherwise uses the
 * project's built-in Auth mailer so reset works without extra secrets.
 */
export async function sendPasswordResetEmail(
  sb: SupabaseClient,
  opts: {
    to: string;
    schoolId: string;
    username: string;
    code: string;
    mail: MailSecrets;
  },
): Promise<"mail" | "auth"> {
  if (isMailReady(opts.mail)) {
    try {
      await sendPlainEmail({
        to: opts.to,
        subject: "MayaBela password reset code",
        text: resetEmailText(opts),
        html: resetEmailHtml(opts),
      }, opts.mail);
      return "mail";
    } catch (e) {
      const msg = String((e as Error)?.message || e);
      if (
        !msg.includes("smtp_blocked") &&
        !msg.includes("smtp_timeout") &&
        !msg.includes("mail_send_failed")
      ) {
        throw e;
      }
      console.error("direct mail failed, trying Auth mailer", e);
    }
  }
  // Built-in Auth SMTP (after 26 Sep 2026) only delivers to Supabase org
  // members, and Gmail often junks supabase.io. Still try it so the owner
  // inbox has a chance, then tell the client it may land in Spam.
  const sent = await sendViaGoTrueMailer(sb, opts);
  if (!sent) throw new Error("mail_not_configured");
  return "auth";
}

function goTrueMailOutcome(status: number, body: string): "ok" | "retry" | "fail" {
  const lower = `${body} ${status}`.toLowerCase();
  if (
    status === 429 ||
    lower.includes("rate_limit") ||
    lower.includes("over_email_send") ||
    lower.includes("security purposes")
  ) {
    // A reset mail was already handed to the provider for this address.
    return "ok";
  }
  if (
    lower.includes("not authorized") ||
    lower.includes("email_address_not_authorized") ||
    lower.includes("email_not_authorized")
  ) {
    return "fail";
  }
  if (status >= 200 && status < 300) return "ok";
  return "retry";
}

async function sendViaGoTrueMailer(
  sb: SupabaseClient,
  opts: { to: string; schoolId: string; username: string },
): Promise<boolean> {
  const synthetic = syntheticEmail(opts.username, opts.schoolId);
  const secret = await loadSecret(sb, opts.username, opts.schoolId);
  let userId = String(secret?.authUserId || "").trim();
  if (!userId) {
    const found = await findAuthUserByEmail(sb, synthetic) ||
      await findAuthUserByEmail(sb, opts.to);
    userId = found?.id || "";
  }
  if (!userId) {
    console.error("gotrue reset: no auth user for", opts.username, opts.schoolId);
    return false;
  }

  const { data } = await sb.auth.admin.getUserById(userId);
  const original = String(data.user?.email || synthetic).trim() || synthetic;

  const { error: upErr } = await sb.auth.admin.updateUserById(userId, {
    email: opts.to,
    email_confirm: true,
  });
  if (upErr) {
    console.error("gotrue reset: could not set mailbox", upErr);
    return false;
  }

  try {
    const redirectTo = "https://mayabela.pages.dev";
    const { error: linkErr } = await sb.auth.admin.generateLink({
      type: "recovery",
      email: opts.to,
      options: { redirectTo },
    });
    if (!linkErr) return true;
    const linkMsg = String(linkErr.message || linkErr);
    console.error("gotrue generateLink failed", linkMsg);
    const fromLink = goTrueMailOutcome(0, linkMsg);
    if (fromLink === "ok") return true;
    if (fromLink === "fail") {
      await restoreLoginEmail(sb, userId, original, opts.to);
      return false;
    }

    const url = (Deno.env.get("SUPABASE_URL") || "").replace(/\/$/, "");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
      Deno.env.get("SUPABASE_ANON_KEY") ||
      "";
    if (!url || !key) {
      await restoreLoginEmail(sb, userId, original, opts.to);
      return false;
    }

    const headers = {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    };
    const attempts: Array<{ path: string; body: Record<string, unknown> }> = [
      {
        path: "/auth/v1/recover",
        body: { email: opts.to, gotrue_meta_security: {} },
      },
      {
        path: "/auth/v1/otp",
        body: {
          email: opts.to,
          create_user: false,
          options: { emailRedirectTo: redirectTo },
        },
      },
    ];
    for (const attempt of attempts) {
      const res = await fetch(`${url}${attempt.path}`, {
        method: "POST",
        headers,
        body: JSON.stringify(attempt.body),
      });
      const text = await res.text();
      const outcome = goTrueMailOutcome(res.status, text);
      if (outcome === "ok") return true;
      if (outcome === "fail") {
        console.error("gotrue send not authorized", attempt.path, res.status, text);
        await restoreLoginEmail(sb, userId, original, opts.to);
        return false;
      }
      console.error("gotrue send failed", attempt.path, res.status, text);
    }
    await restoreLoginEmail(sb, userId, original, opts.to);
    return false;
  } catch (e) {
    console.error("gotrue reset send failed", e);
    await restoreLoginEmail(sb, userId, original, opts.to);
    return false;
  }
}

async function restoreLoginEmail(
  sb: SupabaseClient,
  userId: string,
  original: string,
  current: string,
): Promise<void> {
  if (original.toLowerCase() === current.toLowerCase()) return;
  try {
    await sb.auth.admin.updateUserById(userId, {
      email: original,
      email_confirm: true,
    });
  } catch (e) {
    console.error("gotrue reset: restore login email failed", e);
  }
}

async function sendViaResend(
  apiKey: string,
  from: string,
  payload: MailPayload,
): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [payload.to],
      subject: payload.subject,
      text: payload.text,
      html: payload.html || payload.text.replace(/\n/g, "<br/>"),
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    console.error("resend failed", res.status, body);
    throw new Error("mail_send_failed");
  }
}

async function sendViaSmtp(
  secrets: MailSecrets,
  payload: MailPayload,
): Promise<void> {
  const { SMTPClient } = await import(
    "https://deno.land/x/denomailer@1.6.0/mod.ts"
  );
  const host = secrets.smtpHost;
  const port = Number(secrets.smtpPort || "587");
  const username = secrets.smtpUser;
  const password = secrets.smtpPass;
  if (!host || !username || !password) {
    throw new Error("mail_not_configured");
  }

  const resolvedPort = Number.isFinite(port) ? port : 587;
  const secureEnv = secrets.smtpSecure.toLowerCase();
  // Port 465 is implicit TLS. Port 587 is STARTTLS (tls: false in denomailer).
  const tls = secureEnv === "true" ||
    (secureEnv !== "false" && resolvedPort === 465);

  const client = new SMTPClient({
    connection: {
      hostname: host,
      port: resolvedPort,
      tls,
      auth: { username, password },
    },
  });
  try {
    await client.send({
      from: secrets.from,
      to: payload.to,
      subject: payload.subject,
      content: payload.text,
      html: payload.html || payload.text.replace(/\n/g, "<br/>"),
    });
  } finally {
    try {
      await client.close();
    } catch (_) {
      /* ignore */
    }
  }
}

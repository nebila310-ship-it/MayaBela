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

export async function sendPlainEmail(
  payload: MailPayload,
  secrets: MailSecrets = mailSecretsFromEnv(),
): Promise<void> {
  assertMailConfigured(secrets);
  if (secrets.smtpHost) {
    await sendViaSmtp(secrets, payload);
    return;
  }
  if (secrets.resendApiKey) {
    await sendViaResend(secrets.resendApiKey, secrets.from, payload);
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
): Promise<void> {
  if (isMailReady(opts.mail)) {
    await sendPlainEmail({
      to: opts.to,
      subject: "MayaBela password reset code",
      text:
        `Your MayaBela password reset code is ${opts.code}.\n\n` +
        `School ID: ${opts.schoolId}\n` +
        `This code expires in 15 minutes. If you did not request it, ignore this email.`,
    }, opts.mail);
    return;
  }
  const sent = await sendViaGoTrueMailer(sb, opts);
  if (!sent) throw new Error("mail_not_configured");
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
    const url = (Deno.env.get("SUPABASE_URL") || "").replace(/\/$/, "");
    const anon = Deno.env.get("SUPABASE_ANON_KEY") ||
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
      "";
    if (!url || !anon) {
      await restoreLoginEmail(sb, userId, original, opts.to);
      return false;
    }

    const headers = {
      apikey: anon,
      Authorization: `Bearer ${anon}`,
      "Content-Type": "application/json",
    };
    const redirectTo = "https://mayabela.pages.dev";
    let res = await fetch(`${url}/auth/v1/otp`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        email: opts.to,
        create_user: false,
        options: { emailRedirectTo: redirectTo },
      }),
    });
    if (!res.ok) {
      const otpBody = await res.text();
      console.error("gotrue otp failed", res.status, otpBody);
      res = await fetch(`${url}/auth/v1/recover`, {
        method: "POST",
        headers,
        body: JSON.stringify({ email: opts.to, gotrue_meta_security: {} }),
      });
      if (!res.ok) {
        console.error("gotrue recover failed", res.status, await res.text());
        await restoreLoginEmail(sb, userId, original, opts.to);
        return false;
      }
    }
    // Leave the real mailbox on the Auth user so the emailed OTP still verifies.
    return true;
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
    });
  } finally {
    try {
      await client.close();
    } catch (_) {
      /* ignore */
    }
  }
}

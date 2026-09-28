import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { getDoc, PLATFORM_SCHOOL_ID } from "./school_auth.ts";

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

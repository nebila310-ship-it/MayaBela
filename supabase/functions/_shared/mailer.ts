export type MailPayload = {
  to: string;
  subject: string;
  text: string;
};

function mailFrom(): string {
  return (Deno.env.get("MAIL_FROM") || Deno.env.get("SMTP_FROM") || "").trim();
}

export async function sendPlainEmail(payload: MailPayload): Promise<void> {
  const from = mailFrom();
  if (!from) throw new Error("mail_not_configured");

  const smtpHost = (Deno.env.get("SMTP_HOST") || "").trim();
  if (smtpHost) {
    await sendViaSmtp(from, payload);
    return;
  }

  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (resendKey) {
    await sendViaResend(resendKey, from, payload);
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

async function sendViaSmtp(from: string, payload: MailPayload): Promise<void> {
  const { SMTPClient } = await import(
    "https://deno.land/x/denomailer@1.6.0/mod.ts"
  );
  const host = (Deno.env.get("SMTP_HOST") || "").trim();
  const port = Number(Deno.env.get("SMTP_PORT") || "587");
  const username = (Deno.env.get("SMTP_USER") || "").trim();
  const password = Deno.env.get("SMTP_PASS") || "";
  if (!host || !username || !password) {
    throw new Error("mail_not_configured");
  }

  const client = new SMTPClient({
    connection: {
      hostname: host,
      port: Number.isFinite(port) ? port : 587,
      tls: Deno.env.get("SMTP_SECURE") === "true",
      auth: { username, password },
    },
  });
  try {
    await client.send({
      from,
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

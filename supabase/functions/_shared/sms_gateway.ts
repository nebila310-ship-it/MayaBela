/** Paid SMS gateway. Secrets stay on the Edge Function — never in the Flutter app. */

export type SmsProvider = "africas_talking" | "twilio";

export type SmsSendResult = {
  ok: boolean;
  provider?: SmsProvider;
  error?: string;
};

export function resolveSmsProvider(): SmsProvider | null {
  const configured = String(Deno.env.get("SMS_PROVIDER") || "")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  if (configured === "africas_talking" || configured === "africastalking") {
    return "africas_talking";
  }
  if (configured === "twilio") return "twilio";
  if (Deno.env.get("AT_API_KEY") && Deno.env.get("AT_USERNAME")) {
    return "africas_talking";
  }
  if (Deno.env.get("TWILIO_ACCOUNT_SID") && Deno.env.get("TWILIO_AUTH_TOKEN")) {
    return "twilio";
  }
  return null;
}

export function smsGatewayConfigured(): boolean {
  return resolveSmsProvider() !== null;
}

export async function sendSms(toE164: string, message: string): Promise<SmsSendResult> {
  const provider = resolveSmsProvider();
  if (!provider) {
    return { ok: false, error: "sms_gateway_required" };
  }
  if (provider === "africas_talking") {
    return sendAfricasTalking(toE164, message);
  }
  return sendTwilio(toE164, message);
}

async function sendAfricasTalking(
  toE164: string,
  message: string,
): Promise<SmsSendResult> {
  const username = String(Deno.env.get("AT_USERNAME") || "").trim();
  const apiKey = String(Deno.env.get("AT_API_KEY") || "").trim();
  const sender = String(Deno.env.get("AT_SENDER") || "").trim();
  if (!username || !apiKey) {
    return { ok: false, provider: "africas_talking", error: "sms_gateway_required" };
  }

  const body = new URLSearchParams({
    username,
    to: toE164,
    message,
  });
  if (sender) body.set("from", sender);

  const res = await fetch("https://api.africastalking.com/version1/messaging", {
    method: "POST",
    headers: {
      apiKey,
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  const json = await res.json().catch(() => ({})) as Record<string, unknown>;
  const data = json.SMSMessageData as Record<string, unknown> | undefined;
  const recipients = Array.isArray(data?.Recipients) ? data!.Recipients as Array<Record<string, unknown>> : [];
  const status = String(recipients[0]?.status || "").toLowerCase();
  const ok = res.ok && (status === "success" || status === "sent");
  if (!ok) {
    const detail = String(
      recipients[0]?.status || data?.Message || json.error || res.statusText || "sms_failed",
    );
    return { ok: false, provider: "africas_talking", error: detail.slice(0, 180) };
  }
  return { ok: true, provider: "africas_talking" };
}

async function sendTwilio(toE164: string, message: string): Promise<SmsSendResult> {
  const sid = String(Deno.env.get("TWILIO_ACCOUNT_SID") || "").trim();
  const token = String(Deno.env.get("TWILIO_AUTH_TOKEN") || "").trim();
  const from = String(Deno.env.get("TWILIO_FROM") || "").trim();
  if (!sid || !token || !from) {
    return { ok: false, provider: "twilio", error: "sms_gateway_required" };
  }

  const res = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${sid}:${token}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: toE164, From: from, Body: message }),
    },
  );
  const json = await res.json().catch(() => ({})) as Record<string, unknown>;
  const status = String(json.status || "").toLowerCase();
  const ok = res.ok && !json.error_code &&
    (status === "queued" || status === "accepted" || status === "sent" || status === "delivered");
  if (!ok) {
    const detail = String(json.message || json.error_message || res.statusText || "sms_failed");
    return { ok: false, provider: "twilio", error: detail.slice(0, 180) };
  }
  return { ok: true, provider: "twilio" };
}

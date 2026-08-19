import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { adminClient, assertNotRateLimited } from "../_shared/school_auth.ts";

const PLATFORM = "__PLATFORM__";

function clip(value: unknown, max: number): string {
  return String(value ?? "").trim().slice(0, max);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const sb = adminClient();
    const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
      req.headers.get("cf-connecting-ip") ||
      "unknown";
    await assertNotRateLimited(sb, `crash_${ip}`);

    const message = clip(body?.message, 500) || "unknown";
    const stack = clip(body?.stack, 4000);
    const release = clip(body?.release, 40);
    const platform = clip(body?.platform, 24);
    const role = clip(body?.role, 24);
    const schoolId = clip(body?.schoolId, 32).toUpperCase();
    const fatal = body?.fatal === true;
    const id = crypto.randomUUID();

    const at = new Date().toISOString();
    const { error } = await sb.from("app_documents").upsert({
      collection: "client_crash_reports",
      school_id: PLATFORM,
      doc_id: id,
      data: {
        message,
        stack,
        release,
        platform,
        role,
        schoolId: schoolId || null,
        fatal,
        at,
      },
      updated_at: at,
    }, { onConflict: "collection,school_id,doc_id" });
    if (error) throw error;

    const webhook = (Deno.env.get("CRASH_ALERT_WEBHOOK") || "").trim();
    if (webhook && /^https:\/\//i.test(webhook)) {
      const text = [
        fatal ? "FATAL MayaBela crash" : "MayaBela crash",
        message,
        `release=${release || "?"} platform=${platform || "?"}`,
        `role=${role || "?"} school=${schoolId || "?"}`,
      ].join("\n");
      try {
        await fetch(webhook, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text, content: text }),
        });
      } catch (alertErr) {
        console.error("crash alert webhook failed", alertErr);
      }
    }

    return jsonResponse({ ok: true, id });
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse("Too many reports.", 429, "rate_limited");
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

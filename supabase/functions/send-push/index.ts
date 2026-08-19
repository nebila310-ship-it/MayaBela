// send-push: fans an app_notifications row out to device FCM tokens.
//
// Triggered by a database trigger (pg_net) whenever a notification document
// is inserted into app_documents. Authenticated with the PUSH_TRIGGER_SECRET
// header rather than a user JWT. The function re-reads the notification row
// itself, so a forged request can only re-send content that actually exists.
//
// Secrets required:
//   FCM_SERVICE_ACCOUNT_B64 - base64 of the Firebase service account JSON
//   PUSH_TRIGGER_SECRET     - shared secret checked against x-push-secret
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";

function adminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}

function b64urlBytes(bytes: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(bytes)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64url(text: string): string {
  return btoa(unescape(encodeURIComponent(text)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const raw = atob(body);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

let cachedToken: { token: string; exp: number } | null = null;

async function fcmAccessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp > now + 60) return cachedToken.token;

  const unsigned = `${b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${
    b64url(JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }))
  }`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64urlBytes(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=${encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")}&assertion=${jwt}`,
  });
  const body = await res.json();
  if (!body.access_token) throw new Error(`token exchange failed: ${JSON.stringify(body)}`);
  cachedToken = { token: body.access_token, exp: now + 3300 };
  return body.access_token;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const secret = Deno.env.get("PUSH_TRIGGER_SECRET") || "";
    if (!secret || req.headers.get("x-push-secret") !== secret) {
      return errorResponse("Unauthorized.", 401, "denied");
    }

    const { doc_id } = await req.json();
    if (!doc_id) return errorResponse("doc_id required.", 400, "invalid");

    const sb = adminClient();
    const { data: row } = await sb
      .from("app_documents")
      .select("school_id,data")
      .eq("collection", "app_notifications")
      .eq("doc_id", doc_id)
      .maybeSingle();
    if (!row) return errorResponse("Notification not found.", 404, "not_found");

    const n = row.data as Record<string, unknown>;
    const schoolId = String(row.school_id || n.schoolId || "");
    const recipientRole = String(n.recipientRole || "").trim();
    const targetStudentId = String(n.targetStudentId || "").trim().toUpperCase();
    const title = String(n.title || "MayaBela");
    const body = String(n.body || "");
    if (!schoolId) return jsonResponse({ ok: true, sent: 0, reason: "no school" });

    // Collect candidate tokens for the school.
    const { data: tokenRows } = await sb
      .from("app_documents")
      .select("doc_id,data")
      .eq("collection", "fcm_tokens")
      .eq("school_id", schoolId);
    let candidates = (tokenRows || []).map((t) => ({
      docId: t.doc_id as string,
      token: String((t.data as Record<string, unknown>).token || ""),
      roleKey: String((t.data as Record<string, unknown>).roleKey || ""),
      username: String((t.data as Record<string, unknown>).username || "").toLowerCase(),
    })).filter((t) => t.token);

    if (recipientRole) {
      candidates = candidates.filter((t) => t.roleKey === recipientRole);
    }

    // Student-targeted parent notifications go only to linked parents.
    if (targetStudentId && recipientRole === "parent") {
      const { data: accountRows } = await sb
        .from("app_documents")
        .select("doc_id,data")
        .eq("collection", "app_auth_accounts")
        .eq("school_id", schoolId);
      const linked = new Set<string>();
      for (const a of accountRows || []) {
        const d = a.data as Record<string, unknown>;
        const ids = (Array.isArray(d.linkedStudentIds) ? d.linkedStudentIds : [])
          .map((s) => String(s).toUpperCase());
        const single = String(d.linkedStudentId || "").toUpperCase();
        if (ids.includes(targetStudentId) || single === targetStudentId) {
          linked.add(String(d.username || a.doc_id).toLowerCase());
        }
      }
      candidates = candidates.filter((t) => linked.has(t.username));
    }

    if (candidates.length === 0) {
      return jsonResponse({ ok: true, sent: 0 });
    }

    const sa = JSON.parse(atob(Deno.env.get("FCM_SERVICE_ACCOUNT_B64") || ""));
    const accessToken = await fcmAccessToken(sa);
    const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let sent = 0;
    const staleDocs: string[] = [];
    await Promise.all(candidates.map(async (c) => {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: c.token,
            notification: { title, body },
            data: {
              type: String(n.type || "general"),
              notificationId: doc_id,
            },
            android: { priority: "HIGH" },
          },
        }),
      });
      if (res.ok) {
        sent++;
        return;
      }
      const err = await res.json().catch(() => ({}));
      const code = err?.error?.details?.[0]?.errorCode || err?.error?.status || "";
      if (code === "UNREGISTERED" || code === "NOT_FOUND" || res.status === 404) {
        staleDocs.push(c.docId);
      } else {
        console.error(`FCM send failed (${res.status}): ${JSON.stringify(err).slice(0, 300)}`);
      }
    }));

    // Prune tokens for uninstalled/expired devices.
    if (staleDocs.length > 0) {
      await sb.from("app_documents")
        .delete()
        .eq("collection", "fcm_tokens")
        .in("doc_id", staleDocs);
    }

    return jsonResponse({ ok: true, sent, pruned: staleDocs.length });
  } catch (e) {
    console.error(e);
    return errorResponse(String(e?.message || e), 500);
  }
});

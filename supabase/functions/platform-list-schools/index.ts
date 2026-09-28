import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { adminClient, normalizeEmail } from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";

function userFacingEmail(value: unknown): string | null {
  const email = normalizeEmail(value);
  if (!email) return null;
  if (email.endsWith(".mayabela.local")) return null;
  return email;
}

/**
 * Returns school_registry documents for the platform console.
 * Requires plaintext owner PIN (never accept a client-supplied hash).
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const sb = adminClient();
    await authorizePlatformOwner(sb, req, body?.ownerPin);

    const { data, error } = await sb
      .from("app_documents")
      .select("doc_id, data, school_id")
      .eq("collection", "school_registry")
      .limit(2000);
    if (error) throw error;

    const emailBySchool = new Map<string, string>();
    try {
      const { data: accounts } = await sb
        .from("app_documents")
        .select("school_id, data")
        .eq("collection", "app_auth_accounts")
        .limit(5000);
      for (const row of accounts || []) {
        const account = (row.data || {}) as Record<string, unknown>;
        if (account.roleKey !== "admin") continue;
        const email = userFacingEmail(account.email);
        if (!email) continue;
        const sid = String(row.school_id || account.schoolId || "")
          .trim()
          .toUpperCase();
        if (sid && !emailBySchool.has(sid)) emailBySchool.set(sid, email);
      }
    } catch (_) {
      /* list still works without account emails */
    }

    const schools = (data || []).map((row) => {
      const raw = { ...((row.data || {}) as Record<string, unknown>) };
      // Never return bootstrap passwords to the console payload.
      delete raw.adminInitialPassword;
      delete raw.password;
      delete raw.passwordHash;
      const id = String(raw.id || row.doc_id || row.school_id || "")
        .trim()
        .toUpperCase();
      const stored = userFacingEmail(raw.adminEmail);
      raw.adminEmail = stored || emailBySchool.get(id) || null;
      return {
        ...raw,
        id,
      };
    }).filter((s) => typeof s.id === "string" && s.id.length > 0);

    return jsonResponse({ schools });
  } catch (e) {
    const msg = String(e?.message || e);
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
    return errorResponse(msg, 500);
  }
});

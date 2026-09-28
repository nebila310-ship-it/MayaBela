import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { adminClient } from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";

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

    const schools = (data || []).map((row) => {
      const raw = { ...((row.data || {}) as Record<string, unknown>) };
      // Never return bootstrap passwords to the console payload.
      delete raw.adminInitialPassword;
      delete raw.password;
      delete raw.passwordHash;
      const id = String(raw.id || row.doc_id || row.school_id || "")
        .trim()
        .toUpperCase();
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

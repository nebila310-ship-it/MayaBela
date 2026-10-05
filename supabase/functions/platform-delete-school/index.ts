import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  PLATFORM_SCHOOL_ID,
  adminClient,
} from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";

/**
 * Permanently remove a school tenant from cloud.
 * Owner console has no school JWT, so this uses the service role + owner PIN.
 * Deletes school_registry and all app_documents for that school_id.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const sb = adminClient();
    await authorizePlatformOwner(sb, req, body?.ownerPin);

    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    if (!schoolId || schoolId.length < 3) {
      return errorResponse("Invalid school id.", 400, "invalid");
    }
    if (schoolId === PLATFORM_SCHOOL_ID) {
      return errorResponse("Cannot delete the platform record.", 400, "invalid");
    }

    const { error: docsError, count } = await sb
      .from("app_documents")
      .delete({ count: "exact" })
      .eq("school_id", schoolId);
    if (docsError) throw docsError;

    // Registry row is keyed by doc_id = school id; catch any row that
    // missed school_id matching.
    const { error: registryError } = await sb
      .from("app_documents")
      .delete()
      .eq("collection", "school_registry")
      .eq("doc_id", schoolId);
    if (registryError) throw registryError;

    return jsonResponse({
      ok: true,
      schoolId,
      deletedDocuments: count ?? 0,
    });
  } catch (e) {
    const msg = String((e as Error)?.message || e);
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
    return errorResponse(msg, 500, "invalid");
  }
});

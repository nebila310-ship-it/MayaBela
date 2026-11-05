import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  PLATFORM_SCHOOL_ID,
  adminClient,
  clientIp,
} from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";
import { logSecurityEvent } from "../_shared/security_events.ts";

/**
 * Remove a school tenant from the live tables.
 * Owner console has no school JWT, so this uses the service role + owner PIN.
 * Moves school_registry and all app_documents for that school_id into a
 * restorable archive (platform_restore_school); purge is possible after 30 days.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const sb = adminClient();
    await authorizePlatformOwner(sb, req, body?.ownerPin, body?.ownerSession);

    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    if (!schoolId || schoolId.length < 3) {
      return errorResponse("Invalid school id.", 400, "invalid");
    }
    if (schoolId === PLATFORM_SCHOOL_ID) {
      return errorResponse("Cannot delete the platform record.", 400, "invalid");
    }

    // Archive (restorable) instead of a hard delete. If the archive migration
    // is not applied yet this fails and nothing is removed.
    const { data: archived, error: archiveError } = await sb.rpc(
      "platform_archive_school",
      { p_school_id: schoolId },
    );
    if (archiveError) throw archiveError;
    const result = (archived ?? {}) as { archiveId?: string; documents?: number };

    await logSecurityEvent(sb, {
      type: "school_archived",
      outcome: "success",
      schoolId,
      ip: clientIp(req),
      detail: { archiveId: result.archiveId ?? null, documents: result.documents ?? 0 },
    });

    return jsonResponse({
      ok: true,
      schoolId,
      deletedDocuments: result.documents ?? 0,
      archived: true,
      archiveId: result.archiveId ?? null,
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

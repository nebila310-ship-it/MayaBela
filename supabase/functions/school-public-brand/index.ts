import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  assertNotRateLimited,
  clientIp,
  getDoc,
} from "../_shared/school_auth.ts";

/**
 * Public login chrome: school name + logo style for a typed School ID.
 * No JWT — same trust model as the public school-branding logo URL.
 * Returns only display fields (never admin emails, phones, or secrets).
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    if (!schoolId || schoolId.length < 3) {
      return errorResponse("School ID is required.", 400, "invalid");
    }

    const sb = adminClient();
    const ip = clientIp(req);
    await assertNotRateLimited(
      sb,
      `public_brand_${ip}`,
      40,
      15 * 60 * 1000,
    );

    const school = await getDoc(sb, "school_registry", schoolId, schoolId) ||
      await getDoc(sb, "school_registry", schoolId);
    if (!school) {
      return errorResponse("School not found.", 404, "not_found");
    }

    const name = String(school.name || "").trim();
    if (!name) {
      return errorResponse("School not found.", 404, "not_found");
    }

    const logoStyle = String(school.logoStyle || "rectangular").trim() ||
      "rectangular";
    const isCircular = logoStyle === "circular";
    const logoUrl = String(
      (isCircular
        ? school.identityLogoUrl || school.logoUrl
        : school.logoUrl || school.identityLogoUrl) ||
        "",
    ).trim();

    return jsonResponse({
      ok: true,
      schoolId,
      name,
      logoStyle,
      logoUrl: logoUrl || null,
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
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

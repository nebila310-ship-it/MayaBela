import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { adminClient, getDoc, upsertDoc } from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";

function brandingFile(kind: string): string {
  return kind === "identity" || kind === "circular"
    ? "identity.jpg"
    : "logo.jpg";
}

function authenticatedUrl(publicUrl: string): string {
  return publicUrl.replace(
    "/storage/v1/object/public/",
    "/storage/v1/object/authenticated/",
  );
}

/**
 * Platform-owner logo upload. Uses the service role so logos can be stored
 * without a school-scoped JWT (owner console has no school session).
 * kind: banner/logo (rectangular) or identity/circular.
 *
 * Also writes logoUrl / identityLogoUrl onto school_registry so leaving the
 * owner console and coming back still shows the saved image.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const sb = adminClient();
    await authorizePlatformOwner(sb, req, body?.ownerPin);

    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    if (!schoolId || schoolId.length < 2) {
      return errorResponse("Invalid school id.", 400, "invalid");
    }

    const b64 = String(body?.bytesBase64 || "").trim();
    if (!b64 || b64.length < 32) {
      return errorResponse("Missing image data.", 400, "invalid");
    }

    let bytes: Uint8Array;
    try {
      const bin = atob(b64);
      bytes = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    } catch {
      return errorResponse("Invalid image encoding.", 400, "invalid");
    }
    if (bytes.length > 4_500_000) {
      return errorResponse("Image too large.", 400, "too_large");
    }

    const kind = String(body?.kind || body?.style || "banner").trim().toLowerCase();
    const file = brandingFile(kind);
    const isIdentity = file === "identity.jpg";
    const path = `schools/${schoolId}/branding/${file}`;
    const options = {
      contentType: "image/jpeg",
      upsert: true,
      cacheControl: "60",
    };

    let upErr = (await sb.storage.from("school-files").upload(path, bytes, options))
      .error;
    if (upErr) {
      const retry = await sb.storage.from("school-files").update(path, bytes, options);
      upErr = retry.error;
    }
    if (upErr) {
      console.error(upErr);
      return errorResponse(upErr.message || "Upload failed.", 500, "upload");
    }

    const { data } = sb.storage.from("school-files").getPublicUrl(path);
    const cacheBust = Date.now();
    const url = `${authenticatedUrl(data.publicUrl)}?v=${cacheBust}`;

    try {
      const existing =
        (await getDoc(sb, "school_registry", schoolId, schoolId)) ||
        (await getDoc(sb, "school_registry", schoolId)) ||
        {};
      const merged: Record<string, unknown> = {
        ...existing,
        id: schoolId,
        schoolId,
        updatedAt: new Date().toISOString(),
        logoStyle: isIdentity ? "circular" : "rectangular",
      };
      if (isIdentity) {
        merged.identityLogoUrl = url;
      } else {
        merged.logoUrl = url;
      }
      await upsertDoc(sb, "school_registry", schoolId, merged, schoolId);
    } catch (regErr) {
      console.error("platform-upload-logo registry persist failed", regErr);
    }

    return jsonResponse({ ok: true, url, path, kind: file });
  } catch (e) {
    const msg = String((e as Error)?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse("Too many attempts. Try again later.", 429, "rate_limited");
    }
    if (msg.includes("owner_pin")) {
      return errorResponse("Owner PIN required.", 401, "unauthorized");
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

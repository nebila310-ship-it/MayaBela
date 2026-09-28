import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  getDoc,
} from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";

/**
 * Platform-owner logo upload. Uses the service role so logos can be stored
 * without a school-scoped JWT (owner console has no school session).
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

    const path = `schools/${schoolId}/branding/logo.jpg`;
    const { error: upErr } = await sb.storage
      .from("school-files")
      .upload(path, bytes, {
        contentType: "image/jpeg",
        upsert: true,
      });
    if (upErr) {
      console.error(upErr);
      return errorResponse(upErr.message || "Upload failed.", 500, "upload");
    }

    const { data } = sb.storage.from("school-files").getPublicUrl(path);
    return jsonResponse({ ok: true, url: data.publicUrl, path });
  } catch (e) {
    const msg = String(e?.message || e);
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

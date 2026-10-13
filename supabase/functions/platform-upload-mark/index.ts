import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { adminClient, getDoc, upsertDoc } from "../_shared/school_auth.ts";
import { authorizePlatformOwner } from "../_shared/platform_pin.ts";

function markFile(kind: string): { file: string; field: string } | null {
  const value = kind.trim().toLowerCase();
  if (value === "stamp") {
    return { file: "stamp.png", field: "stampUrl" };
  }
  if (
    value === "signature" ||
    value === "principal" ||
    value === "principal-signature"
  ) {
    return { file: "principal-signature.png", field: "principalSignatureUrl" };
  }
  return null;
}

async function uploadToBucket(
  sb: ReturnType<typeof adminClient>,
  bucket: string,
  path: string,
  bytes: Uint8Array,
  options: { contentType: string; upsert: boolean; cacheControl: string },
) {
  let upErr = (await sb.storage.from(bucket).upload(path, bytes, options)).error;
  if (upErr) {
    const retry = await sb.storage.from(bucket).update(path, bytes, options);
    upErr = retry.error;
  }
  return upErr;
}

async function ensurePublicBrandingBucket(sb: ReturnType<typeof adminClient>) {
  const { data } = await sb.storage.getBucket("school-branding");
  if (!data) {
    await sb.storage.createBucket("school-branding", {
      public: true,
      fileSizeLimit: 4500000,
      allowedMimeTypes: ["image/jpeg", "image/jpg", "image/png", "image/webp"],
    });
    return;
  }
  if (!data.public) {
    await sb.storage.updateBucket("school-branding", { public: true });
  }
}

/**
 * Platform-owner stamp and principal-signature upload.
 * Separate from platform-upload-logo so a stamp never replaces the school logo.
 * kind: stamp | signature.
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

    const mark = markFile(String(body?.kind || ""));
    if (!mark) {
      return errorResponse("Kind must be stamp or signature.", 400, "invalid");
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

    const path = `schools/${schoolId}/branding/${mark.file}`;
    const options = {
      contentType: "image/png",
      upsert: true,
      cacheControl: "60",
    };

    await ensurePublicBrandingBucket(sb);
    const publicErr = await uploadToBucket(
      sb,
      "school-branding",
      path,
      bytes,
      options,
    );
    if (publicErr) {
      console.error(publicErr);
      return errorResponse(publicErr.message || "Upload failed.", 500, "upload");
    }
    await uploadToBucket(sb, "school-files", path, bytes, options);

    const { data } = sb.storage.from("school-branding").getPublicUrl(path);
    const url = `${data.publicUrl}?v=${Date.now()}`;

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
        [mark.field]: url,
      };
      await upsertDoc(sb, "school_registry", schoolId, merged, schoolId);
    } catch (regErr) {
      console.error("platform-upload-mark registry persist failed", regErr);
    }

    return jsonResponse({ ok: true, url, path, kind: mark.file });
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

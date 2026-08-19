import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { adminClient, assertNotRateLimited } from "../_shared/school_auth.ts";
import {
  hashOwnerPin,
  loadOwnerPinHash,
  saveOwnerPinHash,
  verifyOwnerPinHash,
} from "../_shared/platform_pin.ts";

/**
 * Platform-owner PIN management.
 * The stored hash is NEVER returned to clients. Callers prove knowledge of the
 * plaintext PIN; the server verifies against the stored hash.
 *
 * Actions:
 *   status  → { configured: boolean }
 *   verify  → { ok: true } when ownerPin matches
 *   save    → set/change PIN (first setup or currentOwnerPin + newPin)
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const action = String(body?.action || "status").trim().toLowerCase();
    const sb = adminClient();
    const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
      req.headers.get("cf-connecting-ip") ||
      "unknown";

    if (action === "load") {
      // Backward-compatible alias — never returns the hash.
      await assertNotRateLimited(sb, `platform_pin_status_${ip}`);
      const existing = await loadOwnerPinHash(sb);
      return jsonResponse({ configured: !!existing, pinHash: null });
    }

    if (action === "status") {
      await assertNotRateLimited(sb, `platform_pin_status_${ip}`);
      const existing = await loadOwnerPinHash(sb);
      return jsonResponse({ configured: !!existing });
    }

    if (action === "verify") {
      await assertNotRateLimited(sb, `platform_pin_verify_${ip}`);
      const existing = await loadOwnerPinHash(sb);
      if (!existing) {
        return errorResponse("Owner PIN is not configured.", 404, "not_configured");
      }
      const ok = await verifyOwnerPinHash(String(body?.ownerPin || ""), existing);
      if (!ok) {
        return errorResponse("Invalid owner PIN.", 401, "unauthorized");
      }
      return jsonResponse({ ok: true });
    }

    if (action === "save") {
      await assertNotRateLimited(sb, `platform_pin_save_${ip}`);
      const newPin = String(body?.newPin || body?.ownerPin || "").trim();
      if (newPin.length < 6) {
        return errorResponse("PIN must be at least 6 characters.", 400, "invalid");
      }
      const existing = await loadOwnerPinHash(sb);
      if (existing) {
        const current = String(body?.currentOwnerPin || "").trim();
        const ok = await verifyOwnerPinHash(current, existing);
        if (!ok) {
          return errorResponse(
            "Current owner PIN is required to change the PIN.",
            401,
            "unauthorized",
          );
        }
      }
      const pinHash = await hashOwnerPin(newPin);
      await saveOwnerPinHash(sb, pinHash);
      return jsonResponse({ ok: true, configured: true });
    }

    return errorResponse("Unknown action.", 400, "invalid");
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse("Too many attempts. Try again later.", 429, "rate_limited");
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});

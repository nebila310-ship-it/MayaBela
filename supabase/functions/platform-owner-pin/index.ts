import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  assertNotRateLimited,
  clientIp,
  PLATFORM_AUTHED_RATE_LIMIT,
  PLATFORM_AUTHED_RATE_WINDOW_MS,
  LOGIN_RATE_LIMIT,
  LOGIN_RATE_WINDOW_MS,
} from "../_shared/school_auth.ts";
import {
  createOwnerPinHashIfAbsent,
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
function constantTimeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  let diff = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i += 1) {
    diff |= (left[i] || 0) ^ (right[i] || 0);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const action = String(body?.action || "status").trim().toLowerCase();
    const sb = adminClient();
    const ip = clientIp(req);

    if (action === "load") {
      // Backward-compatible alias — never returns the hash.
      await assertNotRateLimited(
        sb,
        `platform_pin_status_${ip}`,
        PLATFORM_AUTHED_RATE_LIMIT,
        PLATFORM_AUTHED_RATE_WINDOW_MS,
      );
      const existing = await loadOwnerPinHash(sb);
      return jsonResponse({ configured: !!existing, pinHash: null });
    }

    if (action === "status") {
      await assertNotRateLimited(
        sb,
        `platform_pin_status_${ip}`,
        PLATFORM_AUTHED_RATE_LIMIT,
        PLATFORM_AUTHED_RATE_WINDOW_MS,
      );
      const existing = await loadOwnerPinHash(sb);
      return jsonResponse({ configured: !!existing });
    }

    if (action === "verify") {
      await assertNotRateLimited(
        sb,
        `platform_pin_verify_${ip}`,
        LOGIN_RATE_LIMIT,
        LOGIN_RATE_WINDOW_MS,
      );
      const existing = await loadOwnerPinHash(sb);
      if (!existing) {
        return errorResponse("Owner PIN is not configured.", 404, "not_configured");
      }
      const suppliedPin = String(body?.ownerPin || "");
      const ok = await verifyOwnerPinHash(suppliedPin, existing);
      if (!ok) {
        return errorResponse("Invalid owner PIN.", 401, "unauthorized");
      }
      // Upgrade legacy fast hashes after successful proof of the PIN.
      if (existing.startsWith("sha256:")) {
        await saveOwnerPinHash(sb, await hashOwnerPin(suppliedPin));
      }
      return jsonResponse({ ok: true });
    }

    if (action === "save") {
      await assertNotRateLimited(
        sb,
        `platform_pin_save_${ip}`,
        LOGIN_RATE_LIMIT,
        LOGIN_RATE_WINDOW_MS,
      );
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
      } else {
        // First-time setup must be provisioned out-of-band by the deployment
        // operator. A client-generated OTP is not server-side proof of ownership.
        const expectedSetupSecret = Deno.env.get("PLATFORM_PIN_SETUP_SECRET") || "";
        const suppliedSetupSecret = String(body?.setupSecret || "");
        if (!expectedSetupSecret || !constantTimeEqual(suppliedSetupSecret, expectedSetupSecret)) {
          return errorResponse(
            "Initial owner PIN setup is not authorized. Contact the platform administrator.",
            403,
            "setup_not_authorized",
          );
        }
      }
      const pinHash = await hashOwnerPin(newPin);
      if (existing) {
        await saveOwnerPinHash(sb, pinHash);
      } else {
        const initialized = await createOwnerPinHashIfAbsent(sb, pinHash);
        if (!initialized) {
          return errorResponse(
            "Owner PIN was initialized by another request. Verify the existing PIN.",
            409,
            "already_configured",
          );
        }
      }
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

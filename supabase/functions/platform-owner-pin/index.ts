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
  ownerPinFailureBuckets,
  saveOwnerPinHash,
  verifyOwnerPinWithLockout,
} from "../_shared/platform_pin.ts";
import {
  mintOwnerSession,
  ownerTotpSecret,
  TOTP_STEP_MS,
  verifyOwnerSession,
  verifyTotp,
} from "../_shared/owner_factor.ts";
import {
  assertNotLocked,
  recordFailure,
  supabaseLimitStore,
} from "../_shared/abuse_limits.ts";
import { logSecurityEvent } from "../_shared/security_events.ts";

/**
 * Platform-owner PIN management.
 * The stored hash is NEVER returned to clients. Callers prove knowledge of the
 * plaintext PIN; the server verifies against the stored hash.
 *
 * Actions:
 *   status  → { configured: boolean, totpRequired: boolean }
 *   verify  → { ok: true, ownerSession? } when ownerPin (+ totpCode) matches
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

type AdminClient = ReturnType<typeof adminClient>;

/** Accepts each authenticator code once; failures share the PIN buckets. */
async function verifyOwnerTotp(
  sb: AdminClient,
  req: Request,
  totpSecret: string,
  code: unknown,
): Promise<boolean> {
  const store = supabaseLimitStore(sb);
  const ip = clientIp(req);
  const step = await verifyTotp(totpSecret, code);
  if (step != null) {
    const used = { key: `owner_totp_used_${step}`, limit: 1, windowMs: 3 * TOTP_STEP_MS };
    try {
      await assertNotLocked(store, [used]);
      await recordFailure(store, [used]);
      return true;
    } catch {
      // Replayed code: fall through and count as a failure.
    }
  }
  await recordFailure(store, ownerPinFailureBuckets(ip));
  await logSecurityEvent(sb, { type: "owner_totp", outcome: "failure", ip });
  return false;
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
    const totpSecret = ownerTotpSecret();

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
      return jsonResponse({ configured: !!existing, totpRequired: !!totpSecret });
    }

    if (action === "verify") {
      const existing = await loadOwnerPinHash(sb);
      if (!existing) {
        return errorResponse("Owner PIN is not configured.", 404, "not_configured");
      }
      const suppliedPin = String(body?.ownerPin || "");
      try {
        await verifyOwnerPinWithLockout(sb, req, suppliedPin);
      } catch (e) {
        const msg = String((e as Error)?.message || e);
        if (msg.includes("owner_pin_invalid")) {
          return errorResponse("Invalid owner PIN.", 401, "unauthorized");
        }
        throw e;
      }
      if (totpSecret) {
        if (!String(body?.totpCode || "").trim()) {
          return errorResponse("Authenticator code required.", 401, "totp_required");
        }
        if (!(await verifyOwnerTotp(sb, req, totpSecret, body?.totpCode))) {
          return errorResponse("Invalid authenticator code.", 401, "totp_invalid");
        }
      }
      // Upgrade legacy fast hashes after successful proof of the PIN.
      if (existing.startsWith("sha256:")) {
        await saveOwnerPinHash(sb, await hashOwnerPin(suppliedPin));
      }
      await logSecurityEvent(sb, { type: "owner_unlock", outcome: "success", ip });
      if (!totpSecret) return jsonResponse({ ok: true });
      const session = await mintOwnerSession(totpSecret);
      return jsonResponse({
        ok: true,
        ownerSession: session.token,
        ownerSessionExpiresAt: session.expiresAt,
      });
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
        try {
          await verifyOwnerPinWithLockout(sb, req, current);
        } catch (e) {
          const msg = String((e as Error)?.message || e);
          if (msg.includes("owner_pin_invalid")) {
            return errorResponse(
              "Current owner PIN is required to change the PIN.",
              401,
              "unauthorized",
            );
          }
          throw e;
        }
        if (totpSecret && !(await verifyOwnerSession(totpSecret, body?.ownerSession))) {
          return errorResponse(
            "Unlock with your authenticator code before changing the PIN.",
            401,
            "totp_required",
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
      await logSecurityEvent(sb, { type: "owner_pin_changed", outcome: "success", ip });
      return jsonResponse({ ok: true, configured: true });
    }

    return errorResponse("Unknown action.", 400, "invalid");
  } catch (e) {
    const msg = String((e as Error)?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse("Too many attempts. Try again later.", 429, "rate_limited");
    }
    console.error(e);
    return errorResponse("Request failed.", 500, "invalid");
  }
});

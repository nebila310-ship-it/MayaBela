/**
 * Platform-owner PIN helpers.
 * Client PasswordHashService format: sha256:<salt>:<hexDigest>
 * where digest = SHA-256(utf8(`${salt}::${plain}`)).
 */
import {
  adminClient,
  assertNotRateLimited,
  clientIp,
  getDoc,
  LOGIN_RATE_LIMIT,
  LOGIN_RATE_WINDOW_MS,
  PLATFORM_SCHOOL_ID,
  upsertDoc,
} from "./school_auth.ts";

type AdminClient = ReturnType<typeof adminClient>;

export async function sha256Hex(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Verify plaintext PIN against stored `sha256:salt:digest` hash. */
export async function verifyOwnerPinHash(
  plain: string,
  stored: string,
): Promise<boolean> {
  const pin = String(plain || "").trim();
  const hash = String(stored || "").trim();
  if (pin.length < 6 || !hash) return false;
  if (!hash.startsWith("sha256:")) {
    // Legacy plaintext (should not exist) — reject in production paths.
    return false;
  }
  const body = hash.slice("sha256:".length);
  const parts = body.split(":");
  if (parts.length !== 2) return false;
  const [salt, expected] = parts;
  const digest = await sha256Hex(`${salt}::${pin}`);
  return digest === expected;
}

export async function hashOwnerPin(plain: string): Promise<string> {
  const pin = String(plain || "").trim();
  if (pin.length < 6) throw new Error("PIN too short");
  const saltBytes = new Uint8Array(16);
  crypto.getRandomValues(saltBytes);
  let bin = "";
  for (const b of saltBytes) bin += String.fromCharCode(b);
  const salt = btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const digest = await sha256Hex(`${salt}::${pin}`);
  return `sha256:${salt}:${digest}`;
}

export async function loadOwnerPinHash(
  sb: AdminClient,
): Promise<string | null> {
  const doc = await getDoc(sb, "platform_secrets", "owner_pin");
  const pinHash = typeof doc?.pinHash === "string" ? doc.pinHash : null;
  return pinHash && pinHash.startsWith("sha256:") ? pinHash : null;
}

/**
 * Authorize a platform edge call with the plaintext owner PIN.
 * Never accept a client-supplied hash as proof of knowledge.
 */
export async function assertOwnerPin(
  sb: AdminClient,
  ownerPin: unknown,
): Promise<void> {
  const existing = await loadOwnerPinHash(sb);
  if (!existing) {
    throw new Error("owner_pin_not_configured");
  }
  const ok = await verifyOwnerPinHash(String(ownerPin || ""), existing);
  if (!ok) {
    throw new Error("owner_pin_invalid");
  }
}

/**
 * Valid owner PIN authorizes the call. Failed PIN guesses stay rate-limited.
 * Successful saves/list/create must not share the school-login 8/15min cap.
 */
export async function authorizePlatformOwner(
  sb: AdminClient,
  req: Request,
  ownerPin: unknown,
): Promise<void> {
  try {
    await assertOwnerPin(sb, ownerPin);
  } catch (e) {
    const msg = String((e as Error)?.message || e);
    if (msg.includes("owner_pin")) {
      await assertNotRateLimited(
        sb,
        `platform_pin_fail_${clientIp(req)}`,
        LOGIN_RATE_LIMIT,
        LOGIN_RATE_WINDOW_MS,
      );
    }
    throw e;
  }
}

export async function saveOwnerPinHash(
  sb: AdminClient,
  pinHash: string,
): Promise<void> {
  await upsertDoc(
    sb,
    "platform_secrets",
    "owner_pin",
    {
      pinHash,
      updatedAt: new Date().toISOString(),
    },
    PLATFORM_SCHOOL_ID,
  );
}

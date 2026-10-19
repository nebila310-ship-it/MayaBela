/**
 * Platform-owner PIN helpers.
 * New hashes use PBKDF2-SHA256; legacy salted SHA-256 hashes are upgraded on verification.
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

const PIN_PBKDF2_ITERATIONS = 210_000;

async function pbkdf2Hex(pin: string, salt: string, iterations: number): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(pin),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits({
    name: "PBKDF2",
    salt: new TextEncoder().encode(salt),
    iterations,
    hash: "SHA-256",
  }, key, 256);
  return [...new Uint8Array(bits)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeStringEqual(a: string, b: string): boolean {
  let diff = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i += 1) {
    diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  }
  return diff === 0;
}

/** Verify legacy sha256 or current PBKDF2-SHA256 owner PIN hashes. */
export async function verifyOwnerPinHash(
  plain: string,
  stored: string,
): Promise<boolean> {
  const pin = String(plain || "").trim();
  const hash = String(stored || "").trim();
  if (pin.length < 6 || !hash) return false;
  const parts = hash.split(":");
  if (parts[0] === "pbkdf2" && parts.length === 4) {
    const iterations = Number(parts[1]);
    if (!Number.isInteger(iterations) || iterations < 100_000 || iterations > 1_000_000) {
      return false;
    }
    const digest = await pbkdf2Hex(pin, parts[2], iterations);
    return constantTimeStringEqual(digest, parts[3]);
  }
  if (parts[0] === "sha256" && parts.length === 3) {
    const digest = await sha256Hex(`${parts[1]}::${pin}`);
    return constantTimeStringEqual(digest, parts[2]);
  }
  // Legacy plaintext hashes are deliberately rejected.
  return false;
}

export async function hashOwnerPin(plain: string): Promise<string> {
  const pin = String(plain || "").trim();
  if (pin.length < 6) throw new Error("PIN too short");
  const saltBytes = new Uint8Array(16);
  crypto.getRandomValues(saltBytes);
  let bin = "";
  for (const b of saltBytes) bin += String.fromCharCode(b);
  const salt = btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const digest = await pbkdf2Hex(pin, salt, PIN_PBKDF2_ITERATIONS);
  return `pbkdf2:${PIN_PBKDF2_ITERATIONS}:${salt}:${digest}`;
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

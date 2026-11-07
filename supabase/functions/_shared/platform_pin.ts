/**
 * Platform-owner PIN helpers.
 * New hashes use PBKDF2-SHA256; legacy salted SHA-256 hashes are upgraded on verification.
 */
import {
  adminClient,
  clientIp,
  getDoc,
  PLATFORM_SCHOOL_ID,
  upsertDoc,
} from "./school_auth.ts";
import {
  assertNotLocked,
  type LimitBucket,
  type LimitStore,
  recordFailure,
  supabaseLimitStore,
} from "./abuse_limits.ts";
import { ownerTotpSecret, verifyOwnerSession } from "./owner_factor.ts";
import { logSecurityEvent } from "./security_events.ts";

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
  return pinHash && (pinHash.startsWith("sha256:") || pinHash.startsWith("pbkdf2:"))
    ? pinHash
    : null;
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
 * Owner PIN failure buckets. The global buckets cannot be bypassed by
 * changing the client IP header; they lock only the owner console, never
 * school logins.
 */
export function ownerPinFailureBuckets(ip: string): LimitBucket[] {
  return [
    { key: "owner_pin_fail_global", limit: 10, windowMs: 15 * 60 * 1000 },
    { key: "owner_pin_fail_day", limit: 30, windowMs: 24 * 60 * 60 * 1000 },
    { key: `owner_pin_fail_ip_${ip}`, limit: 5, windowMs: 15 * 60 * 1000 },
  ];
}

/**
 * Checks the PIN lockout before testing the PIN, and counts only failures,
 * so a correct guess is refused while the lock is active.
 */
export async function verifyOwnerPinWithLockout(
  sb: AdminClient,
  req: Request,
  ownerPin: unknown,
  store: LimitStore = supabaseLimitStore(sb),
): Promise<void> {
  const ip = clientIp(req);
  const buckets = ownerPinFailureBuckets(ip);
  try {
    await assertNotLocked(store, buckets);
  } catch (e) {
    await logSecurityEvent(sb, { type: "owner_pin", outcome: "blocked", ip });
    throw e;
  }
  try {
    await assertOwnerPin(sb, ownerPin);
  } catch (e) {
    const msg = String((e as Error)?.message || e);
    if (msg.includes("owner_pin_invalid")) {
      await recordFailure(store, buckets);
      await logSecurityEvent(sb, { type: "owner_pin", outcome: "failure", ip });
    }
    throw e;
  }
}

/**
 * Valid owner PIN (and, when the authenticator is enabled, a valid owner
 * session from `platform-owner-pin` verify) authorizes the call.
 */
export async function authorizePlatformOwner(
  sb: AdminClient,
  req: Request,
  ownerPin: unknown,
  ownerSession?: unknown,
): Promise<void> {
  await verifyOwnerPinWithLockout(sb, req, ownerPin);
  const totpSecret = ownerTotpSecret();
  if (totpSecret && !(await verifyOwnerSession(totpSecret, ownerSession))) {
    await logSecurityEvent(sb, {
      type: "owner_session",
      outcome: "failure",
      ip: clientIp(req),
    });
    throw new Error("owner_pin_session_required");
  }
}

/** Atomically create the first owner PIN; never overwrite a concurrent setup. */
export async function createOwnerPinHashIfAbsent(
  sb: AdminClient,
  pinHash: string,
): Promise<boolean> {
  const now = new Date().toISOString();
  const { error } = await sb.from("app_documents").insert({
    collection: "platform_secrets",
    doc_id: "owner_pin",
    school_id: PLATFORM_SCHOOL_ID,
    data: {
      pinHash,
      updatedAt: now,
    },
    updated_at: now,
  });
  if (error) {
    // PostgreSQL unique violation: another setup request won the race.
    if (error.code === "23505") return false;
    throw error;
  }
  return true;
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

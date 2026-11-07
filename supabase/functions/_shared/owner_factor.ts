/**
 * Optional second factor for the platform owner (RFC 6238 TOTP).
 *
 * Enabled only when the edge secret PLATFORM_OWNER_TOTP_SECRET (base32) is
 * set. While enabled, `platform-owner-pin` verify needs PIN + authenticator
 * code and returns a short-lived signed owner session that every platform
 * function requires in addition to the PIN.
 */

const BASE32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
export const TOTP_STEP_MS = 30_000;
export const OWNER_SESSION_TTL_MS = 8 * 60 * 60 * 1000;

export function ownerTotpSecret(): string | null {
  const raw = (Deno.env.get("PLATFORM_OWNER_TOTP_SECRET") || "").trim();
  return raw.length >= 16 ? raw : null;
}

export function base32Decode(input: string): Uint8Array<ArrayBuffer> {
  const clean = input.toUpperCase().replace(/[\s=-]/g, "");
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const ch of clean) {
    const idx = BASE32.indexOf(ch);
    if (idx < 0) throw new Error("invalid_base32");
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return new Uint8Array(out);
}

export async function hotp(secret: Uint8Array<ArrayBuffer>, counter: number): Promise<string> {
  const msg = new Uint8Array(8);
  let c = counter;
  for (let i = 7; i >= 0; i -= 1) {
    msg[i] = c & 0xff;
    c = Math.floor(c / 256);
  }
  const key = await crypto.subtle.importKey(
    "raw",
    secret,
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, msg));
  const offset = mac[mac.length - 1] & 0x0f;
  const bin = ((mac[offset] & 0x7f) << 24) |
    (mac[offset + 1] << 16) |
    (mac[offset + 2] << 8) |
    mac[offset + 3];
  return String(bin % 1_000_000).padStart(6, "0");
}

/** Returns the matched time step (for replay protection) or null. */
export async function verifyTotp(
  secretBase32: string,
  code: unknown,
  nowMs: number = Date.now(),
  window = 1,
): Promise<number | null> {
  const supplied = String(code ?? "").replace(/\s/g, "");
  if (!/^\d{6}$/.test(supplied)) return null;
  const secret = base32Decode(secretBase32);
  const step = Math.floor(nowMs / TOTP_STEP_MS);
  for (let d = -window; d <= window; d += 1) {
    if ((await hotp(secret, step + d)) === supplied) return step + d;
  }
  return null;
}

function b64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function hmac(key: string, message: string): Promise<string> {
  const k = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return b64url(
    new Uint8Array(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(message))),
  );
}

function sessionKey(totpSecret: string): string {
  // Rotating either secret invalidates every outstanding owner session.
  return `owner-session:v1:${totpSecret}:${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""}`;
}

export async function mintOwnerSession(
  totpSecret: string,
  nowMs: number = Date.now(),
  ttlMs: number = OWNER_SESSION_TTL_MS,
): Promise<{ token: string; expiresAt: string }> {
  const exp = nowMs + ttlMs;
  const nonce = b64url(crypto.getRandomValues(new Uint8Array(12)));
  const body = `v1.${exp}.${nonce}`;
  const sig = await hmac(sessionKey(totpSecret), body);
  return { token: `${body}.${sig}`, expiresAt: new Date(exp).toISOString() };
}

export async function verifyOwnerSession(
  totpSecret: string,
  token: unknown,
  nowMs: number = Date.now(),
): Promise<boolean> {
  const parts = String(token ?? "").split(".");
  if (parts.length !== 4 || parts[0] !== "v1") return false;
  const exp = Number(parts[1]);
  if (!Number.isFinite(exp) || exp < nowMs) return false;
  if (exp - nowMs > OWNER_SESSION_TTL_MS) return false;
  const expected = await hmac(sessionKey(totpSecret), parts.slice(0, 3).join("."));
  if (expected.length !== parts[3].length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i += 1) {
    diff |= expected.charCodeAt(i) ^ parts[3].charCodeAt(i);
  }
  return diff === 0;
}

/**
 * Generate the platform-owner authenticator secret (optional second factor).
 *
 * Writes the secret and the authenticator enrolment link to a private file
 * (mode 0600) instead of the terminal, so it does not end up in shell logs.
 *
 * Usage (from repo root):
 *   node tools/generate_owner_totp_secret.mjs [output-file]
 *
 * Then:
 *   1. Add the secret to the owner's authenticator app (manual entry or the
 *      otpauth link) and confirm it shows 6-digit codes.
 *   2. Set it as the edge secret PLATFORM_OWNER_TOTP_SECRET on the target
 *      project (staging first).
 *   3. Delete the output file.
 * Removing PLATFORM_OWNER_TOTP_SECRET turns the second factor off again.
 */
import { randomBytes } from "node:crypto";
import fs from "node:fs";

const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

function base32(bytes) {
  let bits = 0;
  let value = 0;
  let out = "";
  for (const b of bytes) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out += alphabet[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += alphabet[(value << (5 - bits)) & 31];
  return out;
}

const secret = base32(randomBytes(20));
const label = encodeURIComponent("MaJo Bridge Platform Owner");
const uri = `otpauth://totp/${label}?secret=${secret}&issuer=${encodeURIComponent("MaJo Bridge")}&algorithm=SHA1&digits=6&period=30`;
const out = process.argv[2] || "owner_totp_secret.txt";

fs.writeFileSync(
  out,
  `PLATFORM_OWNER_TOTP_SECRET=${secret}\n${uri}\n`,
  { mode: 0o600, flag: "wx" },
);
console.log(`Owner authenticator secret written to ${out} (mode 0600). Delete it after enrolment.`);

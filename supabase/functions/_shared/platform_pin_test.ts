import { hashOwnerPin, sha256Hex, verifyOwnerPinHash } from "./platform_pin.ts";

Deno.test("new platform PIN hashes use PBKDF2 and verify correctly", async () => {
  const hash = await hashOwnerPin("739184");
  if (!hash.startsWith("pbkdf2:210000:")) {
    throw new Error("New PIN hash did not use the expected PBKDF2 format.");
  }
  if (!(await verifyOwnerPinHash("739184", hash))) {
    throw new Error("Correct PIN did not verify.");
  }
  if (await verifyOwnerPinHash("739185", hash)) {
    throw new Error("Incorrect PIN unexpectedly verified.");
  }
});

Deno.test("legacy salted SHA-256 PIN hashes remain verifiable for migration", async () => {
  const salt = "legacy-salt-for-test";
  const digest = await sha256Hex(`${salt}::739184`);
  const legacyHash = `sha256:${salt}:${digest}`;
  if (!(await verifyOwnerPinHash("739184", legacyHash))) {
    throw new Error("Legacy PIN hash should remain verifiable for upgrade.");
  }
  if (await verifyOwnerPinHash("739185", legacyHash)) {
    throw new Error("Incorrect PIN unexpectedly verified against legacy hash.");
  }
});

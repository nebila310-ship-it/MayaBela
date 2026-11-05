import { hashOwnerPin, ownerPinFailureBuckets, verifyOwnerPinWithLockout } from "./platform_pin.ts";
import { assertNotLocked, memoryLimitStore, recordFailure } from "./abuse_limits.ts";
import {
  base32Decode,
  hotp,
  mintOwnerSession,
  OWNER_SESSION_TTL_MS,
  verifyOwnerSession,
  verifyTotp,
} from "./owner_factor.ts";

function expect(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

/** Minimal stand-in for the service-role client used by the PIN helpers. */
function fakeClient(pinHash: string) {
  const inserted: unknown[] = [];
  const query = {
    select: () => query,
    eq: () => query,
    maybeSingle: () => Promise.resolve({ data: { data: { pinHash } }, error: null }),
  };
  return {
    inserted,
    from: () => ({
      ...query,
      insert: (row: unknown) => {
        inserted.push(row);
        return Promise.resolve({ error: null });
      },
    }),
  };
}

function request(ip: string): Request {
  return new Request("https://example.invalid", { headers: { "x-real-ip": ip } });
}

async function outcome(p: Promise<unknown>): Promise<string> {
  try {
    await p;
    return "ok";
  } catch (e) {
    return String((e as Error).message);
  }
}

Deno.test("correct owner PIN is refused while the failure lock is active", async () => {
  const hash = await hashOwnerPin("739184");
  const sb = fakeClient(hash);
  const store = memoryLimitStore();
  // deno-lint-ignore no-explicit-any
  const client = sb as any;
  for (let i = 0; i < 5; i += 1) {
    expect(
      (await outcome(verifyOwnerPinWithLockout(client, request("1.1.1.1"), "000000", store)))
        === "owner_pin_invalid",
      "wrong PIN must be rejected",
    );
  }
  expect(
    (await outcome(verifyOwnerPinWithLockout(client, request("1.1.1.1"), "739184", store)))
      === "rate_limited",
    "correct PIN must be refused while the IP is locked",
  );
});

Deno.test("rotating the IP header does not bypass the global owner lock", async () => {
  const hash = await hashOwnerPin("739184");
  // deno-lint-ignore no-explicit-any
  const client = fakeClient(hash) as any;
  const store = memoryLimitStore();
  for (let i = 0; i < 10; i += 1) {
    await outcome(verifyOwnerPinWithLockout(client, request(`10.0.0.${i}`), "000000", store));
  }
  expect(
    (await outcome(verifyOwnerPinWithLockout(client, request("10.9.9.9"), "739184", store)))
      === "rate_limited",
    "fresh IP must still be locked by the global bucket",
  );
});

Deno.test("owner lock expires after the window", async () => {
  let now = 1_000_000;
  const store = memoryLimitStore(() => now);
  const buckets = ownerPinFailureBuckets("1.1.1.1").filter((b) => b.key.includes("_ip_"));
  for (let i = 0; i < 5; i += 1) await recordFailure(store, buckets);
  expect((await outcome(assertNotLocked(store, buckets, now))) === "rate_limited", "locked");
  now += 16 * 60 * 1000;
  expect((await outcome(assertNotLocked(store, buckets, now))) === "ok", "unlocked after window");
});

Deno.test("successful PIN checks are not counted", async () => {
  const hash = await hashOwnerPin("739184");
  // deno-lint-ignore no-explicit-any
  const client = fakeClient(hash) as any;
  const store = memoryLimitStore();
  for (let i = 0; i < 20; i += 1) {
    expect(
      (await outcome(verifyOwnerPinWithLockout(client, request("2.2.2.2"), "739184", store)))
        === "ok",
      "owner using the console must never be locked by successful calls",
    );
  }
  expect(store.rows.size === 0, "no bucket rows for successful calls");
});

Deno.test("TOTP matches the RFC 6238 SHA-1 test vector", async () => {
  // RFC 6238 Appendix B secret "12345678901234567890" in base32.
  const secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";
  expect(base32Decode(secret).length === 20, "base32 decode length");
  // T = 59s → counter 1 → 94287082 (8 digits); 6-digit form is 287082.
  expect((await hotp(base32Decode(secret), 1)) === "287082", "HOTP counter 1");
  expect((await verifyTotp(secret, "287082", 59_000)) === 1, "TOTP at T=59s");
  expect((await verifyTotp(secret, "287083", 59_000)) === null, "wrong code rejected");
  expect((await verifyTotp(secret, "abc", 59_000)) === null, "non-numeric rejected");
});

Deno.test("owner session tokens verify, expire, and resist tampering", async () => {
  const secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";
  const now = Date.now();
  const { token } = await mintOwnerSession(secret, now);
  expect(await verifyOwnerSession(secret, token, now + 1000), "fresh session valid");
  expect(
    !(await verifyOwnerSession(secret, token, now + OWNER_SESSION_TTL_MS + 1)),
    "expired session rejected",
  );
  expect(!(await verifyOwnerSession("JBSWY3DPEHPK3PXPJBSWY3DP", token, now)), "other secret rejected");
  const parts = token.split(".");
  const forged = `v1.${Number(parts[1]) + 1000}.${parts[2]}.${parts[3]}`;
  expect(!(await verifyOwnerSession(secret, forged, now)), "tampered expiry rejected");
  expect(!(await verifyOwnerSession(secret, "", now)), "missing session rejected");
});

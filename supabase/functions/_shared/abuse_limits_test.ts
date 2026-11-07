import {
  assertNotLocked,
  loginFailureBuckets,
  memoryLimitStore,
  recordFailure,
} from "./abuse_limits.ts";

function expect(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

async function locked(p: Promise<unknown>): Promise<boolean> {
  try {
    await p;
    return false;
  } catch (e) {
    return String((e as Error).message) === "rate_limited";
  }
}

const SECRET = "test-hmac-key";

Deno.test("spraying one password across a school is stopped; other passwords still work", async () => {
  const store = memoryLimitStore();
  // 40 different students, same guessed password, from rotating IPs.
  for (let i = 0; i < 40; i += 1) {
    const buckets = await loginFailureBuckets("SCH1", `10.0.${i}.1`, "Default@2026", SECRET);
    expect(!(await locked(assertNotLocked(store, buckets))), `attempt ${i} allowed`);
    await recordFailure(store, buckets);
  }
  const sprayed = await loginFailureBuckets("SCH1", "10.9.9.9", "Default@2026", SECRET);
  expect(await locked(assertNotLocked(store, sprayed)), "41st spray attempt is locked");

  const ownPassword = await loginFailureBuckets("SCH1", "10.9.9.9", "my-own-pass-123", SECRET);
  expect(!(await locked(assertNotLocked(store, ownPassword))), "a student's own password is unaffected");

  const otherSchool = await loginFailureBuckets("SCH2", "10.9.9.9", "Default@2026", SECRET);
  expect(!(await locked(assertNotLocked(store, otherSchool))), "other schools are unaffected");
});

Deno.test("a school lab behind one IP can absorb normal typing mistakes", async () => {
  const store = memoryLimitStore();
  for (let i = 0; i < 150; i += 1) {
    const buckets = await loginFailureBuckets("SCH1", "196.188.1.1", `typo-${i}`, SECRET);
    await recordFailure(store, buckets);
  }
  const next = await loginFailureBuckets("SCH1", "196.188.1.1", "correct-pass", SECRET);
  expect(!(await locked(assertNotLocked(store, next))), "150 mistakes from one lab IP do not lock it");
  for (let i = 0; i < 50; i += 1) {
    await recordFailure(store, await loginFailureBuckets("SCH1", "196.188.1.1", `x-${i}`, SECRET));
  }
  expect(await locked(assertNotLocked(store, next)), "200 failures from one IP lock that IP");
});

Deno.test("bucket keys never contain the password", async () => {
  const buckets = await loginFailureBuckets("SCH1", "1.1.1.1", "Secret#Pass99", SECRET);
  expect(buckets.every((b) => !b.key.includes("Secret#Pass99")), "no plaintext in key");
  const again = await loginFailureBuckets("sch1", "1.1.1.1", "Secret#Pass99", SECRET);
  expect(buckets[0].key === again[0].key, "school id is case-insensitive");
});

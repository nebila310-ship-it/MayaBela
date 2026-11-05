/**
 * Failure-only lockouts that are checked before a credential is tested.
 *
 * `auth_rate_limit_hit` counts every call, so using it after a failed check
 * lets an attacker keep guessing while the bucket is full (the correct guess
 * still succeeds). These helpers peek at the bucket first and refuse while it
 * is full, and only count failed attempts.
 */
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export type LimitBucket = {
  key: string;
  limit: number;
  windowMs: number;
};

export type LimitRow = { count: number; windowStart: number };

export interface LimitStore {
  read(key: string): Promise<LimitRow | null>;
  hit(bucket: LimitBucket): Promise<void>;
}

export function isBucketFull(
  row: LimitRow | null,
  bucket: LimitBucket,
  nowMs: number,
): boolean {
  if (!row) return false;
  if (nowMs - row.windowStart > bucket.windowMs) return false;
  return row.count >= bucket.limit;
}

/** Throws `rate_limited` when any bucket is full. Does not count the call. */
export async function assertNotLocked(
  store: LimitStore,
  buckets: LimitBucket[],
  nowMs: number = Date.now(),
): Promise<void> {
  for (const bucket of buckets) {
    const row = await store.read(bucket.key);
    if (isBucketFull(row, bucket, nowMs)) {
      throw new Error("rate_limited");
    }
  }
}

export async function recordFailure(
  store: LimitStore,
  buckets: LimitBucket[],
): Promise<void> {
  for (const bucket of buckets) {
    await store.hit(bucket);
  }
}

export function supabaseLimitStore(sb: SupabaseClient): LimitStore {
  return {
    async read(key) {
      const { data, error } = await sb
        .from("auth_rate_limits")
        .select("count, window_start")
        .eq("bucket_key", key)
        .maybeSingle();
      if (error) throw error;
      if (!data) return null;
      return {
        count: Number(data.count) || 0,
        windowStart: Number(data.window_start) || 0,
      };
    },
    async hit(bucket) {
      const { error } = await sb.rpc("auth_rate_limit_hit", {
        p_bucket_key: bucket.key,
        p_limit: bucket.limit,
        p_window_ms: bucket.windowMs,
      });
      if (error) throw error;
    },
  };
}

/** Keyed HMAC so bucket keys never contain a guessable password digest. */
export async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** In-memory store for unit tests. */
export function memoryLimitStore(clock: () => number = Date.now): LimitStore & {
  rows: Map<string, LimitRow>;
} {
  const rows = new Map<string, LimitRow>();
  return {
    rows,
    read(key) {
      return Promise.resolve(rows.get(key) ?? null);
    },
    hit(bucket) {
      const now = clock();
      const row = rows.get(bucket.key);
      if (!row || now - row.windowStart > bucket.windowMs) {
        rows.set(bucket.key, { count: 1, windowStart: now });
      } else {
        row.count += 1;
      }
      return Promise.resolve();
    },
  };
}

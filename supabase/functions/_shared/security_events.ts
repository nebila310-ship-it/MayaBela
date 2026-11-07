/**
 * Server-written security events (`security_events`, server-only collection).
 * Stored under the platform tenant so no school JWT can read them even before
 * the server-only migration is applied. Never include secrets or passwords.
 */
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export const SECURITY_EVENTS_COLLECTION = "security_events";
const PLATFORM_TENANT = "__PLATFORM__";

export type SecurityEvent = {
  type: string;
  outcome: "success" | "failure" | "blocked" | "info";
  schoolId?: string | null;
  actor?: string | null;
  ip?: string | null;
  detail?: Record<string, unknown>;
};

export function securityEventDoc(event: SecurityEvent, now: Date = new Date()) {
  const rand = crypto.getRandomValues(new Uint8Array(6));
  const suffix = [...rand].map((b) => b.toString(16).padStart(2, "0")).join("");
  const at = now.toISOString();
  return {
    collection: SECURITY_EVENTS_COLLECTION,
    school_id: PLATFORM_TENANT,
    doc_id: `${at}_${event.type}_${suffix}`,
    data: {
      type: event.type,
      outcome: event.outcome,
      schoolId: event.schoolId ?? null,
      actor: event.actor ?? null,
      ip: event.ip ?? null,
      detail: event.detail ?? {},
      at,
    },
    updated_at: at,
  };
}

/** Best effort: a logging failure must never break the request. */
export async function logSecurityEvent(
  sb: SupabaseClient,
  event: SecurityEvent,
): Promise<void> {
  try {
    const { error } = await sb.from("app_documents").insert(securityEventDoc(event));
    if (error) console.error("security_event_write_failed", error.code);
  } catch (e) {
    console.error("security_event_write_failed", String((e as Error)?.message || e));
  }
}

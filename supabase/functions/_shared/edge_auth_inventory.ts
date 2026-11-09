// Line-audit catalogue of Edge Functions. Service-role is used by several
// of these; each row states the gate that stands in for RLS. Keep in sync
// with supabase/functions/*/index.ts — the test fails if a folder is missing.

export type EdgeAuthMode =
  | "user-jwt"
  | "password-login"
  | "platform-owner-pin"
  | "public-rate-limited"
  | "push-secret"
  | "user-jwt-or-service";

export type EdgeAuthEntry = {
  name: string;
  mode: EdgeAuthMode;
  notes: string;
};

export const EDGE_AUTH_INVENTORY: EdgeAuthEntry[] = [
  {
    name: "school-login",
    mode: "password-login",
    notes: "Rate-limited; schoolId required; JWT minted after verifySecret.",
  },
  {
    name: "school-refresh-claims",
    mode: "user-jwt",
    notes: "Caller JWT; may refresh own claims only.",
  },
  {
    name: "school-change-password",
    mode: "user-jwt",
    notes: "Self or desk; secret stored hashed.",
  },
  {
    name: "school-upsert-account",
    mode: "user-jwt",
    notes: "JWT then service-role write; desk permissions checked first.",
  },
  {
    name: "school-upsert-registry",
    mode: "user-jwt",
    notes: "JWT then guardRegistryRecord then service-role upsert.",
  },
  {
    name: "school-delete-account",
    mode: "user-jwt",
    notes: "JWT; cannot delete another school's account.",
  },
  {
    name: "school-request-password-reset",
    mode: "public-rate-limited",
    notes: "No JWT; rate-limited; does not reveal whether the user exists.",
  },
  {
    name: "school-confirm-password-reset",
    mode: "public-rate-limited",
    notes: "Code + rate-limit; hashed secret replace.",
  },
  {
    name: "school-request-student-password-reset",
    mode: "public-rate-limited",
    notes: "Queues a desk row; no JWT.",
  },
  {
    name: "school-verify-student",
    mode: "user-jwt",
    notes: "Desk JWT to confirm a student portal identity.",
  },
  {
    name: "school-register-parent",
    mode: "public-rate-limited",
    notes: "Invite/DOB gated; new parent account in one school.",
  },
  {
    name: "school-invite-parent",
    mode: "public-rate-limited",
    notes: "Sends mail; rate-limited per school+email; no student dump in response.",
  },
  {
    name: "school-submit-application",
    mode: "public-rate-limited",
    notes: "Public admissions intake; rate-limited; writes admission_applications.",
  },
  {
    name: "school-public-brand",
    mode: "public-rate-limited",
    notes: "Login chrome only (name/logo). No emails or passwords.",
  },
  {
    name: "maya-assistant-chat",
    mode: "user-jwt",
    notes: "JWT; counts-only context; refuses health/safeguarding/passwords.",
  },
  {
    name: "platform-owner-pin",
    mode: "platform-owner-pin",
    notes: "PIN verify; rate-limited; PBKDF2.",
  },
  {
    name: "platform-list-schools",
    mode: "platform-owner-pin",
    notes: "PIN; strips adminInitialPassword from payload.",
  },
  {
    name: "platform-create-school",
    mode: "platform-owner-pin",
    notes: "PIN; service-role create.",
  },
  {
    name: "platform-update-school",
    mode: "platform-owner-pin",
    notes: "PIN; no password fields.",
  },
  {
    name: "platform-delete-school",
    mode: "platform-owner-pin",
    notes: "PIN; dedicated owner action.",
  },
  {
    name: "platform-upload-logo",
    mode: "platform-owner-pin",
    notes: "PIN; branding bucket only.",
  },
  {
    name: "platform-upload-mark",
    mode: "platform-owner-pin",
    notes: "PIN; branding bucket only.",
  },
  {
    name: "platform-mail-config",
    mode: "platform-owner-pin",
    notes: "PIN; mail secrets stay server-side.",
  },
  {
    name: "client-crash-report",
    mode: "public-rate-limited",
    notes: "Clipped stack; no student rows; rate-limited by IP.",
  },
  {
    name: "send-push",
    mode: "push-secret",
    notes: "x-push-secret; re-reads the notification row (cannot forge content).",
  },
];

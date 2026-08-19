/**
 * Staging load test for MayaBela / MaJo Bridge (k6).
 *
 * NEVER point this at production.
 * Required env:
 *   STAGING_SUPABASE_URL
 *   STAGING_ANON_KEY
 * Optional:
 *   LOAD_SCHOOL_ID   (default LOAD-001)
 *   LOAD_PASSWORD    (shared staging password, min 10 chars)
 *   LOAD_PROFILE     session (login once then read)
 *                    full (login every iteration)
 *                    smoke (~100 VUs, 1 minute)
 *                    rung (login-once at LOAD_VUS, mix scaled from 500)
 *   LOAD_VUS         peak VUs for rung (50 / 250 / 750 / 1000)
 *
 * Mix (500 VUs): 250 parent / 100 teacher / 100 student / 30 admin / 20 finance
 *
 *   k6 run load/k6/school_erp.js
 */
import http from "k6/http";
import { check, sleep, fail } from "k6";

const PROD_REF = "hwkiihonthueadbhcvfi";
const base = (__ENV.STAGING_SUPABASE_URL || "").replace(/\/$/, "");
const anon = __ENV.STAGING_ANON_KEY || "";
const schoolId = (__ENV.LOAD_SCHOOL_ID || "LOAD-001").toUpperCase();
const password = __ENV.LOAD_PASSWORD || "LoadTest12!";
const profile = String(__ENV.LOAD_PROFILE || "full").toLowerCase();
const isSmoke = profile === "smoke";
const isRung = profile === "rung";
const isSession = profile === "session" || isRung;
const rungVus = Math.max(1, parseInt(__ENV.LOAD_VUS || "50", 10) || 50);
let cachedJwt = "";

if (!base || !anon) {
  fail("Set STAGING_SUPABASE_URL and STAGING_ANON_KEY. Refusing to guess.");
}
if (base.includes(PROD_REF)) {
  fail("Refusing to load-test production (hwkiihonthueadbhcvfi). Use staging.");
}

function stages(full) {
  if (isRung) {
    return [
      { duration: "20s", target: Math.max(1, Math.round(full * 0.5)) },
      { duration: "70s", target: full },
    ];
  }
  if (isSmoke) {
    return [
      { duration: "20s", target: Math.max(1, Math.round(full * 0.1)) },
      { duration: "40s", target: Math.max(2, Math.round(full * 0.2)) },
    ];
  }
  if (full >= 100) {
    return [
      { duration: "1m", target: Math.round(full * 0.1) },
      { duration: "1m", target: Math.round(full * 0.25) },
      { duration: "2m", target: Math.round(full * 0.5) },
      { duration: "2m", target: full },
    ];
  }
  if (full >= 30) {
    return [
      { duration: "1m", target: 5 },
      { duration: "2m", target: 15 },
      { duration: "3m", target: full },
    ];
  }
  return [
    { duration: "1m", target: 5 },
    { duration: "4m", target: full },
  ];
}

function mix(partOf500) {
  if (!isRung) return partOf500;
  return Math.max(partOf500 === 0 ? 0 : 1, Math.round((partOf500 / 500) * rungVus));
}

export const options = {
  summaryTrendStats: ["avg", "min", "med", "max", "p(90)", "p(95)", "p(99)"],
  scenarios: {
    parents: {
      executor: "ramping-vus",
      exec: "parentFlow",
      startVUs: 0,
      stages: stages(mix(250)),
    },
    teachers: {
      executor: "ramping-vus",
      exec: "teacherFlow",
      startVUs: 0,
      stages: stages(mix(100)),
    },
    students: {
      executor: "ramping-vus",
      exec: "studentFlow",
      startVUs: 0,
      stages: stages(mix(100)),
    },
    admins: {
      executor: "ramping-vus",
      exec: "adminFlow",
      startVUs: 0,
      stages: stages(mix(30)),
    },
    finance: {
      executor: "ramping-vus",
      exec: "financeFlow",
      startVUs: 0,
      stages: stages(mix(20)),
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<2500"],
  },
};

function loginOnce(roleKey, username) {
  if (isSession && cachedJwt) return cachedJwt;
  const jwt = login(roleKey, username);
  if (isSession && jwt) cachedJwt = jwt;
  return jwt;
}

function login(roleKey, username) {
  const res = http.post(
    `${base}/functions/v1/school-login`,
    JSON.stringify({
      schoolId,
      roleKey,
      username,
      password,
    }),
    {
      headers: {
        "Content-Type": "application/json",
        apikey: anon,
        Authorization: `Bearer ${anon}`,
      },
      tags: { name: "school-login", role: roleKey },
    },
  );
  check(res, { "login status 200/401/403": (r) => r.status < 500 });
  let jwt = "";
  try {
    const body = res.json();
    jwt = body?.access_token || body?.session?.access_token || "";
  } catch (_) {}
  return jwt;
}

function readCollection(jwt, collection) {
  if (!jwt) {
    sleep(1);
    return;
  }
  const res = http.get(
    `${base}/rest/v1/app_documents?collection=eq.${collection}&select=doc_id,updated_at&limit=50`,
    {
      headers: {
        apikey: anon,
        Authorization: `Bearer ${jwt}`,
      },
      tags: { name: "delta-get", collection },
    },
  );
  check(res, { "GET not 5xx": (r) => r.status < 500 });
}

export function parentFlow() {
  const jwt = loginOnce("parent", `load-parent-${__VU}`);
  readCollection(jwt, "app_announcements");
  readCollection(jwt, "grade_reports");
  readCollection(jwt, "attendance_sessions");
  sleep(2 + Math.random() * 2);
}

export function teacherFlow() {
  const jwt = loginOnce("teacher", `load-teacher-${__VU}`);
  readCollection(jwt, "student_registry");
  readCollection(jwt, "attendance_sessions");
  readCollection(jwt, "grade_reports");
  sleep(2 + Math.random() * 2);
}

export function studentFlow() {
  const jwt = loginOnce("student", `load-student-${__VU}`);
  readCollection(jwt, "grade_reports");
  readCollection(jwt, "homework");
  sleep(2 + Math.random() * 2);
}

export function adminFlow() {
  const jwt = loginOnce("admin", `load-admin-${__VU}`);
  readCollection(jwt, "student_registry");
  readCollection(jwt, "app_auth_accounts");
  sleep(3);
}

export function financeFlow() {
  const jwt = loginOnce("teacher", `load-finance-${__VU}`);
  readCollection(jwt, "fees");
  readCollection(jwt, "inventory_items");
  sleep(3);
}

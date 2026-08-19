/**
 * Live PostgREST RLS isolation (negative cases must FAIL).
 *
 * Staging only. Refuses production project ref hwkiihonthueadbhcvfi.
 *
 *   node tools/test_rls_isolation.mjs
 *
 * Env (or .env.staging):
 *   STAGING_SUPABASE_URL
 *   STAGING_ANON_KEY
 *   STAGING_SERVICE_ROLE_KEY
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const PROD_REF = "hwkiihonthueadbhcvfi";
const PASS = "IsoRls12!!";
const SCHOOL_A = "ISOA";
const SCHOOL_B = "ISOB";
const STU_A_OWN = "ISOA-OWN";
const STU_A_OTHER = "ISOA-OTH";
const STU_B_OWN = "ISOB-OWN";
const PARENT_A = "iso-pa";
const PARENT_B = "iso-pb";
const TEACHER_A = "iso-ta";
const TEACHER_B = "iso-tb";

function loadEnvFile(filePath) {
  if (!existsSync(filePath)) return;
  for (const line of readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const i = trimmed.indexOf("=");
    if (i < 0) continue;
    const k = trimmed.slice(0, i).trim();
    const v = trimmed.slice(i + 1).trim();
    if (!process.env[k]) process.env[k] = v;
  }
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
loadEnvFile(resolve(root, ".env.staging"));

const URL_BASE = (process.env.STAGING_SUPABASE_URL || "").replace(/\/$/, "");
const ANON = process.env.STAGING_ANON_KEY || "";
const SERVICE = process.env.STAGING_SERVICE_ROLE_KEY || "";

if (!URL_BASE || !ANON || !SERVICE) {
  console.error(
    "Set STAGING_SUPABASE_URL, STAGING_ANON_KEY, STAGING_SERVICE_ROLE_KEY",
  );
  process.exit(2);
}
if (URL_BASE.includes(PROD_REF)) {
  console.error("Refusing to run isolation tests against production.");
  process.exit(2);
}

function accountDocId(schoolId, username) {
  return `${schoolId}__${username}`;
}

function doc(collection, docId, schoolId, data) {
  return {
    collection,
    doc_id: docId,
    school_id: schoolId,
    data: { schoolId, ...data },
    updated_at: new Date().toISOString(),
  };
}

async function rest(path, opts = {}, token = SERVICE) {
  const res = await fetch(`${URL_BASE}${path}`, {
    ...opts,
    headers: {
      apikey: token === SERVICE ? SERVICE : ANON,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Prefer: opts.prefer || "return=representation",
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: res.status, body };
}

function ids(body) {
  return (Array.isArray(body) ? body : []).map((r) => r.doc_id);
}

let failures = 0;
function check(name, ok, detail = "") {
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? ` — ${detail}` : ""}`);
  if (!ok) failures += 1;
}

async function login(username, roleKey, schoolId) {
  const res = await fetch(`${URL_BASE}/functions/v1/school-login`, {
    method: "POST",
    headers: {
      apikey: ANON,
      Authorization: `Bearer ${ANON}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      username,
      password: PASS,
      roleKey,
      schoolId,
    }),
  });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, token: body.access_token || "", body };
}

async function cleanup() {
  for (const school of [SCHOOL_A, SCHOOL_B]) {
    await rest(`/rest/v1/app_documents?school_id=eq.${school}`, {
      method: "DELETE",
      prefer: "return=minimal",
    });
  }
  const rateKeys = [
    `login_${PARENT_A}_parent_${SCHOOL_A}`,
    `login_${PARENT_B}_parent_${SCHOOL_B}`,
    `login_${TEACHER_A}_teacher_${SCHOOL_A}`,
    `login_${TEACHER_B}_teacher_${SCHOOL_B}`,
  ];
  for (const key of rateKeys) {
    await rest(`/rest/v1/auth_rate_limits?bucket_key=eq.${key}`, {
      method: "DELETE",
      prefer: "return=minimal",
    });
  }
  const emails = [
    `${PARENT_A}@isoa.mayabela.local`,
    `${TEACHER_A}@isoa.mayabela.local`,
    `${PARENT_B}@isob.mayabela.local`,
    `${TEACHER_B}@isob.mayabela.local`,
  ];
  for (const email of emails) {
    const listed = await rest(
      `/auth/v1/admin/users?email=${encodeURIComponent(email)}&page=1&per_page=10`,
    );
    const users = Array.isArray(listed.body?.users)
      ? listed.body.users
      : Array.isArray(listed.body)
        ? listed.body
        : [];
    for (const u of users) {
      if (String(u.email || "").toLowerCase() !== email) continue;
      await rest(`/auth/v1/admin/users/${u.id}`, {
        method: "DELETE",
        prefer: "return=minimal",
      });
    }
  }
}

async function seed() {
  const rows = [
    doc("school_registry", SCHOOL_A, SCHOOL_A, {
      id: SCHOOL_A,
      name: "Isolation School A",
      status: "active",
    }),
    doc("school_registry", SCHOOL_B, SCHOOL_B, {
      id: SCHOOL_B,
      name: "Isolation School B",
      status: "active",
    }),
    doc("app_auth_accounts", accountDocId(SCHOOL_A, PARENT_A), SCHOOL_A, {
      username: PARENT_A,
      roleKey: "parent",
      fullName: "Iso Parent A",
      password: PASS,
      linkedStudentIds: [STU_A_OWN],
      linkedClassNames: ["Iso 1A"],
    }),
    doc("app_auth_accounts", accountDocId(SCHOOL_B, PARENT_B), SCHOOL_B, {
      username: PARENT_B,
      roleKey: "parent",
      fullName: "Iso Parent B",
      password: PASS,
      linkedStudentIds: [STU_B_OWN],
    }),
    doc("app_auth_accounts", accountDocId(SCHOOL_A, TEACHER_A), SCHOOL_A, {
      username: TEACHER_A,
      roleKey: "teacher",
      fullName: "Iso Teacher A",
      password: PASS,
      staffRoles: [],
    }),
    doc("app_auth_accounts", accountDocId(SCHOOL_B, TEACHER_B), SCHOOL_B, {
      username: TEACHER_B,
      roleKey: "teacher",
      fullName: "Iso Teacher B",
      password: PASS,
      staffRoles: [],
    }),
    doc("student_registry", STU_A_OWN, SCHOOL_A, {
      studentId: STU_A_OWN,
      fullName: "Own Child A",
      className: "Iso 1A",
    }),
    doc("student_registry", STU_A_OTHER, SCHOOL_A, {
      studentId: STU_A_OTHER,
      fullName: "Other Child A",
      className: "Iso 1B",
    }),
    doc("student_registry", STU_B_OWN, SCHOOL_B, {
      studentId: STU_B_OWN,
      fullName: "Own Child B",
      className: "Iso 2A",
    }),
    doc("grade_reports", "iso-grade-a-own", SCHOOL_A, {
      studentId: STU_A_OWN,
      subject: "Math",
      score: 91,
    }),
    doc("grade_reports", "iso-grade-a-other", SCHOOL_A, {
      studentId: STU_A_OTHER,
      subject: "Math",
      score: 44,
    }),
    doc("grade_reports", "iso-grade-b-own", SCHOOL_B, {
      studentId: STU_B_OWN,
      subject: "Math",
      score: 77,
    }),
    doc("fees", "iso-fee-a-other", SCHOOL_A, {
      studentId: STU_A_OTHER,
      amount: 250,
      status: "unpaid",
    }),
    doc("student_medical", "iso-med-a-other", SCHOOL_A, {
      studentId: STU_A_OTHER,
      note: "secret-allergy",
    }),
    doc("app_announcements", "iso-ann-a", SCHOOL_A, {
      title: "School A notice",
      body: "ok-for-parents",
    }),
  ];
  const { status, body } = await rest(`/rest/v1/app_documents`, {
    method: "POST",
    prefer: "resolution=merge-duplicates,return=minimal",
    body: JSON.stringify(rows),
  });
  if (status >= 300) {
    throw new Error(`seed failed ${status}: ${JSON.stringify(body)}`);
  }
}

async function main() {
  console.log("RLS isolation against", URL_BASE);
  await cleanup();
  await seed();

  const parentA = await login(PARENT_A, "parent", SCHOOL_A);
  check("parent A login", parentA.status === 200 && !!parentA.token, `status=${parentA.status}`);
  const teacherB = await login(TEACHER_B, "teacher", SCHOOL_B);
  check("teacher B login", teacherB.status === 200 && !!teacherB.token, `status=${teacherB.status}`);
  const parentB = await login(PARENT_B, "parent", SCHOOL_B);
  check("parent B login", parentB.status === 200 && !!parentB.token, `status=${parentB.status}`);
  const teacherA = await login(TEACHER_A, "teacher", SCHOOL_A);
  check("teacher A login", teacherA.status === 200 && !!teacherA.token, `status=${teacherA.status}`);

  if (!parentA.token || !teacherB.token || !parentB.token || !teacherA.token) {
    await cleanup();
    process.exit(1);
  }

  const paGrades = await rest(
    `/rest/v1/app_documents?collection=eq.grade_reports&select=doc_id,school_id,data`,
    {},
    parentA.token,
  );
  const paGradeIds = ids(paGrades.body);
  check("parent A can read own child's grade", paGradeIds.includes("iso-grade-a-own"), paGradeIds.join(","));
  check(
    "parent A cannot read other child's grade",
    !paGradeIds.includes("iso-grade-a-other"),
    paGradeIds.join(","),
  );
  check(
    "parent A cannot read other school's grade",
    !paGradeIds.includes("iso-grade-b-own"),
    paGradeIds.join(","),
  );

  const paFees = await rest(
    `/rest/v1/app_documents?collection=eq.fees&select=doc_id,data`,
    {},
    parentA.token,
  );
  check(
    "parent A cannot read other child's fee",
    !ids(paFees.body).includes("iso-fee-a-other"),
    ids(paFees.body).join(","),
  );

  const paMed = await rest(
    `/rest/v1/app_documents?collection=eq.student_medical&select=doc_id,data`,
    {},
    parentA.token,
  );
  check(
    "parent A cannot read other child's medical",
    !ids(paMed.body).includes("iso-med-a-other"),
    ids(paMed.body).join(","),
  );

  const paStudents = await rest(
    `/rest/v1/app_documents?collection=eq.student_registry&select=doc_id`,
    {},
    parentA.token,
  );
  const paStu = ids(paStudents.body);
  check("parent A can read own student registry row", paStu.includes(STU_A_OWN), paStu.join(","));
  check("parent A cannot read other student registry row", !paStu.includes(STU_A_OTHER), paStu.join(","));
  check("parent A cannot read other school's student", !paStu.includes(STU_B_OWN), paStu.join(","));

  const paAnn = await rest(
    `/rest/v1/app_documents?collection=eq.app_announcements&select=doc_id`,
    {},
    parentA.token,
  );
  check(
    "parent A can read own-school announcement",
    ids(paAnn.body).includes("iso-ann-a"),
    ids(paAnn.body).join(","),
  );

  const feeHack = await rest(
    `/rest/v1/app_documents`,
    {
      method: "POST",
      prefer: "resolution=merge-duplicates,return=minimal",
      body: JSON.stringify(
        doc("fees", "iso-fee-hack", SCHOOL_A, {
          studentId: STU_A_OWN,
          amount: 1,
          status: "paid",
        }),
      ),
    },
    parentA.token,
  );
  const feeAfter = await rest(
    `/rest/v1/app_documents?collection=eq.fees&doc_id=eq.iso-fee-hack&school_id=eq.${SCHOOL_A}&select=doc_id`,
  );
  check(
    "parent A cannot persist a fee write",
    (feeAfter.body?.length ?? 0) === 0,
    `write=${feeHack.status} rows=${feeAfter.body?.length}`,
  );

  const tbGrades = await rest(
    `/rest/v1/app_documents?collection=eq.grade_reports&select=doc_id,school_id`,
    {},
    teacherB.token,
  );
  const tbIds = ids(tbGrades.body);
  check("teacher B can read own-school grade", tbIds.includes("iso-grade-b-own"), tbIds.join(","));
  check(
    "teacher B cannot read school A grades",
    !tbIds.includes("iso-grade-a-own") && !tbIds.includes("iso-grade-a-other"),
    tbIds.join(","),
  );

  const pbGrades = await rest(
    `/rest/v1/app_documents?collection=eq.grade_reports&select=doc_id`,
    {},
    parentB.token,
  );
  const pbIds = ids(pbGrades.body);
  check("parent B cannot read school A child grade", !pbIds.includes("iso-grade-a-own"), pbIds.join(","));

  const taOtherSchool = await rest(
    `/rest/v1/app_documents?collection=eq.student_registry&school_id=eq.${SCHOOL_B}&select=doc_id`,
    {},
    teacherA.token,
  );
  check(
    "teacher A query for school B student_registry is empty",
    (taOtherSchool.body?.length ?? 0) === 0,
    ids(taOtherSchool.body).join(","),
  );

  await cleanup();
  console.log(failures === 0 ? "\nRESULT: ALL PASS" : `\nRESULT: ${failures} FAILURE(S)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch(async (e) => {
  console.error(e);
  try {
    await cleanup();
  } catch (_) {}
  process.exit(1);
});

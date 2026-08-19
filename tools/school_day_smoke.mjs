/**
 * School-day smoke against ephemeral school SMOKE30.
 * Verifies login, JWT RBAC claims, RLS reads, and role writes.
 * Usage: node tools/school_day_smoke.mjs [--keep]
 */
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const KEEP = process.argv.includes("--keep");
const env = {};
for (const line of readFileSync(resolve(process.cwd(), ".env.local"), "utf8").split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, "").trim();
}

const URL = env.SUPABASE_URL;
const ANON = env.SUPABASE_ANON_KEY;
const SERVICE = env.SUPABASE_SERVICE_ROLE_KEY;
const SCHOOL = "SMOKE30";
const PASS = "SmokeDay30!";
const stamp = new Date().toISOString();

const users = {
  owner: {
    username: "smoke_owner",
    roleKey: "admin",
    fullName: "Smoke Owner",
    staffRoles: ["full_access"],
  },
  hr: {
    username: "smoke_hr",
    roleKey: "teacher",
    fullName: "Smoke HR",
    staffRoles: ["human_resource"],
  },
  sd: {
    username: "smoke_sd",
    roleKey: "teacher",
    fullName: "Smoke Section Director",
    staffRoles: ["section_director"],
  },
  sa: {
    username: "smoke_sa",
    roleKey: "teacher",
    fullName: "Smoke Student Affairs",
    staffRoles: ["student_affairs"],
  },
  teacher: {
    username: "smoke_teacher",
    roleKey: "teacher",
    fullName: "Smoke Teacher",
    staffRoles: [],
  },
  parent: {
    username: "smoke_parent",
    roleKey: "parent",
    fullName: "Smoke Parent",
    staffRoles: [],
  },
};

const results = [];
function check(id, ok, detail = "") {
  results.push({ id, ok: !!ok, detail });
  console.log(`${ok ? "PASS" : "FAIL"}  ${id}${detail ? " — " + detail : ""}`);
}

async function rest(path, opts = {}, token = SERVICE) {
  const isUser = token !== SERVICE;
  const res = await fetch(`${URL}${path}`, {
    ...opts,
    headers: {
      apikey: isUser ? ANON : SERVICE,
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

async function upsertDoc(collection, docId, schoolId, data) {
  return rest(`/rest/v1/app_documents`, {
    method: "POST",
    prefer: "resolution=merge-duplicates,return=minimal",
    body: JSON.stringify({
      collection,
      doc_id: docId,
      school_id: schoolId,
      data,
      updated_at: stamp,
    }),
  });
}

async function deleteDocs(collection, schoolId) {
  return rest(
    `/rest/v1/app_documents?collection=eq.${collection}&school_id=eq.${schoolId}`,
    { method: "DELETE", prefer: "return=minimal" },
  );
}

async function login(username, roleKey) {
  const res = await fetch(`${URL}/functions/v1/school-login`, {
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
      schoolId: SCHOOL,
    }),
  });
  const body = await res.json();
  return { status: res.status, body };
}

async function claims(accessToken) {
  const r = await rest(`/auth/v1/user`, {}, accessToken);
  return r.body?.app_metadata || {};
}

async function cleanup() {
  console.log("\nCleaning smoke school…");
  const collections = [
    "app_auth_accounts",
    "auth_secrets",
    "school_registry",
    "teachers",
    "employee_registry",
    "students",
    "parent_student_links",
    "announcements",
    "grades",
    "grade_approvals",
    "calendar_events",
    "school_role_catalogs",
  ];
  for (const c of collections) await deleteDocs(c, SCHOOL);
  for (const u of Object.values(users)) {
    await rest(
      `/rest/v1/app_documents?collection=eq.app_auth_accounts&doc_id=eq.${u.username}`,
      { method: "DELETE", prefer: "return=minimal" },
    );
    await rest(
      `/rest/v1/app_documents?collection=eq.auth_secrets&doc_id=eq.${u.username}`,
      { method: "DELETE", prefer: "return=minimal" },
    );
  }
  const listed = await rest(`/auth/v1/admin/users?page=1&per_page=1000`);
  for (const u of listed.body?.users || []) {
    const email = String(u.email || "");
    if (email.includes("smoke_") && email.toLowerCase().includes("smoke30")) {
      await rest(`/auth/v1/admin/users/${u.id}`, {
        method: "DELETE",
        prefer: "return=minimal",
      });
    }
  }
}

async function seed() {
  console.log("Seeding smoke school", SCHOOL);
  await cleanup();

  check(
    "seed.school_registry",
    (
      await upsertDoc("school_registry", SCHOOL, SCHOOL, {
        id: SCHOOL,
        schoolId: SCHOOL,
        name: "Smoke Day School",
        status: "active",
        adminFullName: "Smoke Owner",
        adminContactPhone: "0999000030",
        adminInitialPassword: PASS,
        registeredAt: stamp,
        updatedAt: stamp,
      })
    ).status < 300,
  );

  for (const u of Object.values(users)) {
    const r = await upsertDoc("app_auth_accounts", u.username, SCHOOL, {
      username: u.username,
      roleKey: u.roleKey,
      schoolId: SCHOOL,
      fullName: u.fullName,
      password: PASS,
      staffRoles: u.staffRoles,
    });
    check(`seed.account.${u.username}`, r.status < 300, `status=${r.status}`);
  }

  await upsertDoc("teachers", "smoke_t1", SCHOOL, {
    teacherId: "smoke_t1",
    schoolId: SCHOOL,
    fullName: "Smoke Hire Candidate",
    phone: "0999000031",
    subject: "Math",
    assignedClass: "",
    staffRoles: [],
    isActive: true,
  });
  await upsertDoc("students", "smoke_s1", SCHOOL, {
    studentId: "smoke_s1",
    schoolId: SCHOOL,
    fullName: "Smoke Student One",
    grade: "Grade 2",
    section: "C",
    isActive: true,
  });
  await upsertDoc("parent_student_links", "smoke_link1", SCHOOL, {
    id: "smoke_link1",
    schoolId: SCHOOL,
    parentUsername: "smoke_parent",
    studentId: "smoke_s1",
    status: "pending",
    requestedAt: stamp,
  });
  await upsertDoc("announcements", "smoke_a_old", SCHOOL, {
    id: "smoke_a_old",
    schoolId: SCHOOL,
    title: "Older announcement",
    body: "old",
    createdAt: "2026-07-01T10:00:00.000Z",
    date: "2026-07-01T10:00:00.000Z",
  });
  await upsertDoc("announcements", "smoke_a_new", SCHOOL, {
    id: "smoke_a_new",
    schoolId: SCHOOL,
    title: "Newest announcement",
    body: "new",
    createdAt: "2026-07-30T10:00:00.000Z",
    date: "2026-07-30T10:00:00.000Z",
  });
  await upsertDoc("calendar_events", "smoke_cal1", SCHOOL, {
    id: "smoke_cal1",
    schoolId: SCHOOL,
    title: "Smoke assembly",
    date: "2026-07-30",
    startDate: "2026-07-30",
  });
  await upsertDoc("grades", "smoke_g1", SCHOOL, {
    id: "smoke_g1",
    schoolId: SCHOOL,
    studentId: "smoke_s1",
    teacherId: "smoke_teacher",
    subject: "Math",
    score: 88,
    status: "pending_approval",
    term: "Term 1",
    createdAt: stamp,
  });
}

async function smokeLogins() {
  console.log("\n--- Login + JWT RBAC claims ---");
  const out = {};

  for (const [key, u] of Object.entries(users)) {
    const res = await login(u.username, u.roleKey);
    check(`login.${key}`, res.status === 200 && !!res.body?.access_token, `status=${res.status}`);
    if (res.body?.access_token) {
      const meta = await claims(res.body.access_token);
      out[key] = { ...res, meta };
      console.log(
        `   ${key} claims: role=${meta.role} school=${meta.school_id || meta.schoolId} roles=${JSON.stringify(meta.staffRoles)} perms=${(meta.permissions || []).length}`,
      );
    }
  }

  const hrPerms = new Set(out.hr?.meta?.permissions || []);
  const sdPerms = new Set(out.sd?.meta?.permissions || []);
  const saPerms = new Set(out.sa?.meta?.permissions || []);

  check("rbac.hr.manage_staff_accounts", hrPerms.has("manage_staff_accounts"));
  check("rbac.hr.manage_buses_or_drivers", hrPerms.has("manage_buses") || hrPerms.has("manage_drivers"));
  check("rbac.hr.blocks_approve_grades", !hrPerms.has("approve_grades"));

  check("rbac.sd.approve_grades", sdPerms.has("approve_grades"));
  check("rbac.sd.assign_teachers", sdPerms.has("assign_teachers"));
  check("rbac.sd.manage_parent_links", sdPerms.has("manage_parent_links"));
  check("rbac.sd.blocks_manage_staff_accounts", !sdPerms.has("manage_staff_accounts"));

  check("rbac.sa.manage_parent_links", saPerms.has("manage_parent_links"));
  check("rbac.sa.manage_students", saPerms.has("manage_students"));

  return out;
}

async function smokeData(tokens) {
  console.log("\n--- Role-scoped reads/writes ---");
  const sdToken = tokens.sd?.body?.access_token;
  const hrToken = tokens.hr?.body?.access_token;
  if (!sdToken) {
    check("data.skipped", false, "no SD token");
    return;
  }

  // Service-role confirms seed exists
  const seeded = await rest(
    `/rest/v1/app_documents?collection=eq.announcements&school_id=eq.${SCHOOL}&select=doc_id`,
  );
  check(
    "seed.announcements_exist",
    Array.isArray(seeded.body) && seeded.body.length >= 2,
    `count=${Array.isArray(seeded.body) ? seeded.body.length : 0}`,
  );

  const anns = await rest(
    `/rest/v1/app_documents?collection=eq.announcements&school_id=eq.${SCHOOL}&select=doc_id,data`,
    {},
    sdToken,
  );
  const annList = Array.isArray(anns.body) ? anns.body : [];
  check(
    "read.sd.announcements",
    anns.status === 200 && annList.length >= 2,
    `status=${anns.status} count=${annList.length}`,
  );
  const sorted = [...annList].sort((a, b) => {
    const da = Date.parse(a.data?.date || a.data?.createdAt || 0);
    const db = Date.parse(b.data?.date || b.data?.createdAt || 0);
    return db - da;
  });
  check(
    "order.announcements_newest_first",
    sorted[0]?.doc_id === "smoke_a_new",
    `top=${sorted[0]?.doc_id}`,
  );

  const links = await rest(
    `/rest/v1/app_documents?collection=eq.parent_student_links&school_id=eq.${SCHOOL}&select=doc_id,data`,
    {},
    sdToken,
  );
  const linkList = Array.isArray(links.body) ? links.body : [];
  check(
    "read.sd.parent_links",
    linkList.some((l) => l.data?.status === "pending"),
    `count=${linkList.length}`,
  );

  const grades = await rest(
    `/rest/v1/app_documents?collection=eq.grades&school_id=eq.${SCHOOL}&select=doc_id,data`,
    {},
    sdToken,
  );
  const gList = Array.isArray(grades.body) ? grades.body : [];
  check(
    "read.sd.grades_pending",
    gList.some((x) => x.data?.status === "pending_approval"),
    `count=${gList.length}`,
  );

  const cal = await rest(
    `/rest/v1/app_documents?collection=eq.calendar_events&school_id=eq.${SCHOOL}&select=doc_id,data`,
    {},
    sdToken,
  );
  check(
    "read.sd.calendar",
    Array.isArray(cal.body) && cal.body.length >= 1,
    `count=${Array.isArray(cal.body) ? cal.body.length : 0}`,
  );

  if (hrToken) {
    const emp = await rest(
      `/rest/v1/app_documents`,
      {
        method: "POST",
        prefer: "resolution=merge-duplicates,return=minimal",
        body: JSON.stringify({
          collection: "employee_registry",
          doc_id: "smoke_emp1",
          school_id: SCHOOL,
          data: {
            employeeId: "smoke_emp1",
            schoolId: SCHOOL,
            fullName: "Smoke Guard",
            jobTitle: "Security",
            isActive: true,
          },
          updated_at: stamp,
        }),
      },
      hrToken,
    );
    check(
      "write.hr.employee_registry",
      emp.status < 300,
      `status=${emp.status} ${typeof emp.body === "object" ? JSON.stringify(emp.body).slice(0, 160) : emp.body}`,
    );
  }

  const approve = await rest(
    `/rest/v1/app_documents?collection=eq.grades&doc_id=eq.smoke_g1`,
    {
      method: "PATCH",
      prefer: "return=minimal",
      body: JSON.stringify({
        data: {
          id: "smoke_g1",
          schoolId: SCHOOL,
          studentId: "smoke_s1",
          teacherId: "smoke_teacher",
          subject: "Math",
          score: 88,
          status: "approved",
          term: "Term 1",
          approvedAt: stamp,
          approvedBy: "smoke_sd",
        },
        updated_at: stamp,
      }),
    },
    sdToken,
  );
  check(
    "write.sd.approve_grade",
    approve.status < 300,
    `status=${approve.status} ${typeof approve.body === "object" ? JSON.stringify(approve.body).slice(0, 160) : approve.body}`,
  );

  const linkOk = await rest(
    `/rest/v1/app_documents?collection=eq.parent_student_links&doc_id=eq.smoke_link1`,
    {
      method: "PATCH",
      prefer: "return=minimal",
      body: JSON.stringify({
        data: {
          id: "smoke_link1",
          schoolId: SCHOOL,
          parentUsername: "smoke_parent",
          studentId: "smoke_s1",
          status: "approved",
          approvedAt: stamp,
          approvedBy: "smoke_sd",
        },
        updated_at: stamp,
      }),
    },
    sdToken,
  );
  check(
    "write.sd.approve_parent_link",
    linkOk.status < 300,
    `status=${linkOk.status}`,
  );

  const assign = await rest(
    `/rest/v1/app_documents?collection=eq.teachers&doc_id=eq.smoke_t1`,
    {
      method: "PATCH",
      prefer: "return=minimal",
      body: JSON.stringify({
        data: {
          teacherId: "smoke_t1",
          schoolId: SCHOOL,
          fullName: "Smoke Hire Candidate",
          phone: "0999000031",
          subject: "Math",
          assignedClass: "Grade 2C",
          classroomRole: "homeroom",
          isActive: true,
          staffRoles: [],
        },
        updated_at: stamp,
      }),
    },
    sdToken,
  );
  check("write.sd.assign_teacher_class", assign.status < 300, `status=${assign.status}`);
}

async function main() {
  await seed();
  const tokens = await smokeLogins();
  await smokeData(tokens);

  const pass = results.filter((r) => r.ok).length;
  const fail = results.filter((r) => !r.ok).length;
  writeFileSync(
    resolve(process.cwd(), "reports/school_day_smoke_results.json"),
    JSON.stringify(
      {
        school: SCHOOL,
        at: stamp,
        pass,
        fail,
        results,
        ui: KEEP
          ? {
              url: "https://mayabela.pages.dev",
              schoolId: SCHOOL,
              password: PASS,
              accounts: Object.fromEntries(
                Object.entries(users).map(([k, v]) => [
                  k,
                  { username: v.username, roleKey: v.roleKey },
                ]),
              ),
            }
          : null,
      },
      null,
      2,
    ),
  );
  console.log(`\nSummary: ${pass} pass / ${fail} fail`);
  if (!KEEP) await cleanup();
  else console.log("Kept SMOKE30 for UI (--keep).");
  process.exit(fail ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

/**
 * Seed the dedicated staging project for load/k6/school_erp.js.
 *
 * Loads ../.env.staging (never production). Refuses hwkiihonthueadbhcvfi.
 *
 *   node tools/seed_k6_staging.mjs
 */
import { createClient } from "@supabase/supabase-js";
import { createRequire } from "node:module";
import { randomBytes } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const bcrypt = require("bcryptjs");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROD_REF = "hwkiihonthueadbhcvfi";
const SCHOOL = "LOAD-001";
const PASSWORD = process.env.LOAD_PASSWORD || "LoadTest12!";
const BCRYPT_ROUNDS = 12;

const COUNTS = {
  parent: 250,
  teacher: 100,
  student: 100,
  admin: 30,
  finance: 20,
};

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  for (const line of fs.readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const i = trimmed.indexOf("=");
    if (i < 0) continue;
    const k = trimmed.slice(0, i).trim();
    const v = trimmed.slice(i + 1).trim();
    if (!process.env[k]) process.env[k] = v;
  }
}

loadEnvFile(path.join(__dirname, "..", ".env.staging"));

const url = (process.env.STAGING_SUPABASE_URL || "").replace(/\/$/, "");
const service = process.env.STAGING_SERVICE_ROLE_KEY || "";
if (!url || !service) {
  console.error("Set STAGING_SUPABASE_URL and STAGING_SERVICE_ROLE_KEY in .env.staging");
  process.exit(1);
}
if (url.includes(PROD_REF)) {
  console.error("Refusing to seed production.");
  process.exit(2);
}

const sb = createClient(url, service, {
  auth: { autoRefreshToken: false, persistSession: false },
});

function accountDocId(username) {
  return `${SCHOOL}__${String(username).trim().toLowerCase()}`;
}

function row(collection, docId, data) {
  return {
    collection,
    doc_id: docId,
    school_id: SCHOOL,
    data,
    updated_at: new Date().toISOString(),
  };
}

async function upsertChunk(rows) {
  const chunkSize = 80;
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    const { error } = await sb.from("app_documents").upsert(chunk, {
      onConflict: "collection,school_id,doc_id",
    });
    if (error) {
      console.error("upsert failed:", error.message);
      process.exit(1);
    }
    process.stdout.write(`  upserted ${Math.min(i + chunk.length, rows.length)}/${rows.length}\r`);
  }
  process.stdout.write("\n");
}

async function main() {
  console.log("Seeding staging", url, "school", SCHOOL);
  const stamp = new Date().toISOString();
  const passwordHash = bcrypt.hashSync(PASSWORD, BCRYPT_ROUNDS);

  const rows = [];
  rows.push(
    row("school_registry", SCHOOL, {
      id: SCHOOL,
      schoolId: SCHOOL,
      name: "MayaBela Load Staging",
      status: "active",
      adminFullName: "Load Admin",
      registeredAt: stamp,
      updatedAt: stamp,
    }),
  );

  for (let i = 1; i <= 20; i++) {
    const studentId = `LOAD-STU-${i}`;
    rows.push(
      row("student_registry", studentId, {
        studentId,
        schoolId: SCHOOL,
        fullName: `Load Student ${i}`,
        className: "Grade 1A",
        isActive: true,
      }),
    );
  }

  rows.push(
    row("app_announcements", "load-ann-1", {
      schoolId: SCHOOL,
      title: "Load test announcement",
      body: "Staging seed",
      createdAt: stamp,
    }),
    row("grade_reports", "load-grade-1", {
      schoolId: SCHOOL,
      studentId: "LOAD-STU-1",
      className: "Grade 1A",
      subject: "Math",
      score: 88,
    }),
    row("attendance_sessions", "load-att-1", {
      schoolId: SCHOOL,
      className: "Grade 1A",
      date: stamp.slice(0, 10),
      studentIds: ["LOAD-STU-1", "LOAD-STU-2"],
    }),
    row("homework", "load-hw-1", {
      schoolId: SCHOOL,
      className: "Grade 1A",
      title: "Load homework",
      studentIds: ["LOAD-STU-1"],
    }),
    row("fees", "load-fee-1", {
      schoolId: SCHOOL,
      studentId: "LOAD-STU-1",
      amount: 100,
      status: "unpaid",
    }),
    row("inventory_items", "load-inv-1", {
      schoolId: SCHOOL,
      name: "Load chalk",
      quantity: 12,
    }),
  );

  const specs = [
    { roleKey: "parent", prefix: "load-parent", n: COUNTS.parent, staffRoles: [] },
    { roleKey: "teacher", prefix: "load-teacher", n: COUNTS.teacher, staffRoles: [] },
    { roleKey: "student", prefix: "load-student", n: COUNTS.student, staffRoles: [] },
    { roleKey: "admin", prefix: "load-admin", n: COUNTS.admin, staffRoles: ["full_access"] },
    { roleKey: "teacher", prefix: "load-finance", n: COUNTS.finance, staffRoles: ["finance"] },
  ];

  const accounts = [];
  for (const spec of specs) {
    for (let vu = 1; vu <= spec.n; vu++) {
      const username = `${spec.prefix}-${vu}`;
      const docId = accountDocId(username);
      const studentId = `LOAD-STU-${((vu - 1) % 20) + 1}`;
      const data = {
        username,
        roleKey: spec.roleKey,
        schoolId: SCHOOL,
        fullName: `Load ${spec.prefix} ${vu}`,
        staffRoles: spec.staffRoles,
        updatedAt: stamp,
      };
      if (spec.roleKey === "parent") {
        data.linkedStudentIds = [studentId];
        data.linkedClassNames = ["Grade 1A"];
      }
      if (spec.roleKey === "student") {
        data.linkedStudentId = studentId;
      }
      accounts.push({ username, docId, data });
      rows.push(row("app_auth_accounts", docId, data));
      rows.push(
        row("auth_secrets", docId, {
          passwordHash,
          username,
          schoolId: SCHOOL,
          updatedAt: stamp,
        }),
      );
    }
  }

  console.log(`Writing ${rows.length} documents…`);
  await upsertChunk(rows);
  console.log(`Binding ${accounts.length} Auth users…`);
  await bindAuthUsers(accounts, passwordHash, stamp);
  console.log("Seed complete. Login password:", PASSWORD);
}

function sessionPassword() {
  return "Sx1!" + randomBytes(18).toString("base64").replace(/[+/=]/g, "x");
}

async function findAuthIdByEmail(email) {
  const res = await fetch(
    `${url}/auth/v1/admin/users?email=${encodeURIComponent(email)}&page=1&per_page=10`,
    { headers: { Authorization: `Bearer ${service}`, apikey: service } },
  );
  if (!res.ok) return "";
  const body = await res.json();
  const hit = (body.users || []).find((u) =>
    String(u.email || "").toLowerCase() === email.toLowerCase()
  );
  return hit?.id || "";
}

async function bindAuthUsers(accounts, passwordHash, stamp) {
  const concurrency = 8;
  let done = 0;
  for (let i = 0; i < accounts.length; i += concurrency) {
    const batch = accounts.slice(i, i + concurrency);
    await Promise.all(batch.map(async (account) => {
      const email = `${account.username}@load-001.mayabela.local`;
      const pass = sessionPassword();
      const meta = {
        role: account.data.roleKey,
        schoolId: SCHOOL,
        username: account.username,
        linkedStudentId: account.data.linkedStudentId || "",
        linkedStudentIds: account.data.linkedStudentIds || [],
        linkedClassNames: account.data.linkedClassNames || [],
        staffRoles: account.data.staffRoles || [],
      };
      let id = "";
      const created = await sb.auth.admin.createUser({
        email,
        password: pass,
        email_confirm: true,
        app_metadata: meta,
        user_metadata: { fullName: account.data.fullName, username: account.username },
      });
      if (created.data?.user?.id) {
        id = created.data.user.id;
      } else {
        id = await findAuthIdByEmail(email);
        if (!id) {
          for (let page = 1; page <= 20 && !id; page++) {
            const listed = await sb.auth.admin.listUsers({ page, perPage: 200 });
            const hit = (listed.data?.users || []).find((u) =>
              String(u.email || "").toLowerCase() === email
            );
            if (hit) id = hit.id;
            if ((listed.data?.users || []).length < 200) break;
          }
        }
        if (!id) {
          console.error("auth bind failed", account.username, created.error?.message);
          return;
        }
        const upd = await sb.auth.admin.updateUserById(id, {
          password: pass,
          email_confirm: true,
          app_metadata: meta,
        });
        if (upd.error) {
          console.error("auth update failed", account.username, upd.error.message);
          return;
        }
      }
      const { error } = await sb.from("app_documents").upsert({
        collection: "auth_secrets",
        doc_id: account.docId,
        school_id: SCHOOL,
        data: {
          passwordHash,
          username: account.username,
          schoolId: SCHOOL,
          authUserId: id,
          sessionPassword: pass,
          updatedAt: stamp,
        },
        updated_at: new Date().toISOString(),
      }, { onConflict: "collection,school_id,doc_id" });
      if (error) {
        console.error("secret bind failed", account.username, error.message);
      }
    }));
    done += batch.length;
    process.stdout.write(`  auth ${done}/${accounts.length}\r`);
  }
  process.stdout.write("\n");
}

await main();

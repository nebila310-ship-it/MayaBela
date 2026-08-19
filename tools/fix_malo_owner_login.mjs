/**
 * Fix corrupt MAL838 auth row + ensure owner secret is school-scoped.
 */
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { createClient } = require("@supabase/supabase-js");
const bcrypt = require("bcryptjs");

const __dirname = dirname(fileURLToPath(import.meta.url));
function loadEnvLocal() {
  const envPath = resolve(__dirname, "..", ".env.local");
  for (const line of readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith("#") || !t.includes("=")) continue;
    const i = t.indexOf("=");
    const k = t.slice(0, i).trim();
    let v = t.slice(i + 1).trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    if (!process.env[k]) process.env[k] = v;
  }
}
loadEnvLocal();

const sb = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

// 1) List schools
{
  const { data } = await sb
    .from("app_documents")
    .select("doc_id, data")
    .eq("collection", "school_registry")
    .limit(50);
  console.log(
    "schools:",
    (data || []).map((s) => ({
      id: s.doc_id,
      name: s.data?.name,
      admin: s.data?.adminContactPhone,
    })),
  );
}

// 2) Fix corrupt legacy admin row: data.schoolId=MAJ840 but column=MAL838
{
  const { data: row } = await sb
    .from("app_documents")
    .select("doc_id, school_id, data")
    .eq("collection", "app_auth_accounts")
    .eq("doc_id", "0977441122")
    .maybeSingle();
  console.log("before corrupt row:", JSON.stringify(row, null, 2));
  if (row) {
    const dataSchool = String(row.data?.schoolId || "").trim().toUpperCase();
    if (dataSchool === "MAJ840" && row.school_id === "MAL838") {
      const { error } = await sb
        .from("app_documents")
        .update({
          school_id: "MAJ840",
          data: {
            ...row.data,
            schoolId: "MAJ840",
            updatedAt: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        })
        .eq("collection", "app_auth_accounts")
        .eq("doc_id", "0977441122");
      console.log("fixed corrupt 0977441122 school_id -> MAJ840", error || "ok");
    }
  }
}

// 3) Ensure school-scoped owner secret exists for MAL838 (copy existing hash)
{
  const { data: legacy } = await sb
    .from("app_documents")
    .select("data")
    .eq("collection", "auth_secrets")
    .eq("doc_id", "0912798279")
    .maybeSingle();
  const passwordHash =
    legacy?.data?.passwordHash || bcrypt.hashSync("Welcome12!", 12);
  const { error } = await sb.from("app_documents").upsert(
    {
      collection: "auth_secrets",
      doc_id: "MAL838__0912798279",
      school_id: "MAL838",
      data: {
        passwordHash,
        username: "0912798279",
        schoolId: "MAL838",
        updatedAt: new Date().toISOString(),
      },
      updated_at: new Date().toISOString(),
    },
    { onConflict: "collection,school_id,doc_id" },
  );
  console.log("upsert owner secret MAL838__0912798279", error || "ok");
}

// 4) Re-test logins
const url = `${process.env.SUPABASE_URL}/functions/v1/school-login`;
async function tryLogin(label, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.SUPABASE_ANON_KEY}`,
      apikey: process.env.SUPABASE_ANON_KEY,
    },
    body: JSON.stringify(body),
  });
  console.log(label, res.status, (await res.text()).slice(0, 120));
}

await tryLogin("owner", {
  username: "0912798279",
  password: "Welcome12!",
  roleKey: "admin",
  schoolId: "MAL838",
});
await tryLogin("staff affairs", {
  username: "0910101010",
  password: "Welcome12!",
  roleKey: "teacher",
  schoolId: "MAL838",
});

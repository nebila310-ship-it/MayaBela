// Inventory of live Supabase data: collections in app_documents with row
// counts, storage buckets, and auth user count. Read-only.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const envText = readFileSync(resolve(process.cwd(), ".env.local"), "utf8");
const env = {};
for (const line of envText.split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+)\s*$/);
  if (m) env[m[1]] = m[2];
}
const URL_BASE = env.SUPABASE_URL;
const SERVICE = env.SUPABASE_SERVICE_ROLE_KEY;

async function rest(path, headers = {}) {
  const res = await fetch(`${URL_BASE}${path}`, {
    headers: {
      apikey: SERVICE,
      Authorization: `Bearer ${SERVICE}`,
      ...headers,
    },
  });
  return res;
}

async function main() {
  // Page through all docs, counting per collection and per school.
  const counts = {};
  const schools = new Set();
  let from = 0;
  const page = 1000;
  for (;;) {
    const res = await rest(
      `/rest/v1/app_documents?select=collection,school_id&order=collection`,
      { Range: `${from}-${from + page - 1}` },
    );
    if (res.status === 416) break;
    const rows = await res.json();
    if (!Array.isArray(rows) || rows.length === 0) break;
    for (const r of rows) {
      counts[r.collection] = (counts[r.collection] || 0) + 1;
      if (r.school_id) schools.add(r.school_id);
    }
    if (rows.length < page) break;
    from += page;
  }
  console.log("app_documents collections:");
  for (const [k, v] of Object.entries(counts).sort()) {
    console.log(`  ${k}: ${v}`);
  }
  console.log("total docs:", Object.values(counts).reduce((a, b) => a + b, 0));
  console.log("distinct school_ids:", [...schools].join(", ") || "(none)");

  const buckets = await (await rest(`/storage/v1/bucket`)).json();
  console.log("\nstorage buckets:", buckets.map?.((b) => `${b.name} (public=${b.public})`).join(", ") || JSON.stringify(buckets));

  const users = await (await rest(`/auth/v1/admin/users?page=1&per_page=1000`)).json();
  console.log("auth users:", users.users?.length ?? "?");
  for (const u of users.users || []) {
    console.log(`  ${u.email} role=${u.app_metadata?.role} school=${u.app_metadata?.schoolId}`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

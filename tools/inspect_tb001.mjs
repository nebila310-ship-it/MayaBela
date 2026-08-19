// Read-only inspection: tb-001 vs TB-001 rows, school_registry docs,
// account schoolIds, and storage objects.
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

async function rest(path, opts = {}) {
  const res = await fetch(`${URL_BASE}${path}`, {
    ...opts,
    headers: {
      apikey: SERVICE,
      Authorization: `Bearer ${SERVICE}`,
      "Content-Type": "application/json",
      ...(opts.headers || {}),
    },
  });
  return res.json();
}

async function main() {
  const reg = await rest(`/rest/v1/app_documents?collection=eq.school_registry&select=doc_id,school_id,data`);
  console.log("school_registry docs:");
  for (const r of reg) {
    console.log(`  doc_id=${r.doc_id} school_id=${r.school_id} name=${r.data?.name} id-in-data=${r.data?.id}`);
  }

  for (const sid of ["TB-001", "tb-001"]) {
    const rows = await rest(
      `/rest/v1/app_documents?school_id=eq.${encodeURIComponent(sid)}&select=collection`,
    );
    const counts = {};
    for (const r of rows) counts[r.collection] = (counts[r.collection] || 0) + 1;
    console.log(`\nschool_id=${sid}: ${rows.length} rows`);
    for (const [k, v] of Object.entries(counts).sort()) console.log(`  ${k}: ${v}`);
  }

  const accounts = await rest(
    `/rest/v1/app_documents?collection=eq.app_auth_accounts&select=doc_id,school_id,data`,
  );
  console.log("\naccounts (doc_id / roleKey / schoolId-in-data):");
  for (const a of accounts) {
    console.log(`  ${a.doc_id} role=${a.data?.roleKey} school=${a.data?.schoolId} (col school_id=${a.school_id})`);
  }

  const objects = await rest(`/storage/v1/object/list/school-files`, {
    method: "POST",
    body: JSON.stringify({ prefix: "", limit: 100 }),
  });
  console.log("\nstorage top-level entries:", JSON.stringify(objects?.map?.((o) => o.name) ?? objects));
  const schools = await rest(`/storage/v1/object/list/school-files`, {
    method: "POST",
    body: JSON.stringify({ prefix: "schools", limit: 100 }),
  });
  console.log("storage under schools/:", JSON.stringify(schools?.map?.((o) => o.name) ?? schools));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

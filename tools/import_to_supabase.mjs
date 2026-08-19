/**
 * Import tools/firestore_export into Supabase app_documents.
 *
 * Loads ../.env.local automatically for SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY.
 *
 *   node tools/import_to_supabase.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { createClient } = require("@supabase/supabase-js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const exportRoot = path.join(__dirname, "firestore_export");

function loadEnvLocal() {
  const envPath = path.join(__dirname, "..", ".env.local");
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const i = trimmed.indexOf("=");
    if (i < 0) continue;
    const k = trimmed.slice(0, i).trim();
    const v = trimmed.slice(i + 1).trim();
    if (!process.env[k]) process.env[k] = v;
  }
}

loadEnvLocal();

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}
if (!fs.existsSync(exportRoot)) {
  console.error(`Missing export folder: ${exportRoot}`);
  console.error("Run: node tools/export_firestore.mjs");
  process.exit(1);
}

const sb = createClient(url, key, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const collections = fs
  .readdirSync(exportRoot, { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => d.name);

let total = 0;
for (const collection of collections) {
  const dir = path.join(exportRoot, collection);
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".json"));
  const rows = [];
  for (const file of files) {
    const payload = JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
    const data = payload.data || {};
    const schoolId =
      typeof data.schoolId === "string" && data.schoolId.trim()
        ? data.schoolId.trim()
        : null;
    rows.push({
      collection: payload.collection || collection,
      doc_id: payload.doc_id,
      school_id: schoolId,
      data,
      updated_at: new Date().toISOString(),
    });
  }

  const chunkSize = 200;
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    const { error } = await sb.from("app_documents").upsert(chunk, {
      onConflict: "collection,school_id,doc_id",
    });
    if (error) {
      console.error(`Failed ${collection} chunk @${i}:`, error.message);
      process.exit(1);
    }
  }
  console.log(`${collection}: imported ${rows.length}`);
  total += rows.length;
}

console.log(`Imported ${total} documents into app_documents`);

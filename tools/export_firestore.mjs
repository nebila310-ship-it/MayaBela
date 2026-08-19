/**
 * Export Firestore collections into tools/firestore_export/
 *
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccount.json
 *   node tools/export_firestore.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const {
  initializeApp,
  getApps,
  applicationDefault,
  cert,
} = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const outRoot = path.join(__dirname, "firestore_export");
const projectId = process.env.FIREBASE_PROJECT_ID || "majo-e-school-bridge";
const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!getApps().length) {
  let credential = applicationDefault();
  if (credPath && fs.existsSync(credPath)) {
    const sa = JSON.parse(fs.readFileSync(credPath, "utf8"));
    credential = cert(sa);
  }
  initializeApp({ credential, projectId });
}

const db = getFirestore();

const COLLECTIONS = [
  "app_auth_accounts",
  "auth_secrets",
  "auth_rate_limits",
  "parent_link_requests",
  "student_medical",
  "student_registry",
  "teacher_registry",
  "driver_registry",
  "grade_reports",
  "homework",
  "daily_activities",
  "conversations",
  "app_announcements",
  "attendance_sessions",
  "fees",
  "calendar_events",
  "class_timetables",
  "gallery_posts",
  "learning_materials",
  "grade_audit_log",
  "qr_scans",
  "school_registry",
  "platform_audit_log",
  "fcm_tokens",
  "transport_scans",
  "transport_passenger_status",
  "bus_live_positions",
  "app_notifications",
  "inventory_items",
  "stock_transactions",
  "student_issued_items",
  "classroom_inventory",
  "assets",
  "suppliers",
  "maintenance_reports",
  "users",
  "classes",
  "students",
  "parents",
  "parent_student_links",
  "teachers",
  "teacher_assignments",
  "drivers",
  "routes",
  "transport_assignments",
  "attendance",
  "grades",
  "announcements",
];

function serialize(value) {
  if (value == null) return value;
  if (typeof value?.toDate === "function") return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(serialize);
  if (typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = serialize(v);
    return out;
  }
  return value;
}

fs.mkdirSync(outRoot, { recursive: true });
let total = 0;

for (const collection of COLLECTIONS) {
  const dir = path.join(outRoot, collection);
  fs.mkdirSync(dir, { recursive: true });
  try {
    const snap = await db.collection(collection).get();
    console.log(`${collection}: ${snap.size} docs`);
    for (const doc of snap.docs) {
      const payload = {
        collection,
        doc_id: doc.id,
        data: serialize(doc.data()),
      };
      const safeId = doc.id.replace(/[\\/:*?"<>|]/g, "_");
      fs.writeFileSync(
        path.join(dir, `${safeId}.json`),
        JSON.stringify(payload, null, 2),
      );
      total += 1;
    }
  } catch (e) {
    console.log(`${collection}: SKIP (${e.message})`);
  }
}

console.log(`Exported ${total} documents to ${outRoot}`);

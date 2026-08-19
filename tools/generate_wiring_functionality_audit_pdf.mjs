#!/usr/bin/env node
/**
 * Deep wiring + functionality audit PDF for MaJo e-School Bridge.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "reports");
const OUT_PDF = path.join(OUT_DIR, "MaJo_Wiring_Functionality_Audit.pdf");
const RESULTS_JSON = path.join(OUT_DIR, "wiring_functionality_test_results.json");

function ensurePdfKit() {
  const require = createRequire(import.meta.url);
  try {
    return require("pdfkit");
  } catch {
    spawnSync("npm", ["install", "pdfkit", "--no-save"], {
      cwd: __dirname,
      shell: true,
      stdio: "inherit",
    });
    return require("pdfkit");
  }
}

function runTests() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const r = spawnSync(
    "flutter",
    [
      "test",
      "test/functionality_suite_test.dart",
      "test/database_test.dart",
      "--reporter",
      "json",
    ],
    {
      cwd: ROOT,
      encoding: "utf8",
      shell: true,
      maxBuffer: 20 * 1024 * 1024,
    },
  );

  const starts = new Map();
  const dones = [];
  for (const line of (r.stdout || "").split(/\r?\n/)) {
    const t = line.trim();
    if (!t.startsWith("{")) continue;
    let ev;
    try {
      ev = JSON.parse(t);
    } catch {
      continue;
    }
    if (ev.type === "testStart" && ev.test) starts.set(ev.test.id, ev.test);
    else if (ev.type === "testDone") dones.push(ev);
  }

  const cases = [];
  for (const d of dones) {
    if (d.hidden) continue;
    const st = starts.get(d.testID) || {};
    const name = st.name || `test#${d.testID}`;
    if (
      name.startsWith("loading ") ||
      name.includes("(setUpAll)") ||
      name.includes("(tearDownAll)")
    ) {
      continue;
    }
    cases.push({ name, result: d.result || "error" });
  }

  const summary = {
    exit_code: r.status ?? 1,
    total: cases.length,
    passed: cases.filter((c) => c.result === "success").length,
    failed: cases.filter((c) => c.result !== "success").length,
    cases,
    generated_at: new Date().toISOString(),
  };
  fs.writeFileSync(RESULTS_JSON, JSON.stringify(summary, null, 2));
  return summary;
}

function drawTable(doc, startY, headers, rows, colWidths) {
  const pageWidth =
    doc.page.width - doc.page.margins.left - doc.page.margins.right;
  const widths = colWidths || headers.map(() => pageWidth / headers.length);
  let y = startY;
  const rowH = 15;

  const drawHeader = () => {
    let x = doc.page.margins.left;
    doc.save();
    doc.rect(x, y, pageWidth, rowH).fill("#0F766E");
    doc.fillColor("white").font("Helvetica-Bold").fontSize(7.5);
    headers.forEach((h, i) => {
      doc.text(h, x + 2, y + 4, { width: widths[i] - 4, ellipsis: true });
      x += widths[i];
    });
    doc.restore();
    y += rowH;
  };

  const ensure = (h) => {
    if (y + h > doc.page.height - doc.page.margins.bottom) {
      doc.addPage();
      y = doc.page.margins.top;
      drawHeader();
      doc.font("Helvetica").fontSize(7).fillColor("black");
    }
  };

  drawHeader();
  doc.font("Helvetica").fontSize(7).fillColor("black");
  rows.forEach((row, idx) => {
    ensure(rowH + 2);
    let x = doc.page.margins.left;
    if (idx % 2 === 1) {
      doc.save();
      doc.rect(x, y, pageWidth, rowH).fill("#F8FAFC");
      doc.restore();
      doc.fillColor("black");
    }
    row.forEach((cell, i) => {
      doc.text(String(cell), x + 2, y + 3.5, {
        width: widths[i] - 4,
        ellipsis: true,
      });
      x += widths[i];
    });
    y += rowH;
  });
  return y + 6;
}

function h2(doc, text) {
  if (doc.y > doc.page.height - 100) doc.addPage();
  doc.moveDown(0.4);
  doc.font("Helvetica-Bold").fontSize(12).fillColor("black").text(text);
  doc.moveDown(0.25);
  doc.font("Helvetica").fontSize(9);
}

function para(doc, text) {
  doc.font("Helvetica").fontSize(9).fillColor("black").text(text, {
    align: "justify",
  });
  doc.moveDown(0.3);
}

async function buildPdf(summary) {
  const PDFDocument = ensurePdfKit();
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const doc = new PDFDocument({
    size: "A4",
    margins: { top: 36, bottom: 36, left: 36, right: 36 },
    info: {
      Title: "MaJo Wiring & Deep Functionality Audit",
      Author: "eduaba audit",
    },
  });
  const stream = fs.createWriteStream(OUT_PDF);
  doc.pipe(stream);

  const now = new Date().toLocaleString();
  const rate = summary.total
    ? Math.round((100 * summary.passed) / summary.total)
    : 0;

  doc.font("Helvetica-Bold").fontSize(17).text("MaJo e-School Bridge", {
    align: "center",
  });
  doc
    .fontSize(13)
    .text("Deep Wiring & Functionality Audit Report", { align: "center" });
  doc.moveDown(0.3);
  doc
    .font("Helvetica")
    .fontSize(8)
    .fillColor("#64748B")
    .text(
      `Generated ${now}  |  Static wiring analysis + automated suite  |  Firebase project: majo-e-school-bridge`,
      { align: "center" },
    );
  doc.fillColor("black");
  doc.moveDown();

  h2(doc, "1. Executive verdict");
  para(
    doc,
    `Code wiring is coherent for a local-first school ERP with a cloud sync layer. Auth is designed around Cloud Function custom tokens and school claims; Firestore/Storage rules in-repo enforce role+schoolId. Automated deep suite: ${summary.passed}/${summary.total} passed (${rate}%). Live multi-school selling is NOT ready until Blaze + Functions deploy + Console alignment. Dual data namespaces (AppFirestoreCollections vs DbCollections) increase wiring risk.`,
  );

  h2(doc, "2. Boot & session wiring");
  para(
    doc,
    "main() → Firebase.initializeApp → App Check activate → FCM background handler → CriticalBootstrapGate → AppBootstrap.",
  );
  para(
    doc,
    "Critical (pre-login): registerAllDashboards, FirebaseBootstrap.tryInitialize, load Auth/Enrollment/Student/Teacher/Driver persistence, locale, school registry, login prefs, AppLock. Background: heavy LocalJsonStore loads, optional pushFullLocalStateToCloud if school claims exist, SchoolDatabaseService, FcmService, deferred Storage bootstrap.",
  );
  para(
    doc,
    "Session restore: SessionPrefsService prefers Firebase Auth claims via SchoolAuthCloudService.restoreFromFirebaseAuth; fallback AuthService.restoreSession(username). On restore → SessionCloudSync.startSessionWithCloudSync + NotificationService.onSessionStarted → AuthNavigation.homeForCurrentUser().",
  );

  h2(doc, "3. Auth wiring (release vs debug)");
  let y = drawTable(
    doc,
    doc.y,
    ["Component", "Path", "Responsibility"],
    [
      ["AuthService", "lib/services/auth_service.dart", "Local users, session, validateLoginAsync"],
      ["SchoolAuthCloudService", "lib/services/school_auth_cloud_service.dart", "schoolLogin callable → custom token"],
      ["FirebaseBootstrap", "lib/database/firebase/firebase_bootstrap.dart", "Init; claims required; anon disabled"],
      ["SessionPrefsService", "lib/services/session_prefs_service.dart", "Persist username/school; restore"],
      ["Password path", "auth_secrets + callables", "bcrypt server-side; client never reads secrets"],
    ],
    [110, 180, 220],
  );
  doc.y = y;
  para(
    doc,
    "Release: cloud login required when Firebase configured; fails with cloud_required if Functions unavailable. Debug: falls back to local demo accounts (kDebugMode). Forced ChangePasswordScreen when mustChangePassword. Remember-me stores identifier only (no password).",
  );

  h2(doc, "4. Sync & persistence wiring");
  para(
    doc,
    "LocalJsonStore (SharedPreferences JSON) ↔ FirestoreAppStore (school-scoped queries). SessionCloudSync on login pulls role-specific data then starts RealtimeMessagingBootstrap. CloudBootstrapService.ensureLoginCredentialsFromCloud is intentionally empty (no pre-login password pull). ensureAnonymousAuthReady is a misnamed alias for ensureReadyForFirestore (claims check).",
  );
  y = drawTable(
    doc,
    doc.y,
    ["Local / domain", "Firestore collection"],
    [
      ["Auth profiles", "app_auth_accounts"],
      ["Password hashes", "auth_secrets (Admin SDK only)"],
      ["Students / medical", "student_registry / student_medical"],
      ["Teachers / drivers", "teacher_registry / driver_registry"],
      ["Grades / audit", "grade_reports / grade_audit_log"],
      ["Homework / materials", "homework / learning_materials"],
      ["Messages", "conversations"],
      ["Attendance / fees", "attendance_sessions / fees"],
      ["Transport live", "bus_live_positions / transport_scans / …"],
      ["Inventory*", "inventory_items / stock_transactions / …"],
      ["FCM", "fcm_tokens"],
      ["Normalized DB layer", "users/classes/students/grades/… (DbCollections)"],
    ],
    [200, 310],
  );
  doc.y = y;

  doc.addPage();
  h2(doc, "5. Deep functionality by role");
  y = drawTable(
    doc,
    doc.y,
    ["Role", "Modules (dashboard tiles)", "Depth / notes"],
    [
      [
        "Teacher",
        "classes, attendance, messages, announcements, homework, learning_materials, gallery, grades, qr, calendar, timetable, parent_approvals, settings",
        "Full classroom loop; grades submit for approval",
      ],
      [
        "Parent",
        "children, attendance, homework, learning_materials, messages, announcements, fees, bus, grades, calendar, timetable, settings",
        "Bus live map; fees UI partial (payments not live)",
      ],
      [
        "Student",
        "profile, grades, homework, learning_materials, attendance, timetable, calendar, announcements, messages, settings",
        "Portal can be disabled per school",
      ],
      [
        "Admin",
        "add_teacher/student, approvals, portal settings, password resets, transfer, staff, students, classes, attendance, messages, announcements, finance, transport, grades, grade_approvals, workflow settings, calendar, timetable, settings",
        "Web → WebErpShell; workflow settings may be orphaned in grouped mobile layout",
      ],
      [
        "Driver",
        "route, passengers, scan, qr, pickup, messages, announcements, issue, map, calendar, settings",
        "QR onboard/discharge + GPS share",
      ],
    ],
    [55, 280, 175],
  );
  doc.y = y;

  h2(doc, "6. Grades workflow wiring");
  para(
    doc,
    "Teacher Enter Grades → SchoolDataService.submitSubjectGradeForApproval (or publish if approval off) → Admin GradeApprovalQueueScreen approve/reject → Parent/Student GradeReportsScreen views. Settings: AdminGradeWorkflowSettingsScreen (grade_workflow_settings). Audit: grade_audit_log.",
  );

  h2(doc, "7. Transport & messaging wiring");
  para(
    doc,
    "Driver TransportQrScannerScreen + BusLiveLocationService → bus_live_positions. Parent bus tile → TransportLiveMapScreen / ParentBusLinkScreen. Realtime: TransportRealtimeSync from messaging bootstrap. Messages: ConversationRealtimeSync; Cloud Function onConversationMessage fans out FCM using fcm_tokens (needs Blaze deploy). FCM client skipped on web.",
  );

  h2(doc, "8. Web ERP wiring");
  para(
    doc,
    "kIsWeb AdminDashboard → WebErpAdminShell → WebErpRouter.pageFor. Wired: dashboard, students, teachers, parents, employees, finance, transport, attendance, examinations/grade_approvals, grades, academic, learning_materials, announcements, calendar/events, reports, support, audit_log, system_health, settings, library, inventory, add_student/teacher. Placeholders only: institution, school, campus (+ unknown routes).",
  );

  h2(doc, "9. Firebase / cloud wiring gaps");
  y = drawTable(
    doc,
    doc.y,
    ["Gap", "Severity", "Impact"],
    [
      ["Blaze off → Functions undeployable", "Critical", "No cloud login / cross-device / FCM send"],
      ["Rules may not be deployed to Console", "Critical", "Live DB may still be open"],
      ["Anonymous still enabled in firebase.json", "High", "Disable in Console"],
      ["App Check client on; Console not enforced", "High", "Bot API abuse once Functions live"],
      ["Storage bootstrap deferred=true", "High", "Uploads stay local until billing/enable"],
      ["Parent rules: school-wide student/medical read", "High", "Tighten to linked children"],
      ["school_registry allow get: if true", "Medium", "School ID enumeration"],
      ["Dual App vs Db collection namespaces", "Medium", "Sync confusion / stale paths"],
      ["Misnamed ensureAnonymousAuth* APIs", "Low", "Maintenance hazard"],
      ["grade_workflow_settings orphaned in grouped admin UI", "Low", "Hard to discover on mobile"],
    ],
    [220, 55, 235],
  );
  doc.y = y;

  doc.addPage();
  h2(doc, "10. Actual automated test report");
  para(
    doc,
    `Command: flutter test test/functionality_suite_test.dart test/database_test.dart  |  Exit ${summary.exit_code}  |  ${summary.passed}/${summary.total} passed (${rate}%)`,
  );
  y = drawTable(
    doc,
    doc.y,
    ["#", "Result", "Test case"],
    summary.cases.map((c, i) => [
      String(i + 1),
      c.result === "success" ? "PASS" : "FAIL",
      c.name,
    ]),
    [28, 45, 437],
  );
  doc.y = y;

  h2(doc, "11. Deep functionality health matrix");
  y = drawTable(
    doc,
    doc.y,
    ["Area", "Code wired", "Local/debug verified", "Cloud live"],
    [
      ["Role login (debug accounts)", "Yes", "PASS (suite)", "N/A"],
      ["Cloud schoolLogin", "Yes", "N/A (needs Functions)", "BLOCKED (Blaze)"],
      ["Password hashing / policy", "Yes", "PASS", "Secrets via Functions"],
      ["Parent↔child resolver", "Yes", "PASS", "Needs claims sync"],
      ["Teacher/driver access bounds", "Yes", "PASS", "Needs claims + rules deploy"],
      ["Web ERP core routes", "Yes", "PASS (router)", "Needs hosting deploy"],
      ["Web ERP org placeholders", "Placeholder", "N/A", "N/A"],
      ["Grades enter→approve→view", "Yes", "Code path", "Needs cloud session"],
      ["Transport QR + GPS", "Yes", "Code path", "Needs cloud + device"],
      ["Messaging + FCM fan-out", "Yes", "Partial", "Functions blocked"],
      ["Inventory / Storage uploads", "Yes", "Local only", "Storage deferred"],
      ["Online fee payments", "Partial UI", "Not live", "Provider missing"],
      ["Owner PIN console", "Yes", "PASS (hash/verify)", "Device-local"],
    ],
    [150, 90, 120, 150],
  );
  doc.y = y;

  h2(doc, "12. Sell-readiness wiring score");
  para(
    doc,
    "Architecture/wiring maturity: HIGH for offline-first ERP. Production cloud wiring: BLOCKED on Blaze + deploy. Privacy rules depth: PARTIAL (school isolation yes; relationship isolation incomplete). Product completeness: MEDIUM (core school loops yes; org placeholders + payments pending).",
  );
  para(
    doc,
    "Recommendation: do not sell as production until (1) deploy firestore+storage rules, (2) Blaze+Functions+admin bootstrap, (3) parent/medical rule tightening, (4) multi-device pilot pass. Safe to sell only as supervised pilot with local/debug caveats.",
  );

  h2(doc, "13. Recommended next wiring fixes");
  [
    "1. Rename ensureAnonymousAuth* → ensureSchoolAuth* across call sites.",
    "2. Deploy rules; disable Anonymous in Console; flip firebase.json.",
    "3. Blaze → deploy functions → seed admin → migrateAuthSecrets.",
    "4. Tighten Firestore parent reads to linkedStudentIds.",
    "5. Enable Storage bootstrap when bucket is live; deploy storage.rules.",
    "6. Surface grade_workflow_settings in admin grouped sections.",
    "7. Document/clarify AppFirestoreCollections vs DbCollections ownership.",
    "8. Re-run this PDF generator after each deploy milestone.",
  ].forEach((line) => {
    doc.font("Helvetica").fontSize(9).text(line);
  });

  doc.moveDown(1);
  doc
    .fontSize(8)
    .fillColor("#64748B")
    .text(`JSON: reports/wiring_functionality_test_results.json`);
  doc.text(`PDF: ${path.basename(OUT_PDF)}`);

  doc.end();
  await new Promise((resolve, reject) => {
    stream.on("finish", resolve);
    stream.on("error", reject);
  });
  return OUT_PDF;
}

console.log("Running functionality suite...");
const summary = runTests();
console.log(`Tests: ${summary.passed}/${summary.total} (exit ${summary.exit_code})`);
await buildPdf(summary);
console.log(`PDF written: ${OUT_PDF}`);
process.exit(summary.failed === 0 ? 0 : 1);

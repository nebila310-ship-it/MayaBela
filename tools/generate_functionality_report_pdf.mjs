#!/usr/bin/env node
/**
 * Runs functionality tests and writes a PDF report.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "reports");
const OUT_PDF = path.join(OUT_DIR, "MaJo_Functionality_Test_Report.pdf");
const RESULTS_JSON = path.join(OUT_DIR, "functionality_test_results.json");

function ensurePdfKit() {
  const require = createRequire(import.meta.url);
  try {
    return require("pdfkit");
  } catch {
    console.log("Installing pdfkit...");
    const r = spawnSync("npm", ["install", "pdfkit", "--no-save"], {
      cwd: __dirname,
      shell: true,
      stdio: "inherit",
    });
    if (r.status !== 0) throw new Error("npm install pdfkit failed");
    return require("pdfkit");
  }
}

const FEATURES = [
  ["Shared", "Login / roles", "Role-based sign-in (admin, teacher, parent, student, driver)", "Implemented", "Cloud login needs Blaze Functions"],
  ["Shared", "Forgot / change password", "OTP + password reset / forced change", "Implemented", "Real SMS needs Blaze Phone Auth"],
  ["Shared", "Localization", "EN / Amharic / Oromo", "Implemented", "None"],
  ["Shared", "Settings & app lock", "Preferences, background lock / web idle timeout", "Implemented", "None"],
  ["Shared", "Push notifications", "FCM token + local notifications", "Implemented", "FCM send via Functions needs Blaze"],
  ["Shared", "Messaging", "Conversations, attachments, voice", "Implemented", "Cloud sync needs auth claims"],
  ["Shared", "Announcements", "Create/view school announcements", "Implemented", "Cloud sync"],
  ["Shared", "Calendar / timetable", "Events and class timetables", "Implemented", "Cloud sync"],
  ["Teacher", "Classes", "My classes view", "Implemented", "Cloud sync"],
  ["Teacher", "Attendance", "Take / view attendance", "Implemented", "Cloud sync"],
  ["Teacher", "Homework", "Assign / manage homework", "Implemented", "Cloud sync"],
  ["Teacher", "Learning materials", "Share materials", "Implemented", "Storage may need Blaze"],
  ["Teacher", "Grades", "Enter grades / reports", "Implemented", "Cloud sync"],
  ["Teacher", "Gallery / QR", "Gallery posts and QR tools", "Implemented", "Camera device"],
  ["Parent", "Children", "Linked children overview", "Implemented", "Cloud sync"],
  ["Parent", "Fees", "Fee view / payment UX (provider pending)", "Partial", "Online payments not live"],
  ["Parent", "Bus tracking", "Live bus / transport status", "Implemented", "Cloud + location"],
  ["Parent", "Signup / approvals", "Register + admin approval", "Implemented", "Register callable needs Blaze"],
  ["Student", "Portal", "Grades, homework, materials, attendance", "Implemented", "Portal flags / cloud"],
  ["Admin", "People registries", "Students / teachers / staff CRUD", "Implemented", "Cloud sync"],
  ["Admin", "Finance", "Fees / finance dashboard", "Implemented", "Cloud sync"],
  ["Admin", "Transport admin", "Routes, drivers, scans", "Implemented", "Cloud sync"],
  ["Admin", "Grade approvals", "Workflow queue", "Implemented", "Cloud sync"],
  ["Admin", "Inventory (web)", "Stock / assets module", "Implemented", "Storage + Blaze bucket"],
  ["Admin", "Web ERP shell", "Sidebar ERP for web admin", "Implemented", "Flutter web"],
  ["Admin", "Institution / campus", "Org management entries", "Placeholder", "UI placeholders"],
  ["Driver", "Route / passengers", "Assigned route and list", "Implemented", "Cloud sync"],
  ["Driver", "QR scan / pickup", "Transport scanning", "Implemented", "Camera"],
  ["Driver", "Live map share", "GPS publish for parents", "Implemented", "Location + cloud"],
  ["Platform", "Owner console", "Hidden PIN console", "Implemented", "Device-local PIN"],
  ["Platform", "Audit / health", "Audit log and system health", "Implemented", "Cloud sync"],
];

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
    if (ev.type === "testStart" && ev.test) {
      starts.set(ev.test.id, ev.test);
    } else if (ev.type === "testDone") {
      dones.push(ev);
    }
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
    cases.push({
      name,
      result: d.result || "error",
      file: st.url || "",
    });
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
  const widths =
    colWidths || headers.map(() => pageWidth / headers.length);
  let y = startY;
  const rowH = 16;

  const ensureSpace = (h) => {
    if (y + h > doc.page.height - doc.page.margins.bottom) {
      doc.addPage();
      y = doc.page.margins.top;
      // redraw header
      drawHeader();
    }
  };

  const drawHeader = () => {
    let x = doc.page.margins.left;
    doc.save();
    doc.rect(x, y, pageWidth, rowH).fill("#0F766E");
    doc.fillColor("white").font("Helvetica-Bold").fontSize(8);
    headers.forEach((h, i) => {
      doc.text(h, x + 3, y + 4, { width: widths[i] - 6, ellipsis: true });
      x += widths[i];
    });
    doc.restore();
    y += rowH;
  };

  drawHeader();
  doc.font("Helvetica").fontSize(7.5).fillColor("black");

  rows.forEach((row, idx) => {
    ensureSpace(rowH + 2);
    let x = doc.page.margins.left;
    if (idx % 2 === 1) {
      doc.save();
      doc.rect(x, y, pageWidth, rowH).fill("#F8FAFC");
      doc.restore();
    }
    doc.fillColor("black");
    row.forEach((cell, i) => {
      doc.text(String(cell), x + 3, y + 4, {
        width: widths[i] - 6,
        ellipsis: true,
      });
      x += widths[i];
    });
    y += rowH;
  });
  return y + 8;
}

async function buildPdf(summary) {
  const PDFDocument = ensurePdfKit();
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const doc = new PDFDocument({
    size: "A4",
    margins: { top: 40, bottom: 40, left: 40, right: 40 },
    info: {
      Title: "MaJo e-School Bridge — Functionality & Test Report",
      Author: "eduaba audit",
    },
  });
  const stream = fs.createWriteStream(OUT_PDF);
  doc.pipe(stream);

  const now = new Date().toLocaleString();
  const rate = summary.total
    ? Math.round((100 * summary.passed) / summary.total)
    : 0;

  doc.font("Helvetica-Bold").fontSize(18).text("MaJo e-School Bridge", {
    align: "center",
  });
  doc
    .fontSize(14)
    .text("Functionality Report & Actual Test Results", { align: "center" });
  doc.moveDown(0.4);
  doc
    .font("Helvetica")
    .fontSize(9)
    .fillColor("#64748B")
    .text(
      `Generated ${now}  |  Flutter Android + Web ERP  |  Firebase: majo-e-school-bridge`,
      { align: "center" },
    );
  doc.fillColor("black");
  doc.moveDown();

  doc.font("Helvetica-Bold").fontSize(12).text("1. Executive summary");
  doc.moveDown(0.3);
  doc
    .font("Helvetica")
    .fontSize(10)
    .text(
      `Automated functionality suite executed ${summary.total} tests: ${summary.passed} passed, ${summary.failed} failed (${rate}% pass). ` +
        "Cloud-dependent features (server login, SMS OTP, Storage bucket, FCM fan-out) are implemented in code but blocked on Firebase Blaze / deployment for live multi-device use.",
      { align: "justify" },
    );

  doc.moveDown();
  doc.font("Helvetica-Bold").fontSize(12).text("2. Product surfaces");
  doc.moveDown(0.3);
  doc.font("Helvetica").fontSize(10);
  doc.text("• Android app — role dashboards (teacher, parent, student, admin, driver)");
  doc.text("• Web ERP — Flutter web admin shell (lib/web_erp)");
  doc.text("• Backend — Firestore, Storage, Cloud Functions, Hosting");

  doc.moveDown();
  doc.font("Helvetica-Bold").fontSize(12).text("3. Functionality inventory");
  doc
    .font("Helvetica")
    .fontSize(8)
    .fillColor("#64748B")
    .text(
      "Implemented = code wired; Partial = gaps; Placeholder = nav without full module.",
    );
  doc.fillColor("black");
  let y = doc.y + 6;
  y = drawTable(
    doc,
    y,
    ["Role", "Module", "Description", "Status", "Notes / deps"],
    FEATURES,
    [55, 85, 160, 70, 130],
  );
  doc.y = y;

  doc.addPage();
  doc.font("Helvetica-Bold").fontSize(12).text("4. Actual automated test report");
  doc.moveDown(0.3);
  doc
    .font("Helvetica")
    .fontSize(9)
    .text(
      "Command: flutter test test/functionality_suite_test.dart test/database_test.dart",
    );
  doc.text(`Exit code: ${summary.exit_code}  |  Pass rate: ${rate}%`);
  doc.moveDown(0.4);

  const testRows = summary.cases.map((c, i) => [
    String(i + 1),
    c.result === "success" ? "PASS" : "FAIL",
    c.name,
  ]);
  y = drawTable(doc, doc.y, ["#", "Result", "Test case"], testRows, [30, 50, 420]);
  doc.y = y + 4;

  doc.font("Helvetica-Bold").fontSize(12).text("5. Manual / environment checks");
  doc.moveDown(0.3);
  y = drawTable(
    doc,
    doc.y,
    ["Check", "Result", "Reason"],
    [
      ["Cloud schoolLogin (phone/web)", "BLOCKED", "Needs Blaze + deployed Functions"],
      ["Firebase Phone SMS OTP (release)", "BLOCKED", "Needs Blaze + Phone Auth setup"],
      ["Cross-device Firestore sync", "BLOCKED", "Needs custom-token session"],
      ["Storage upload/download", "BLOCKED/PENDING", "Bucket/billing + deploy rules"],
      ["Maps on web", "PENDING CONFIG", "Set web/maps_api_key.js"],
      ["Play release signing", "PENDING CONFIG", "android/key.properties + keystore"],
      ["widget_test Login screen", "FAIL (known)", "Needs Firebase mock; excluded from suite"],
    ],
    [160, 90, 250],
  );
  doc.y = y;

  doc.font("Helvetica-Bold").fontSize(12).text("6. Role coverage (local/debug)");
  doc.moveDown(0.3);
  y = drawTable(
    doc,
    doc.y,
    ["Capability", "Admin", "Teacher", "Parent", "Student", "Driver"],
    [
      ["Local debug login", "Yes", "Yes", "Yes", "Seeded", "Yes"],
      ["Messages", "Yes", "Yes", "Yes", "Yes", "Yes"],
      ["Attendance", "Yes", "Yes", "View", "View", "Transport"],
      ["Grades", "Approve", "Enter", "View", "View", "—"],
      ["Fees", "Manage", "—", "View*", "—", "—"],
      ["Transport / bus", "Manage", "—", "Track", "—", "Operate"],
      ["Inventory (web)", "Yes", "—", "—", "—", "—"],
      ["Cloud (Spark today)", "No", "No", "No", "No", "No"],
    ],
    [110, 70, 70, 70, 70, 70],
  );
  doc.y = y;
  doc
    .font("Helvetica")
    .fontSize(8)
    .fillColor("#64748B")
    .text("* Parent online fee providers not live.");
  doc.fillColor("black");

  doc.moveDown();
  doc.font("Helvetica-Bold").fontSize(12).text("7. Recommendations");
  doc.moveDown(0.3);
  doc.font("Helvetica").fontSize(10);
  [
    "1. Use local/debug for feature QA until Blaze.",
    "2. Deploy Firestore + Storage rules on Spark now.",
    "3. After Blaze: deploy Functions, bootstrap admin, re-run this report + manual cloud login.",
    "4. Fix/mock Firebase in test/widget_test.dart for CI.",
    "5. Add integration_test/patrol for dashboards once cloud auth is live.",
  ].forEach((line) => doc.text(line));

  doc.moveDown(1.5);
  doc
    .fontSize(8)
    .fillColor("#64748B")
    .text(`Raw JSON: reports/functionality_test_results.json`);
  doc.text(`PDF: ${path.basename(OUT_PDF)}`);

  doc.end();
  await new Promise((resolve, reject) => {
    stream.on("finish", resolve);
    stream.on("error", reject);
  });
  return OUT_PDF;
}

const summary = runTests();
console.log(
  `Tests: ${summary.passed}/${summary.total} passed (exit ${summary.exit_code})`,
);
await buildPdf(summary);
console.log(`PDF written: ${OUT_PDF}`);
process.exit(summary.failed === 0 ? 0 : 1);

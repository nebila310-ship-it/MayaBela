#!/usr/bin/env python3
"""Generate MaJo e-School Bridge functionality + test report PDF."""

from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_LEFT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import (
        PageBreak,
        Paragraph,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    )
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "reportlab"])
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_LEFT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import (
        PageBreak,
        Paragraph,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    )


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "reports"
OUT_PDF = OUT_DIR / "MaJo_Functionality_Test_Report.pdf"
RESULTS_JSON = OUT_DIR / "functionality_test_results.json"


FEATURES = [
    # role, module, description, implementation, cloud_dep
    ("Shared", "Login / roles", "Role-based sign-in (admin, teacher, parent, student, driver)", "Implemented", "Cloud login needs Blaze Functions"),
    ("Shared", "Forgot / change password", "OTP + password reset / forced change", "Implemented", "Real SMS needs Blaze Phone Auth"),
    ("Shared", "Localization", "EN / Amharic / Oromo strings", "Implemented", "None"),
    ("Shared", "Settings & app lock", "Preferences, background lock / web idle timeout", "Implemented", "None"),
    ("Shared", "Push notifications", "FCM token + local notifications", "Implemented", "FCM send via Functions needs Blaze"),
    ("Shared", "Messaging", "Conversations, attachments, voice", "Implemented", "Cloud sync needs auth claims"),
    ("Shared", "Announcements", "Create/view school announcements", "Implemented", "Cloud sync needs auth claims"),
    ("Shared", "Calendar / timetable", "Events and class timetables", "Implemented", "Cloud sync needs auth claims"),
    ("Teacher", "Classes", "My classes view", "Implemented", "Cloud sync"),
    ("Teacher", "Attendance", "Take / view attendance", "Implemented", "Cloud sync"),
    ("Teacher", "Homework", "Assign / manage homework", "Implemented", "Cloud sync"),
    ("Teacher", "Learning materials", "Share materials", "Implemented", "Storage may need Blaze"),
    ("Teacher", "Grades", "Enter grades / reports", "Implemented", "Cloud sync"),
    ("Teacher", "Gallery / QR", "Gallery posts and QR tools", "Implemented", "Camera device"),
    ("Parent", "Children", "Linked children overview", "Implemented", "Cloud sync"),
    ("Parent", "Fees", "Fee view / payment UX (provider pending)", "Partial", "Online payments not live"),
    ("Parent", "Bus tracking", "Live bus / transport status", "Implemented", "Cloud sync + location"),
    ("Parent", "Parent signup / approvals", "Register + admin approval flow", "Implemented", "Register callable needs Blaze"),
    ("Student", "Portal", "Grades, homework, materials, attendance", "Implemented", "Portal flags / cloud"),
    ("Admin", "Students / teachers / staff", "CRUD registries", "Implemented", "Cloud sync"),
    ("Admin", "Finance", "Fees / finance dashboard", "Implemented", "Cloud sync"),
    ("Admin", "Transport admin", "Routes, drivers, scans", "Implemented", "Cloud sync"),
    ("Admin", "Grade approvals", "Workflow queue", "Implemented", "Cloud sync"),
    ("Admin", "Inventory", "Stock / assets web module", "Implemented", "Storage rules + Blaze for bucket"),
    ("Admin", "Web ERP shell", "Sidebar ERP for web admin", "Implemented", "Same Flutter web build"),
    ("Admin", "Institution / campus pages", "Org management entries", "Placeholder", "UI placeholders only"),
    ("Admin", "Library", "Library module", "Partial / placeholder-risk", "Check live UI"),
    ("Driver", "Route / passengers", "Assigned route and passenger list", "Implemented", "Cloud sync"),
    ("Driver", "QR scan / pickup", "Transport scanning", "Implemented", "Camera device"),
    ("Driver", "Live map share", "GPS publish for parents", "Implemented", "Location + cloud"),
    ("Platform", "Owner console", "Hidden PIN console for schools", "Implemented", "Device-local PIN"),
    ("Platform", "Audit / system health", "Audit log and health views", "Implemented", "Cloud sync"),
]


def run_tests() -> dict:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        "flutter",
        "test",
        "test/functionality_suite_test.dart",
        "test/database_test.dart",
        "--reporter",
        "json",
    ]
    proc = subprocess.run(
        cmd,
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    cases: list[dict] = []
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == "testDone":
            result = ev.get("result", "error")
            # pair with previous testStart via id
            cases.append(
                {
                    "id": ev.get("testID"),
                    "result": result,
                    "hidden": ev.get("hidden", False),
                    "time": ev.get("time"),
                }
            )
        elif ev.get("type") == "testStart":
            test = ev.get("test") or {}
            cases.append(
                {
                    "type": "start",
                    "id": test.get("id"),
                    "name": test.get("name", "unknown"),
                    "url": test.get("url"),
                }
            )

    # Merge start names with done results
    starts = {c["id"]: c for c in cases if c.get("type") == "start"}
    dones = [c for c in cases if "result" in c and c.get("type") != "start"]
    merged = []
    for d in dones:
        if d.get("hidden"):
            continue
        st = starts.get(d["id"], {})
        name = st.get("name", f"test#{d['id']}")
        if name.startswith("loading ") or "(setUpAll)" in name or "(tearDownAll)" in name:
            continue
        merged.append(
            {
                "name": name,
                "result": d.get("result", "error"),
                "file": st.get("url") or "",
            }
        )

    summary = {
        "exit_code": proc.returncode,
        "total": len(merged),
        "passed": sum(1 for m in merged if m["result"] == "success"),
        "failed": sum(1 for m in merged if m["result"] != "success"),
        "cases": merged,
        "stderr_tail": (proc.stderr or "")[-2000:],
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }
    RESULTS_JSON.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary


def styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "title",
            parent=base["Heading1"],
            fontSize=18,
            alignment=TA_CENTER,
            spaceAfter=8,
        ),
        "h2": ParagraphStyle(
            "h2", parent=base["Heading2"], fontSize=13, spaceBefore=14, spaceAfter=6
        ),
        "h3": ParagraphStyle(
            "h3", parent=base["Heading3"], fontSize=11, spaceBefore=10, spaceAfter=4
        ),
        "body": ParagraphStyle(
            "body", parent=base["BodyText"], fontSize=9, leading=12, alignment=TA_LEFT
        ),
        "small": ParagraphStyle(
            "small", parent=base["BodyText"], fontSize=8, leading=10, textColor=colors.grey
        ),
        "cell": ParagraphStyle("cell", parent=base["BodyText"], fontSize=7.5, leading=9),
    }


def table(data, col_widths):
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0F766E")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 7.5),
                ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#CBD5E1")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FAFC")]),
            ]
        )
    )
    return t


def build_pdf(summary: dict) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    s = styles()
    doc = SimpleDocTemplate(
        str(OUT_PDF),
        pagesize=A4,
        leftMargin=14 * mm,
        rightMargin=14 * mm,
        topMargin=14 * mm,
        bottomMargin=14 * mm,
        title="MaJo e-School Bridge — Functionality & Test Report",
    )
    story = []
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    story.append(Paragraph("MaJo e-School Bridge", s["title"]))
    story.append(Paragraph("Functionality Report & Actual Test Results", s["title"]))
    story.append(
        Paragraph(
            f"Generated {now} · Project: eduaba · Flutter Android + Web ERP · Firebase: majo-e-school-bridge",
            s["small"],
        )
    )
    story.append(Spacer(1, 8))

    story.append(Paragraph("1. Executive summary", s["h2"]))
    passed = summary["passed"]
    failed = summary["failed"]
    total = summary["total"]
    rate = (100.0 * passed / total) if total else 0.0
    story.append(
        Paragraph(
            f"Automated functionality suite executed <b>{total}</b> tests: "
            f"<b>{passed} passed</b>, <b>{failed} failed</b> "
            f"({rate:.0f}% pass). "
            "Cloud-dependent features (server login, SMS OTP, Storage bucket, FCM fan-out) "
            "are implemented in code but <b>blocked on Firebase Blaze / deployment</b> for live multi-device use.",
            s["body"],
        )
    )

    story.append(Paragraph("2. Product surfaces", s["h2"]))
    story.append(
        Paragraph(
            "<b>Android app</b> — role dashboards for teacher, parent, student, admin, driver.<br/>"
            "<b>Web ERP</b> — Flutter web admin shell (<font face='Courier'>lib/web_erp</font>).<br/>"
            "<b>Backend</b> — Firestore, Storage, Cloud Functions (schoolLogin, FCM), Hosting.",
            s["body"],
        )
    )

    story.append(Paragraph("3. Functionality inventory", s["h2"]))
    story.append(
        Paragraph(
            "Status meanings: <b>Implemented</b> = code present and wired; "
            "<b>Partial</b> = UI/flow exists with known gaps; "
            "<b>Placeholder</b> = nav entry without full module.",
            s["small"],
        )
    )
    feat_rows = [
        [
            Paragraph("<b>Role</b>", s["cell"]),
            Paragraph("<b>Module</b>", s["cell"]),
            Paragraph("<b>Description</b>", s["cell"]),
            Paragraph("<b>Status</b>", s["cell"]),
            Paragraph("<b>Notes / deps</b>", s["cell"]),
        ]
    ]
    for role, module, desc, status, notes in FEATURES:
        feat_rows.append(
            [
                Paragraph(role, s["cell"]),
                Paragraph(module, s["cell"]),
                Paragraph(desc, s["cell"]),
                Paragraph(status, s["cell"]),
                Paragraph(notes, s["cell"]),
            ]
        )
    story.append(table(feat_rows, [22 * mm, 32 * mm, 55 * mm, 25 * mm, 46 * mm]))

    story.append(PageBreak())
    story.append(Paragraph("4. Actual automated test report", s["h2"]))
    story.append(
        Paragraph(
            "Command: <font face='Courier'>flutter test test/functionality_suite_test.dart "
            "test/database_test.dart</font><br/>"
            f"Exit code: <b>{summary['exit_code']}</b> · "
            f"Pass rate: <b>{rate:.0f}%</b>",
            s["body"],
        )
    )

    test_rows = [
        [
            Paragraph("<b>#</b>", s["cell"]),
            Paragraph("<b>Result</b>", s["cell"]),
            Paragraph("<b>Test case</b>", s["cell"]),
        ]
    ]
    for i, case in enumerate(summary["cases"], 1):
        result = case["result"]
        label = "PASS" if result == "success" else "FAIL"
        color = "#166534" if result == "success" else "#991B1B"
        test_rows.append(
            [
                Paragraph(str(i), s["cell"]),
                Paragraph(f'<font color="{color}"><b>{label}</b></font>', s["cell"]),
                Paragraph(case["name"].replace("<", "&lt;"), s["cell"]),
            ]
        )
    story.append(table(test_rows, [12 * mm, 20 * mm, 148 * mm]))

    story.append(Paragraph("5. Manual / environment checks (not auto-run)", s["h2"]))
    manual = [
        ["Check", "Result", "Reason"],
        [
            "Cloud schoolLogin on device/web",
            "BLOCKED",
            "Requires Blaze + deployed Cloud Functions",
        ],
        [
            "Firebase Phone SMS OTP (release)",
            "BLOCKED",
            "Requires Blaze + Phone Auth Console setup",
        ],
        [
            "Cross-device Firestore sync",
            "BLOCKED",
            "Needs custom-token session from Functions",
        ],
        [
            "Storage upload/download",
            "BLOCKED / PENDING",
            "Bucket/billing + deploy storage.rules",
        ],
        [
            "Maps on web",
            "PENDING CONFIG",
            "Set web/maps_api_key.js and restrict key",
        ],
        [
            "Play Store release signing",
            "PENDING CONFIG",
            "Create android/key.properties + keystore",
        ],
        [
            "Legacy widget_test.dart Login screen",
            "FAIL (known)",
            "Needs Firebase.initializeApp mock; excluded from suite pass rate",
        ],
    ]
    man_rows = [
        [
            Paragraph(f"<b>{a}</b>" if i == 0 else a, s["cell"])
            for a in row
        ]
        for i, row in enumerate(manual)
    ]
    # rebuild properly
    man_rows = []
    for i, row in enumerate(manual):
        if i == 0:
            man_rows.append([Paragraph(f"<b>{c}</b>", s["cell"]) for c in row])
        else:
            man_rows.append([Paragraph(c, s["cell"]) for c in row])
    story.append(table(man_rows, [55 * mm, 30 * mm, 95 * mm]))

    story.append(Paragraph("6. Role coverage matrix (local/debug)", s["h2"]))
    matrix = [
        ["Capability", "Admin", "Teacher", "Parent", "Student", "Driver"],
        ["Local debug login", "Yes", "Yes", "Yes", "Seeded", "Yes"],
        ["Messages", "Yes", "Yes", "Yes", "Yes", "Yes"],
        ["Attendance", "Yes", "Yes", "View", "View", "Transport"],
        ["Grades", "Approve", "Enter", "View", "View", "—"],
        ["Fees", "Manage", "—", "View*", "—", "—"],
        ["Transport / bus", "Manage", "—", "Track", "—", "Operate"],
        ["Inventory (web)", "Yes", "—", "—", "—", "—"],
        ["Cloud (Spark today)", "No", "No", "No", "No", "No"],
    ]
    mat_rows = []
    for i, row in enumerate(matrix):
        if i == 0:
            mat_rows.append([Paragraph(f"<b>{c}</b>", s["cell"]) for c in row])
        else:
            mat_rows.append([Paragraph(c, s["cell"]) for c in row])
    story.append(table(mat_rows, [40 * mm, 24 * mm, 24 * mm, 24 * mm, 24 * mm, 24 * mm]))
    story.append(
        Paragraph(
            "* Parent fee online payment providers are not live (UI / coming soon messaging present).",
            s["small"],
        )
    )

    story.append(Paragraph("7. Recommendations", s["h2"]))
    story.append(
        Paragraph(
            "1. Keep using local/debug for feature QA until Blaze.<br/>"
            "2. Deploy Firestore + Storage rules on Spark now.<br/>"
            "3. After Blaze: deploy Functions, bootstrap admin, re-run this suite + manual cloud login on phone and web.<br/>"
            "4. Fix or mock Firebase in <font face='Courier'>test/widget_test.dart</font> so CI stays green.<br/>"
            "5. Add integration tests (patrol/integration_test) for dashboards once cloud auth is live.",
            s["body"],
        )
    )

    story.append(Spacer(1, 12))
    story.append(
        Paragraph(
            f"Raw results JSON: reports/functionality_test_results.json · PDF: {OUT_PDF.name}",
            s["small"],
        )
    )

    doc.build(story)
    return OUT_PDF


def main():
    print("Running functionality tests...")
    summary = run_tests()
    print(
        f"Tests: {summary['passed']}/{summary['total']} passed "
        f"(exit {summary['exit_code']})"
    )
    pdf = build_pdf(summary)
    print(f"PDF written: {pdf}")
    return 0 if summary["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

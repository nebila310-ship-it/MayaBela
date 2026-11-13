#!/usr/bin/env python3
"""A4 PDF: page-by-page Rev 1.1 → Rev 1.2 check sheet for MBT-LIA-AGR-2026-01."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

try:
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import (
        KeepTogether,
        ListFlowable,
        ListItem,
        Paragraph,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    )
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "reportlab"])
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import (
        KeepTogether,
        ListFlowable,
        ListItem,
        Paragraph,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    )

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/agreements/MBT-LIA-AGR-2026-01_Rev1.2_page_by_page_check.pdf"
NAVY = colors.HexColor("#142033")
GOLD = colors.HexColor("#C4A35A")
USED = colors.HexColor("#F4E6E4")
NOW = colors.HexColor("#E6F0E8")
PALE = colors.HexColor("#F4F7FB")
LINE = colors.HexColor("#C5D0DC")
USED_INK = colors.HexColor("#7A2E24")
NOW_INK = colors.HexColor("#1B5E37")


def styles():
    base = getSampleStyleSheet()
    s = {
        "cover": ParagraphStyle(
            "cover",
            parent=base["Normal"],
            fontName="Times-Bold",
            fontSize=16,
            leading=20,
            textColor=NAVY,
            alignment=TA_CENTER,
            spaceAfter=4,
        ),
        "sub": ParagraphStyle(
            "sub",
            parent=base["Normal"],
            fontName="Times-Italic",
            fontSize=10,
            leading=13,
            textColor=NAVY,
            alignment=TA_CENTER,
            spaceAfter=2,
        ),
        "meta": ParagraphStyle(
            "meta",
            parent=base["Normal"],
            fontName="Times-Roman",
            fontSize=9,
            leading=12,
            textColor=NAVY,
            alignment=TA_CENTER,
            spaceAfter=8,
        ),
        "h": ParagraphStyle(
            "h",
            parent=base["Normal"],
            fontName="Times-Bold",
            fontSize=11.5,
            leading=14,
            textColor=NAVY,
            spaceBefore=10,
            spaceAfter=4,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["Normal"],
            fontName="Times-Roman",
            fontSize=9.5,
            leading=12.5,
            textColor=NAVY,
            alignment=TA_JUSTIFY,
            spaceAfter=4,
        ),
        "note": ParagraphStyle(
            "note",
            parent=base["Normal"],
            fontName="Times-Italic",
            fontSize=8.5,
            leading=11,
            textColor=colors.HexColor("#334155"),
            spaceAfter=6,
        ),
        "cell": ParagraphStyle(
            "cell",
            parent=base["Normal"],
            fontName="Times-Roman",
            fontSize=8.4,
            leading=11,
            textColor=NAVY,
        ),
        "cellb": ParagraphStyle(
            "cellb",
            parent=base["Normal"],
            fontName="Times-Bold",
            fontSize=8.4,
            leading=11,
            textColor=NAVY,
        ),
        "used": ParagraphStyle(
            "used",
            parent=base["Normal"],
            fontName="Times-Roman",
            fontSize=8.6,
            leading=11.4,
            textColor=USED_INK,
        ),
        "now": ParagraphStyle(
            "now",
            parent=base["Normal"],
            fontName="Times-Roman",
            fontSize=8.6,
            leading=11.4,
            textColor=NOW_INK,
        ),
        "lab": ParagraphStyle(
            "lab",
            parent=base["Normal"],
            fontName="Times-Bold",
            fontSize=8,
            leading=10,
            textColor=NAVY,
        ),
        "foot": ParagraphStyle(
            "foot",
            parent=base["Normal"],
            fontName="Times-Roman",
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#475569"),
            alignment=TA_CENTER,
        ),
    }
    return s


def pair(s, loc: str, used: str, now: str) -> KeepTogether:
    loc_p = Paragraph(loc, s["h"])
    data = [
        [
            Paragraph("USED TO SAY — Revision 1.1", s["lab"]),
            Paragraph("NOW SAYS — Revision 1.2", s["lab"]),
        ],
        [Paragraph(used, s["used"]), Paragraph(now, s["now"])],
    ]
    t = Table(data, colWidths=[88 * mm, 88 * mm])
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, 0), colors.HexColor("#E8C9C4")),
                ("BACKGROUND", (1, 0), (1, 0), colors.HexColor("#C9DFD0")),
                ("BACKGROUND", (0, 1), (0, 1), USED),
                ("BACKGROUND", (1, 1), (1, 1), NOW),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, 0), 4),
                ("BOTTOMPADDING", (0, 0), (-1, 0), 4),
                ("TOPPADDING", (0, 1), (-1, 1), 6),
                ("BOTTOMPADDING", (0, 1), (-1, 1), 7),
                ("BOX", (0, 0), (-1, -1), 0.4, LINE),
                ("LINEAFTER", (0, 0), (0, -1), 0.4, LINE),
                ("LINEBELOW", (0, 0), (-1, 0), 0.4, LINE),
            ]
        )
    )
    return KeepTogether([loc_p, t, Spacer(1, 3 * mm)])


def grid(s, headers, rows) -> Table:
    head = [Paragraph(h, s["cellb"]) for h in headers]
    body = [[Paragraph(c, s["cell"]) for c in r] for r in rows]
    n = len(headers)
    if n == 3:
        widths = [28 * mm, 74 * mm, 74 * mm]
    else:
        widths = [22 * mm, 52 * mm, 51 * mm, 51 * mm]
    t = Table([head] + body, colWidths=widths, repeatRows=1)
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), PALE),
                ("FONTNAME", (0, 0), (-1, 0), "Times-Bold"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("GRID", (0, 0), (-1, -1), 0.35, LINE),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("BACKGROUND", (1, 1), (1, -1), USED),
                ("BACKGROUND", (2, 1), (2, -1), NOW),
            ]
        )
    )
    return t


def header_footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(NAVY)
    canvas.rect(0, A4[1] - 12 * mm, A4[0], 12 * mm, fill=1, stroke=0)
    canvas.setFillColor(GOLD)
    canvas.rect(0, A4[1] - 12.8 * mm, A4[0], 1.2 * mm, fill=1, stroke=0)
    canvas.setFillColor(colors.white)
    canvas.setFont("Times-Bold", 8)
    canvas.drawString(
        16 * mm,
        A4[1] - 8 * mm,
        "MBT-LIA-AGR-2026-01  ·  Revision 1.2 page-by-page check  ·  13 November 2026",
    )
    canvas.setFillColor(NAVY)
    canvas.rect(0, 0, A4[0], 10 * mm, fill=1, stroke=0)
    canvas.setFillColor(GOLD)
    canvas.rect(0, 10 * mm, A4[0], 0.8 * mm, fill=1, stroke=0)
    canvas.setFillColor(colors.white)
    canvas.setFont("Times-Roman", 8)
    canvas.drawString(16 * mm, 4 * mm, "Lebawi International Academy  ·  MaJo Bridge Technologies")
    canvas.drawRightString(A4[0] - 16 * mm, 4 * mm, f"Page {doc.page}")
    canvas.restoreState()


def build():
    s = styles()
    story = []
    story.append(Paragraph("SOFTWARE LICENCE AND IMPLEMENTATION AGREEMENT", s["cover"]))
    story.append(Paragraph("Page-by-page check: Revision 1.1 → Revision 1.2", s["cover"]))
    story.append(Paragraph("MBT-LIA-AGR-2026-01  ·  Lebawi International Academy and MaJo Bridge Technologies and Events PLC", s["sub"]))
    story.append(
        Paragraph(
            "Printed from the Word files on 13 November 2026 G.C.  ·  Rev. 1.1 is 28 pages  ·  Rev. 1.2 is 31 pages",
            s["meta"],
        )
    )
    story.append(
        Paragraph(
            "Open <b>Revision 1.1</b> and <b>Revision 1.2</b> side by side. For each block below, go to the stated page, "
            "read the old wording (left, pink) and confirm the new wording (right, green). "
            "Google Docs can sit one page off if you pasted into the old Drive file — if a page does not match, "
            "search the Article or Annex number. Page numbers below are from the Word PDFs.",
            s["body"],
        )
    )
    story.append(
        Paragraph(
            "Every page header used to say <b>Rev. 1.1 (10 Nov 2026)</b> and now says <b>Rev. 1.2 (13 Nov 2026)</b>. "
            "Contract Price 4,456,250 ETB VAT inclusive and the 40 / 40 / 20 split are unchanged.",
            s["note"],
        )
    )

    story.append(pair(
        s,
        "Page 1 — cover title (this is why Google Docs still looked like 1.1)",
        "SOFTWARE LICENCE AND IMPLEMENTATION AGREEMENT",
        "SOFTWARE LICENCE AND IMPLEMENTATION AGREEMENT — REVISION 1.2<br/><br/>"
        "New line under the title: Revision 1.2 · 13 November 2026 G.C. · supersedes Revision 1.1 · MBT-LIA-AGR-2026-01",
    ))
    story.append(pair(
        s,
        "Page 1 — cover table, Agreement reference",
        "MBT-LIA-AGR-2026-01",
        "MBT-LIA-AGR-2026-01 · Revision 1.2 (13 November 2026)",
    ))
    story.append(pair(
        s,
        "Page 1 — cover table, Annexes row",
        "A Module list and prices · B Deliverables and milestones · C Payment schedule · … · "
        "J LIA Revised TOR — 49 Included Modules (October 2026)",
        "Annex Register (signed) · A Module list and prices · B Deliverables, milestones and TOR crosswalk (D1–D12) · "
        "… · J LIA Revised TOR Version 1.0, October 2026 (21 pages, 23 sections + Appendices A and B)",
    ))
    story.append(pair(
        s,
        "Page 2 — revision banner (after “THIS AGREEMENT”)",
        "This Revision 1.1 of 10 November 2026 G.C. incorporates the Client's Revised Terms of Reference, "
        "“Implementation, Configuration, Integration, Deployment and Support of the MaJo e-School Bridge Platform — "
        "Revised Scope: 49 Included Modules” (October 2026), attached as Annex J. Commercial terms (price, payment, "
        "licence, liability) are unchanged from Revision 1.0. Functional and technical acceptance follow Annex J.",
        "This Revision 1.2 of 13 November 2026 G.C. amends Revision 1.1 so that Annex J (the complete Revised TOR, "
        "Version 1.0, October 2026, twenty-one (21) pages, twenty-three (23) sections and Appendices A and B) is the "
        "functional and technical baseline. The Inception Report may add implementation detail but shall not reduce "
        "or override Annex J unless the Client approves a formal change order under Article 15. Commercial terms "
        "(Contract Price, VAT, payment amounts and timing) remain unchanged from Revision 1.0: 4,456,250 ETB VAT "
        "inclusive, 40/40/20.",
    ))
    story.append(pair(
        s,
        "Page 3 — Article 1.1(d) “Inception Report”",
        "“Inception Report” means document MBT-LIA-INC-2026-01, Version 1.0 of 27 October 2026, attached as Annex E, "
        "as finalised and accepted under Milestone M2, and any later revision signed by both Parties.",
        "Same opening sentence, then added: The Inception Report may provide implementation detail (schedule, rooms, "
        "named owners, templates) but shall not reduce, replace, or override any requirement of Annex J, including "
        "Sections 14 and 17 and Appendix B, unless the Client approves a formal change order under Article 15.",
    ))
    story.append(pair(
        s,
        "Page 3 — Article 1.1(g-bis) “Revised TOR” / Annex J",
        "the Client's document “Revised Terms of Reference — MaJo e-School Bridge (49 Modules)”, Version 1.0, "
        "October 2026, including Appendix A (module register) and Appendix B (minimum UAT checklist).",
        "the complete document titled “Revised Terms of Reference — MaJo e-School Bridge (49 Modules)”, also headed "
        "“TERMS OF REFERENCE — Implementation, Configuration, Integration, Deployment and Support of the MaJo "
        "e-School Bridge Platform — Revised Scope: 49 Included Modules”, Version 1.0, October 2026, comprising "
        "twenty-three (23) sections and Appendices A and B, twenty-one (21) pages in the PDF execution copy attached "
        "hereto and initialled on every page by both Parties. No later or different version applies unless signed by both Parties.",
    ))
    story.append(pair(
        s,
        "Page 4 in Rev 1.2 (was page 3) — Article 1.1(i) “Deliverable”",
        "the items listed in Annex B, as detailed in Sections 7 and 8 of the Inception Report.",
        "the items listed in Annex B. Annex B is a crosswalk that preserves every TOR deliverable D1 to D12 in Annex J, "
        "Section 13, without reducing the minimum contents stated there. Where this Agreement previously used a different "
        "number (former D6 training, former D8 pilot, former D10 Go-Live Certificate, former D11 combined handover), "
        "the TOR number and contents control.",
    ))
    story.append(pair(
        s,
        "Page 4 in Rev 1.2 (was page 3) — Article 1.1(j) “Go-Live”",
        "…and the Go-Live Certificate (Deliverable D10) is signed, targeted for Monday 21 December 2026.",
        "…and the Go-Live Certificate (an instrument in Deliverable D9) is signed, targeted for Monday 21 December 2026. "
        "Deliverable D10 is Training and user documentation.",
    ))
    story.append(pair(
        s,
        "Page 4 in Rev 1.2 (was page 3) — Article 1.1(k) “User-Acceptance Testing”",
        "the scripted scenarios in Section 13 of the Inception Report, run by the Client's officers on the Client's own data.",
        "the tests and acceptance activities required by this Agreement, Annex J (including Sections 14 and 17 and "
        "Appendix B), and the approved test plan. The Inception Report may provide implementation detail (including "
        "the scripted scenarios in its Section 13) but shall not reduce or override the requirements of Annex J.",
    ))
    story.append(pair(
        s,
        "Pages 4–5 — Article 2.1(k) Annex J identification",
        "Annex J — LIA Revised TOR, 49 Included Modules (October 2026), including Appendix A and Appendix B.",
        "Annex J — the complete document titled “Revised Terms of Reference — MaJo e-School Bridge (49 Modules)”, "
        "Version 1.0, October 2026, comprising twenty-three (23) sections and Appendices A and B, twenty-one (21) pages, "
        "including the complete 49-module register (Appendix A) and the minimum UAT checklist (Appendix B). No later "
        "or different version applies unless signed by both Parties.",
    ))
    story.append(pair(
        s,
        "Page 5 — Article 2.1(l) Annex Register (NEW)",
        "This clause did not exist in Revision 1.1.",
        "(l) Annex Register — the signed schedule in Article 2.4 listing each annex title, version or date, page count, "
        "and initials of both Parties.",
    ))
    story.append(pair(
        s,
        "Page 5 — Article 2.2 order of precedence (Comment 3)",
        "In the event of conflict: (1) Articles 4 and 5 as to Contract Price and payment; (2) the remaining Articles; "
        "(3) Annex J as to functional and technical acceptance scope, exclusions, hybrid data placement, testing, and "
        "handover; (4) Annexes A to D and I; (5) Annex E (Inception Report); (6) Annexes F to H. Articles 4 and 5 "
        "prevail over any amount in Annexes E to H and Annex J.",
        "For functional and technical scope, the 49 included modules, exclusions, integrations, security, data placement, "
        "NFR, testing, acceptance, deliverables, training and handover, Annex J shall prevail over any inconsistent "
        "provision in the Agreement or other annex. Articles 4 and 5 shall prevail only for Contract Price, VAT and "
        "payment amounts/timing, provided payment triggers remain conditional on acceptance. Articles 8.1(f), 10.1, "
        "10.2 and 10.6 shall not reduce Annex J Sections 14 or 17 or Appendix B.",
    ))
    story.append(pair(
        s,
        "Pages 5–6 — Article 2.4 Annex Register table (NEW)",
        "This clause and table did not exist in Revision 1.1.",
        "Each annex is part of the Agreement only in the complete final version attached and initialled. The table records "
        "title, version/date, page count, LIA initials and MaJo initials. If an annex is not attached and authenticated "
        "at signature, it creates no additional obligation or charge until signed. Annex J is listed as 21 pages. "
        "Annexes E and F must be consistent with Annex J. Annexes G and H shall not introduce unapproved recurring charges.",
    ))
    story.append(pair(
        s,
        "Page 6 — Article 2.5 (NEW)",
        "This clause did not exist in Revision 1.1.",
        "Milestone M2 (acceptance of the Inception Report and the Requirements and Customization Registers) does not "
        "authorise any reduction of Annex J. A requirement of Annex J, including Section 14, Section 17, Appendix A or "
        "Appendix B, is varied only by a written change order signed under Article 15.",
    ))

    story.append(Paragraph("Page 7 — Article 3.1 (was page 5 in Revision 1.1)", s["h"]))
    story.append(Paragraph("Deliverable numbers are aligned to TOR D1–D12.", s["note"]))
    story.append(grid(
        s,
        ["Clause", "Used to say (Rev 1.1 p5)", "Now says (Rev 1.2 p7)"],
        [
            ["(f)", "training sessions and in-app manuals = <b>Deliverable D6</b>", "Integration Specification and Test Evidence = <b>D6</b>; training and user documentation = <b>D10</b>"],
            ["(g)", "backup restore drill and security check of both nodes = D7", "Security and access-control pack, including restore drill and security check = D7"],
            ["(h)", "two-week pilot in one section and report = <b>D8</b>", "Testing Package (plan, cases, evidence, defect register) = <b>D8</b>; the two-week pilot is supporting evidence"],
            ["(i)", "UAT, fix defects, obtain the acceptance certificate = D9", "UAT under Annex J ss. 14 and 17 and Appendix B; UAT and go-live sign-off pack including Go-Live Certificate = <b>D9</b>"],
            ["(j)", "bring all sections live and issue the Go-Live Certificate = <b>D10</b>", "bring all sections live on the agreed Go-Live date as part of <b>D9</b>"],
            ["(k)", "hypercare and hand over the operations handbook = D11", "hypercare and Operations and support handover = <b>D11</b>"],
            ["(k-bis)", "did not exist", "Final Handover and Acceptance Report = <b>D12</b>, separate from Go-Live approval"],
        ],
    ))
    story.append(Spacer(1, 4 * mm))

    story.append(pair(
        s,
        "Page 9 — Article 5.1 payment table, second instalment (was page 7)  ·  amounts unchanged",
        "Supporting document: UAT readiness notice; Deliverables D3 to D8 accepted or deemed accepted; VAT invoice. "
        "Amount still 1,782,500 ETB (40%).",
        "Supporting document: UAT readiness notice; Deliverables D3, D4, D5, D6, D7, D8 and D10 accepted in writing; "
        "VAT invoice. Amount still 1,782,500 ETB (40%).",
    ))
    story.append(pair(
        s,
        "Page 9 — Article 5.1 payment table, third instalment (was page 7)  ·  amounts unchanged",
        "Supporting document: Signed Go-Live Certificate (D10); VAT invoice. Amount still 891,250 ETB (20%).",
        "Supporting document: Signed Go-Live Certificate forming part of Deliverable D9; VAT invoice. Final acceptance "
        "(D12) is separate and does not delay this instalment once D9 Go-Live is signed. Amount still 891,250 ETB (20%).",
    ))
    story.append(pair(
        s,
        "Page 10 — Article 7.1(a) (was page 8)",
        "perform the services … in accordance with the Inception Report;",
        "perform the services … in accordance with this Agreement and Annex J; the Inception Report supplies "
        "implementation detail only and does not reduce Annex J;",
    ))
    story.append(pair(
        s,
        "Page 12 — Article 8.1(f) five-day silence (was page 9)",
        "review each Deliverable within five (5) Working Days and give written comments or acceptance; silence after "
        "five (5) Working Days is treated as acceptance;",
        "review each Deliverable within five (5) Working Days … Silence after five (5) Working Days may be treated as "
        "acceptance of ordinary transmittals other than Deliverables D8, D9, D11 and D12. Silence does not constitute "
        "passed UAT, Go-Live approval, or final acceptance under Annex J Sections 14 and 17. Those four instruments "
        "require a dated written signature (or a dated written statement of defects).",
    ))
    story.append(pair(
        s,
        "Page 14 — Article 10.1 (was page 11)",
        "…silence after five (5) Working Days is treated as acceptance.",
        "…Silence after five (5) Working Days may be treated as acceptance only as limited by Article 8.1(f). UAT, "
        "Go-Live and final acceptance remain governed by Annex J Sections 14 and 17 and by Deliverables D8, D9 and D12.",
    ))
    story.append(pair(
        s,
        "Page 14 — Article 10.2 (was page 11)",
        "The second instalment becomes due when the Service Provider issues the UAT readiness notice … after Milestone M5.",
        "…after Milestone M5, and when Deliverables D3, D4, D5, D6, D7, D8 and D10 have been accepted in writing "
        "(not merely by silence). Payment of that instalment does not waive Annex J testing or acceptance still to be "
        "performed under D9 and D12.",
    ))
    story.append(pair(
        s,
        "Page 14 — Article 10.3 UAT (was page 11)",
        "UAT is run … using the scenarios in Section 13 of the Inception Report and the minimum checklist in Annex J, Appendix B…",
        "UAT is run … using Annex J Section 14, Annex J Section 17, Annex J Appendix B, and the approved test plan… "
        "Scenarios in Section 13 of the Inception Report may be used as additional scripts; they do not replace the TOR checklist.",
    ))
    story.append(pair(
        s,
        "Pages 14–15 — Article 10.4 Go-Live criteria (was page 12)",
        "On fulfilment, the Client signs the acceptance certificate (D9) and, on the agreed Go-Live date, the Go-Live "
        "Certificate (D10). Go-Live approval and final handover (D11) are separate…",
        "On fulfilment of the UAT/go-live conditions, the Client signs Deliverable D9 (UAT and go-live sign-off pack, "
        "including the Go-Live Certificate). Final written acceptance is Deliverable D12 and is separate from Go-Live.",
    ))
    story.append(pair(
        s,
        "Pages 14–15 — Article 10.6 fifteen-day rule (was page 12)",
        "Use of the System in production by the Client for fifteen (15) consecutive Working Days without a written "
        "notice of non-acceptance constitutes acceptance.",
        "Use of the System in production by the Client, including use for fifteen (15) consecutive Working Days, does "
        "not of itself constitute UAT pass, Go-Live approval, or final acceptance. Those events require the written "
        "instruments in Deliverables D9 and D12 and the criteria in Annex J Sections 14 and 17.",
    ))
    story.append(pair(
        s,
        "Page 15 — Article 12.1 warranty (was page 13)",
        "…the System shall perform materially in accordance with the Inception Report, the Requirements Register, and "
        "the Customization Register…",
        "…the System shall perform materially in accordance with Annex J, the Requirements Register, and the "
        "Customization Register… The Inception Report does not narrow this warranty.",
    ))
    story.append(pair(
        s,
        "Page 18 — Article 15.1 baseline (was page 15)",
        "The Requirements Register and the Customization Register signed under Milestone M2 are the baseline. Any "
        "change requested after that date is recorded in the issue log…",
        "Annex J is the functional and technical baseline. The Requirements Register and the Customization Register "
        "signed under Milestone M2, and the Inception Report as accepted under M2, are implementation instruments under "
        "that baseline. Any change that would reduce or replace a requirement of Annex J … is implemented only after "
        "a written variation order (change order)…",
    ))
    story.append(pair(
        s,
        "Page 18 — Article 15.4 (NEW)",
        "This clause did not exist in Revision 1.1.",
        "The M2 Inception Report must not reduce or replace any requirement in the signed TOR (Annex J) unless the "
        "Client approves a formal change order under this Article 15. Product updates, e-mail, or demonstration do not "
        "amend Annex J.",
    ))

    story.append(Paragraph("Pages 26–27 — Annex B (was pages 24–25)", s["h"]))
    story.append(Paragraph(
        "Title used to say <b>ANNEX B — DELIVERABLES AND MILESTONES</b> / “As set out in Sections 7 and 8 of the Inception Report.” "
        "Now says <b>ANNEX B — DELIVERABLES, MILESTONES AND TOR D1–D12 CROSSWALK</b>. TOR contents are the minimum.",
        s["note"],
    ))
    story.append(grid(
        s,
        ["TOR ID", "Used to say in Rev 1.1", "Now says in Rev 1.2"],
        [
            ["D6", "Training delivered (sessions, attendance, in-app manuals)", "<b>Integration specification and test evidence</b>"],
            ["D8", "Pilot report (two weeks, one section)", "<b>Testing package</b> (pilot is supporting evidence, not a substitute)"],
            ["D9", "UAT report and acceptance certificate", "<b>UAT and go-live sign-off pack</b> (includes the Go-Live Certificate)"],
            ["D10", "<b>Go-live certificate</b> — all sections live", "<b>Training and user documentation</b> (this was old D6)"],
            ["D11", "Hypercare closure, operations handover <b>and final acceptance</b>", "<b>Operations and support handover only</b>"],
            ["D12", "Missing as a separate instrument (was mixed into D11)", "<b>Final handover and acceptance report</b> — separate from Go-Live"],
        ],
    ))
    story.append(Spacer(1, 4 * mm))

    story.append(pair(
        s,
        "Page 28 — Annex C payment schedule (was page 26)  ·  amounts unchanged",
        "Second trigger: UAT readiness notice after Milestone M5.<br/>Third trigger: Go-Live Certificate, Milestone M7.",
        "Second trigger: UAT readiness notice after Milestone M5; D3–D8 and D10 accepted in writing.<br/>"
        "Third trigger: Go-Live Certificate (instrument in D9), Milestone M7.",
    ))
    story.append(pair(
        s,
        "Page 29 — Annex E Inception Report (was page 27)",
        "The final version accepted under Milestone M2 replaces Version 1.0 for the purposes of this Agreement.",
        "The version accepted under Milestone M2 may update implementation detail. It shall not reduce or override "
        "Annex J, including Sections 14 and 17 and Appendix B, unless the Client approves a formal change order under Article 15.",
    ))
    story.append(pair(
        s,
        "Page 29 — Annex F Training Modules (was page 27)",
        "Document MBT-LIA-TRN-2026-01, Version 1.0 of 27 October 2026, seventeen (17) pages… Attached hereto.",
        "Same document, plus: Training content shall be consistent with Annex J Section 15 and Deliverable D10. "
        "Recorded in the Annex Register.",
    ))
    story.append(pair(
        s,
        "Page 30 — Annex G Financial Proposal (was page 27)",
        "Attached for the record of unit prices… Where it conflicts with Articles 4 and 5, this Agreement prevails.",
        "Same, plus: Annex G shall not introduce unapproved recurring charges, hosting retainers, SMS, payment-gateway, "
        "or other scope beyond this Agreement and Annex J.",
    ))
    story.append(pair(
        s,
        "Page 30 — Annex H Notice of Intent to Award (was page 27)",
        "Letter of the Procurement Department… Attached hereto.",
        "Same, plus: initialled and recorded in the Annex Register. It does not add modules, exclusions, or recurring "
        "charges beyond this Agreement and Annex J.",
    ))
    story.append(pair(
        s,
        "Page 31 — Annex J cover title (was page 28)",
        "ANNEX J — LIA REVISED TOR (49 INCLUDED MODULES)",
        "ANNEX J — REVISED TOR (VERSION 1.0, OCTOBER 2026, 21 PAGES)",
    ))
    story.append(pair(
        s,
        "Page 31 — Annex J inconsistency rule (was page 28)",
        "In case of inconsistency: this Agreement (especially Articles 4, 5, 11, 12 and 19) governs price, payment, "
        "licence, support hours already stated, and liability; Annex J governs the forty-nine (49) included Modules, "
        "the ten (10) exclusions, hybrid data placement, testing, and handover contents.",
        "In case of inconsistency: Annex J prevails for functional and technical scope, the 49 included modules, "
        "exclusions, integrations, security, data placement, non-functional requirements, testing, acceptance, "
        "deliverables, training and handover, as stated in Article 2.2. Articles 4 and 5 prevail only for Contract "
        "Price, VAT and payment amounts/timing, and only while payment triggers remain conditional on the acceptance "
        "requirements in this Agreement and Annex J.",
    ))

    story.append(Paragraph("What was not rewritten (header and page number only)", s["h"]))
    story.append(Paragraph(
        "Article 4 price table (3,425,000 + 500,000 − 50,000 + 15% VAT = <b>4,456,250 ETB</b>). "
        "Articles 6, 9, 11, 13, 14, 16 to 24. Annex A (the 49-module price list). Signature-block wording. "
        "Those pages moved later in the booklet only because Articles 1, 2 and Annex B grew.",
        s["body"],
    ))
    story.append(Paragraph(
        "Attach this check sheet to the execution pack only as a reading aid. It is not an annex and creates no obligation. "
        "The signed instruments are Revision 1.2 of the Agreement, the Annex Register, Annex B, and the 21-page TOR PDF.",
        s["note"],
    ))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=16 * mm,
        rightMargin=16 * mm,
        topMargin=18 * mm,
        bottomMargin=16 * mm,
        title="MBT-LIA-AGR-2026-01 Rev 1.2 page-by-page check",
        author="MaJo Bridge Technologies and Events PLC",
        subject="Revision 1.1 to Revision 1.2 — used to say / now says",
    )
    doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)
    print(f"Wrote {OUT} bytes {OUT.stat().st_size}")
    return OUT


if __name__ == "__main__":
    build()

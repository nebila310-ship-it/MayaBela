#!/usr/bin/env python3
"""Apply Revision 1.2 of MBT-LIA-AGR-2026-01: Annex J controls TOR scope, UAT, annex register, D1–D12 crosswalk."""
from __future__ import annotations

import shutil
from copy import deepcopy
from pathlib import Path

from docx import Document
from docx.oxml.ns import qn
from docx.shared import Pt, RGBColor
from docx.table import Table
from docx.text.paragraph import Paragraph

SRC = Path("/workspace/docs/agreements/MBT-LIA-AGR-2026-01_Rev1.1.docx")
OUT = Path("/workspace/docs/agreements/MBT-LIA-AGR-2026-01_Rev1.2.docx")

TOR_PAGES = 21  # PDF execution copy LIA_MaJo_Bridge_Revised_TOR_49_Modules.pdf


def para_by_prefix(doc: Document, prefix: str) -> Paragraph:
    for p in doc.paragraphs:
        if p.text.startswith(prefix):
            return p
    raise KeyError(prefix)


def set_text_keep_runs(p: Paragraph, text: str) -> None:
    if p.runs:
        p.runs[0].text = text
        for r in p.runs[1:]:
            r.text = ""
    else:
        p.add_run(text)


def insert_after(paragraph: Paragraph, text: str) -> Paragraph:
    new_p = deepcopy(paragraph._p)
    paragraph._p.addnext(new_p)
    new_para = Paragraph(new_p, paragraph._parent)
    set_text_keep_runs(new_para, text)
    return new_para


def set_cell(cell, text: str, *, bold: bool = False) -> None:
    p = cell.paragraphs[0]
    if not p.runs:
        run = p.add_run(text)
    else:
        p.runs[0].text = text
        for r in p.runs[1:]:
            r.text = ""
        run = p.runs[0]
    run.bold = bold
    run.font.size = Pt(8)
    run.font.color.rgb = RGBColor(0x14, 0x20, 0x33)
    for extra in cell.paragraphs[1:]:
        extra.clear()


def shade_header_row(row) -> None:
    for cell in row.cells:
        tc = cell._tc
        tcPr = tc.get_or_add_tcPr()
        shd = tcPr.find(qn("w:shd"))
        if shd is None:
            shd = tcPr.makeelement(qn("w:shd"), {})
            tcPr.append(shd)
        shd.set(qn("w:fill"), "E8EEF5")
        shd.set(qn("w:val"), "clear")


def insert_table_after(paragraph: Paragraph, doc: Document, rows: list[list[str]]) -> Table:
    table = doc.add_table(rows=len(rows), cols=len(rows[0]))
    table.style = "Table Grid"
    paragraph._p.addnext(table._tbl)
    for ri, row in enumerate(rows):
        for ci, val in enumerate(row):
            set_cell(table.rows[ri].cells[ci], val, bold=(ri == 0))
        if ri == 0:
            shade_header_row(table.rows[0])
    return table


def replace_table(old: Table, doc: Document, rows: list[list[str]]) -> Table:
    table = doc.add_table(rows=len(rows), cols=len(rows[0]))
    table.style = "Table Grid"
    old._tbl.addnext(table._tbl)
    parent = old._tbl.getparent()
    parent.remove(old._tbl)
    for ri, row in enumerate(rows):
        for ci, val in enumerate(row):
            set_cell(table.rows[ri].cells[ci], val, bold=(ri == 0))
        if ri == 0:
            shade_header_row(table.rows[0])
    return table


def main() -> None:
    shutil.copy2(SRC, OUT)
    doc = Document(str(OUT))

    for p in doc.sections[0].header.paragraphs:
        if "Software Licence" in p.text or "Rev." in p.text:
            set_text_keep_runs(
                p,
                "Software Licence and Implementation Agreement · Rev. 1.2 (13 Nov 2026) · "
                "Lebawi International Academy and Majo Bridge Technologies and Events PLC",
            )

    set_text_keep_runs(
        para_by_prefix(doc, "SOFTWARE LICENCE AND IMPLEMENTATION AGREEMENT"),
        "SOFTWARE LICENCE AND IMPLEMENTATION AGREEMENT — REVISION 1.2",
    )
    p_title = para_by_prefix(doc, "SOFTWARE LICENCE AND IMPLEMENTATION AGREEMENT")
    insert_after(
        p_title,
        "Revision 1.2 · 13 November 2026 G.C. · supersedes Revision 1.1 · MBT-LIA-AGR-2026-01",
    )

    cover = doc.tables[0]
    cover.rows[1].cells[1].text = "MBT-LIA-AGR-2026-01  ·  Revision 1.2 (13 November 2026)"
    cover.rows[7].cells[1].text = (
        "Annex Register (signed) · A Module list and prices · B Deliverables, milestones and TOR crosswalk "
        "(D1–D12) · C Payment schedule · D Client-provided infrastructure · E Inception Report "
        "MBT-LIA-INC-2026-01 · F Training Modules MBT-LIA-TRN-2026-01 · G Financial Proposal "
        "MBT-LIA-FIN-2026-02 · H Notice of Intent to Award · I Certificate of Recognition (form) · "
        "J LIA Revised TOR Version 1.0, October 2026 (21 pages, 23 sections + Appendices A and B)"
    )

    p_this = para_by_prefix(doc, "This Software Licence and Implementation Agreement")
    banner = para_by_prefix(doc, "This Revision 1.1 of 10 November 2026")
    set_text_keep_runs(
        banner,
        "This Revision 1.2 of 13 November 2026 G.C. amends Revision 1.1 so that Annex J (the complete "
        "Revised TOR, Version 1.0, October 2026, twenty-one (21) pages, twenty-three (23) sections and "
        "Appendices A and B) is the functional and technical baseline. The Inception Report may add "
        "implementation detail but shall not reduce or override Annex J unless the Client approves a "
        "formal change order under Article 15. Commercial terms (Contract Price, VAT, payment amounts "
        "and timing) remain unchanged from Revision 1.0: 4,456,250 ETB VAT inclusive, 40/40/20. Changes "
        "from Revision 1.1 are marked in Articles 1, 2, 3, 7, 8, 10, 12 and 15 and in Annexes B, E, F, G and J.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "(d)\t“Inception Report”"),
        "(d)\t“Inception Report” means document MBT-LIA-INC-2026-01, Version 1.0 of 27 October 2026, "
        "attached as Annex E, as finalised and accepted under Milestone M2, and any later revision signed "
        "by both Parties. The Inception Report may provide implementation detail (schedule, rooms, named "
        "owners, templates) but shall not reduce, replace, or override any requirement of Annex J, "
        "including Sections 14 and 17 and Appendix B, unless the Client approves a formal change order "
        "under Article 15.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "(g-bis)\t“Revised TOR”"),
        "(g-bis)\t“Revised TOR” or “Annex J” means the complete document titled “Revised Terms of "
        "Reference — MaJo e-School Bridge (49 Modules)”, also headed “TERMS OF REFERENCE — "
        "Implementation, Configuration, Integration, Deployment and Support of the MaJo e-School Bridge "
        "Platform — Revised Scope: 49 Included Modules”, Version 1.0, October 2026, comprising twenty-three "
        f"(23) sections and Appendices A and B, twenty-one ({TOR_PAGES}) pages in the PDF execution copy "
        "attached hereto and initialled on every page by both Parties. It includes the complete 49-module "
        "register (Appendix A) and the minimum UAT checklist (Appendix B). No later or different version "
        "applies unless signed by both Parties.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "(i)\t“Deliverable”"),
        "(i)\t“Deliverable” and “Milestone” mean the items listed in Annex B. Annex B is a crosswalk "
        "that preserves every TOR deliverable D1 to D12 in Annex J, Section 13, without reducing the "
        "minimum contents stated there. Where this Agreement previously used a different number (in "
        "particular former D6 training, former D8 pilot, former D10 Go-Live Certificate, and former D11 "
        "combined handover), the TOR number and contents control.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "(j)\t“Go-Live”"),
        "(j)\t“Go-Live” means the date on which the System is in productive use by all sections of the "
        "Client and the Go-Live Certificate (an instrument in Deliverable D9) is signed, targeted for "
        "Monday 21 December 2026. Deliverable D10 is Training and user documentation.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(k)\t“User-Acceptance Testing”"),
        "(k)\t“User-Acceptance Testing” or “UAT” means the tests and acceptance activities required by "
        "this Agreement, Annex J (including Sections 14 and 17 and Appendix B), and the approved test "
        "plan. The Inception Report may provide implementation detail (including the scripted scenarios "
        "in its Section 13) but shall not reduce or override the requirements of Annex J.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "(k)\tAnnex J"),
        "(k)\tAnnex J — the complete document titled “Revised Terms of Reference — MaJo e-School Bridge "
        "(49 Modules)”, Version 1.0, October 2026, comprising twenty-three (23) sections and Appendices A "
        f"and B, twenty-one ({TOR_PAGES}) pages, including the complete 49-module register (Appendix A) "
        "and the minimum UAT checklist (Appendix B). No later or different version applies unless signed "
        "by both Parties; and",
    )
    p_k = para_by_prefix(doc, "(k)\tAnnex J")
    p_l = insert_after(
        p_k,
        "(l)\tAnnex Register — the signed schedule in Article 2.4 listing each annex title, version or "
        "date, page count, and initials of both Parties.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "2.2\tIn the event of conflict"),
        "2.2\tFor functional and technical scope, the 49 included modules, exclusions, integrations, "
        "security, data placement, non-functional requirements, testing, acceptance, deliverables, "
        "training and handover, Annex J shall prevail over any inconsistent provision in the Agreement "
        "or other annex. Articles 4 and 5 shall prevail only for the agreed Contract Price, VAT and "
        "payment amounts/timing, provided that payment triggers remain conditional on the acceptance "
        "requirements expressly stated in this Agreement and Annex J. Without limiting the foregoing, "
        "Articles 8.1(f), 10.1, 10.2 and 10.6 shall not be read to reduce Annex J Sections 14 or 17 or "
        "Appendix B. The remaining commercial and legal Articles (licence, intellectual property, "
        "confidentiality, liability, dispute, governing law) prevail over annexes on those subjects. "
        "Annex E (Inception Report) and Annexes F to H yield to Annex J on scope, testing and acceptance, "
        "and yield to Articles 4 and 5 on price and payment.",
    )

    p_23 = para_by_prefix(doc, "2.3\tThe Technical Proposal")
    p_24 = insert_after(
        p_23,
        "2.4\tEach annex listed in Article 2.1 is an integral part of this Agreement only in the complete "
        "final version attached to the execution copy and initialled (or signed) by both Parties. The "
        "Annex Register below records title, version or date, page count, and initials. If an annex is "
        "not attached and authenticated at signature, it shall not create an additional obligation or "
        "charge until signed by both Parties. The Inception Report (Annex E) and the training guide "
        "(Annex F) must be consistent with Annex J. The Financial Proposal (Annex G) and the Notice of "
        "Intent to Award (Annex H) shall not introduce unapproved recurring charges or scope.",
    )
    insert_after(
        p_24,
        "2.5\tMilestone M2 (acceptance of the Inception Report and the Requirements and Customization "
        "Registers) does not authorise any reduction of Annex J. A requirement of Annex J, including "
        "Section 14, Section 17, Appendix A or Appendix B, is varied only by a written change order "
        "signed under Article 15.",
    )
    register_rows = [
        ["Annex", "Title", "Version / date", "Pages", "LIA initials", "MaJo initials"],
        ["—", "This Agreement, Articles 1 to 24", "Rev. 1.2, 13 Nov 2026", "as printed", "", ""],
        ["A", "Module list, categories, and unit prices", "Rev. 1.2 (49 modules)", "in this booklet", "", ""],
        ["B", "Deliverables, milestones and TOR D1–D12 crosswalk", "Rev. 1.2", "in this booklet", "", ""],
        ["C", "Payment schedule", "Rev. 1.2 (amounts unchanged)", "in this booklet", "", ""],
        ["D", "Infrastructure, premises, and Client inputs", "Rev. 1.2", "in this booklet", "", ""],
        ["E", "Inception Report MBT-LIA-INC-2026-01", "Version 1.0, 27 Oct 2026", "15", "", ""],
        ["F", "Training Modules and Trainer's Guide MBT-LIA-TRN-2026-01", "Version 1.0, 27 Oct 2026", "17", "", ""],
        ["G", "Financial Proposal MBT-LIA-FIN-2026-02", "16 Oct 2026", "5", "", ""],
        ["H", "Notice of Intent to Award", "as issued by LIA Procurement", "as attached", "", ""],
        ["I", "Form of Certificate of Recognition", "Rev. 1.2", "in this booklet", "", ""],
        [
            "J",
            "Revised TOR — MaJo e-School Bridge (49 Modules), 23 sections + App. A and B",
            "Version 1.0, October 2026",
            str(TOR_PAGES),
            "",
            "",
        ],
    ]
    insert_table_after(p_24, doc, register_rows)

    set_text_keep_runs(
        para_by_prefix(doc, "(f)\tdeliver the training sessions"),
        "(f)\tdeliver the Integration Specification and Test Evidence for agreed included-module "
        "integrations (Deliverable D6), and deliver the training sessions in Annex F together with "
        "the user and administrator documentation (Deliverable D10);",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(g)\tperform the backup restore drill"),
        "(g)\tdeliver the Security and access-control pack, including the backup restore drill and the "
        "security check of both nodes (Deliverable D7);",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(h)\trun a two-week pilot"),
        "(h)\tdeliver the Testing Package (test plan, cases, functional, integration, permission, "
        "migration, security, compatibility, recovery, hybrid-hosting and performance evidence, defect "
        "register and retest results), including the two-week pilot report as supporting evidence "
        "(Deliverable D8);",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(i)\tsupport the Client's User-Acceptance Testing"),
        "(i)\tsupport the Client's User-Acceptance Testing under Annex J Sections 14 and 17 and Appendix B, "
        "fix defects, and obtain the UAT and go-live sign-off pack including the Go-Live Certificate "
        "(Deliverable D9);",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(j)\tbring all sections live"),
        "(j)\tbring all sections live on the agreed Go-Live date as part of Deliverable D9;",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(k)\tprovide hypercare for four"),
        "(k)\tprovide hypercare for four (4) weeks after Go-Live, including on-site presence in the first "
        "week, and deliver the Operations and support handover (Deliverable D11);",
    )
    p_k_scope = para_by_prefix(doc, "(k)\tprovide hypercare for four")
    insert_after(
        p_k_scope,
        "(k-bis)\tdeliver the Final Handover and Acceptance Report (Deliverable D12), which is separate "
        "from Go-Live approval; and",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "(a)\tperform the services with the skill"),
        "(a)\tperform the services with the skill, care, and diligence expected of a professional software "
        "provider, using qualified personnel, and in accordance with this Agreement and Annex J; the "
        "Inception Report supplies implementation detail only and does not reduce Annex J;",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "(f)\treview each Deliverable within five"),
        "(f)\treview each Deliverable within five (5) Working Days and give written comments or acceptance. "
        "Silence after five (5) Working Days may be treated as acceptance of ordinary transmittals other "
        "than Deliverables D8, D9, D11 and D12. Silence does not constitute passed UAT, Go-Live approval, "
        "or final acceptance under Annex J Sections 14 and 17. Those four instruments require a dated "
        "written signature (or a dated written statement of defects) by the acceptor named in Annex B;",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "10.1\tEach Deliverable is submitted"),
        "10.1\tEach Deliverable is submitted to the acceptor named in Annex B with a transmittal note. "
        "The acceptor reviews it within five (5) Working Days. Comments are answered in writing by the "
        "Service Provider. Silence after five (5) Working Days may be treated as acceptance only as "
        "limited by Article 8.1(f). UAT, Go-Live and final acceptance remain governed by Annex J "
        "Sections 14 and 17 and by Deliverables D8, D9 and D12.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "10.2\tThe second instalment becomes due"),
        "10.2\tThe second instalment becomes due when the Service Provider issues the UAT readiness notice "
        "confirming that the configured Modules, the migrated data, and the trained users are ready for "
        "User-Acceptance Testing, after Milestone M5, and when Deliverables D3, D4, D5, D6, D7, D8 and D10 "
        "have been accepted in writing (not merely by silence). Payment of that instalment does not waive "
        "Annex J testing or acceptance requirements still to be performed under D9 and D12.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "10.3\tUAT is run by the Client's officers"),
        "10.3\tUAT is run by the Client's officers using Annex J Section 14, Annex J Section 17, Annex J "
        "Appendix B, and the approved test plan, on the Client's own data under the Client's control. "
        "Scenarios in Section 13 of the Inception Report may be used as additional scripts; they do not "
        "replace the TOR checklist. Testing includes functional, integration, permission (positive and "
        "negative), migration reconciliation, security, compatibility, recovery, and hybrid-hosting tests "
        "as listed in Annex J, Section 14. Performance is tested against an agreed user-load profile; the "
        "former target of 1,000 concurrent users and 99.5% availability are operating targets to be "
        "validated and evidenced, not certificates already proven in a laboratory. Defects are logged with "
        "a severity. The Service Provider fixes defects and the Client retests.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "10.4\tAcceptance and Go-Live criteria"),
        "10.4\tAcceptance and Go-Live criteria are those in Annex J Section 17, including: no open "
        "Critical or High (Severity-1 or Severity-2) defect unless the Client formally accepts a documented "
        "workaround; the forty-nine (49) included Modules configured and demonstrated; the ten (10) "
        "Excluded Modules disabled or inaccessible; agreed migration reconciled; hybrid tests in Article "
        "7.1(m) and Annex J Sections 9.1.1 and 14 passed; Data-Placement Matrix signed; training and "
        "handover materials delivered. On fulfilment of the UAT/go-live conditions, the Client signs "
        "Deliverable D9 (UAT and go-live sign-off pack, including the Go-Live Certificate). Final written "
        "acceptance is Deliverable D12 and is separate from Go-Live. Go-Live approval and final handover "
        "are separate from any assertion that a live product already exists.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "10.6\tUse of the System in production"),
        "10.6\tUse of the System in production by the Client, including use for fifteen (15) consecutive "
        "Working Days, does not of itself constitute UAT pass, Go-Live approval, or final acceptance. "
        "Those events require the written instruments in Deliverables D9 and D12 and the criteria in "
        "Annex J Sections 14 and 17. The Client shall not unreasonably withhold or delay those signatures "
        "where the stated criteria are met.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "12.1\tThe Service Provider warrants"),
        "12.1\tThe Service Provider warrants that, for the Support Period, the System shall perform "
        "materially in accordance with Annex J, the Requirements Register, and the Customization Register, "
        "and shall correct any non-conformity at no cost. The Inception Report does not narrow this warranty.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "15.1\tThe Requirements Register"),
        "15.1\tAnnex J is the functional and technical baseline. The Requirements Register and the "
        "Customization Register signed under Milestone M2, and the Inception Report as accepted under M2, "
        "are implementation instruments under that baseline. Any change requested after M2, and any change "
        "that would reduce or replace a requirement of Annex J, is recorded in the issue log, assessed by "
        "the Service Provider for effect on scope, time, and price, and implemented only after a written "
        "variation order (change order) signed by the Client's project sponsor and the Service Provider's "
        "project lead.",
    )
    p_153 = para_by_prefix(doc, "15.3\tAny variation that changes")
    insert_after(
        p_153,
        "15.4\tThe M2 Inception Report must not reduce or replace any requirement in the signed TOR "
        "(Annex J) unless the Client approves a formal change order under this Article 15. Product "
        "updates, e-mail, or demonstration do not amend Annex J.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "ANNEX B — DELIVERABLES"),
        "ANNEX B — DELIVERABLES, MILESTONES AND TOR D1–D12 CROSSWALK",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "ANNEX J — LIA REVISED TOR"),
        "ANNEX J — REVISED TOR (VERSION 1.0, OCTOBER 2026, 21 PAGES)",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "As set out in Sections 7 and 8"),
        "Annex B maps every TOR deliverable in Annex J, Section 13 (D1 to D12) to this Agreement. "
        "TOR contents are the minimum; extra rows in this Agreement add implementation detail only. "
        "Acceptance follows Article 10 and Annex J Sections 14 and 17. Both Parties initial this annex.",
    )

    crosswalk = [
        [
            "TOR ID / title (Annex J §13)",
            "Agreement ID / title",
            "Required contents (TOR minimum; not reduced)",
            "Due",
            "LIA acceptance owner",
        ],
        [
            "D1 Inception report and approved implementation plan",
            "D1 Inception report (MBT-LIA-INC-2026-01)",
            "Scope confirmation, schedule, roles, governance, risks, dependencies and communications. Implementation detail only; must not reduce Annex J.",
            "M2",
            "LIA Procurement / project sponsor",
        ],
        [
            "D2 Requirements and configuration baseline",
            "D2 Software requirements and customization registers",
            "Module-by-module configuration decisions, workflow diagrams, role matrix, grading rules and unresolved gaps; LIA owners.",
            "M2",
            "LIA focal person and office heads",
        ],
        [
            "D3 Hosting and architecture pack",
            "D3 Hybrid environment / hosting and architecture pack",
            "Architecture and data-flow diagrams; Data-Placement Matrix; School Node on LIA server; Cloud Node; encrypted tunnel; one-login test; hardening; subprocessors; incident escalation.",
            "M3",
            "IT Admin",
        ],
        [
            "D4 Configured 49-module platform",
            "D4 Configured and customized LIA school",
            "LIA-branded production-ready instance for the 49 included modules; Excluded Modules disabled or inaccessible; customizations from D2.",
            "M3",
            "IT Admin and Principal",
        ],
        [
            "D5 Data migration package",
            "D5 Data migration package",
            "Templates, mappings, test-import report, reconciliation results, exception log and approved migration record; live data on the School Node.",
            "M4",
            "Registrar",
        ],
        [
            "D6 Integration specification and test evidence",
            "D6 Integration specification and test evidence",
            "Data exchanged, triggers, error handling, limitations and test results for agreed included-module integrations (including SIS ↔ admissions/parents/transfers; exams ↔ markbook ↔ report cards).",
            "M5",
            "IT Admin and office heads",
        ],
        [
            "D7 Security and access-control pack",
            "D7 Security and access-control pack",
            "Approved role matrix; permission test evidence (positive and negative); backup/restore process and restore-drill evidence; incident escalation; privacy/data-handling notes; MFA on privileged accounts.",
            "M5",
            "IT Admin",
        ],
        [
            "D8 Testing package",
            "D8 Testing package (pilot report is supporting evidence, not a substitute)",
            "Test plan, test cases, functional/integration/security/performance evidence, defect register and retest results, plus the two-week pilot report.",
            "M5 / W7",
            "Section Director (pilot) and project sponsor",
        ],
        [
            "D9 UAT and go-live sign-off pack",
            "D9 UAT and go-live sign-off pack (includes the Go-Live Certificate formerly labelled D10)",
            "UAT scenarios, Annex J Appendix B checklist, user feedback, open-defect list, risk acceptance where applicable, go/no-go approval and Go-Live Certificate.",
            "M6 (UAT) / M7 (Go-Live)",
            "LIA project sponsor",
        ],
        [
            "D10 Training and user documentation",
            "D10 Training and user documentation (formerly labelled D6 in Rev. 1.1)",
            "Administrator/IT guide, teacher guide, parent/student guides, module-specific quick references, training attendance, Annex F sessions and train-the-trainer.",
            "M5",
            "Principal",
        ],
        [
            "D11 Operations and support handover",
            "D11 Operations and support handover",
            "Support contacts, escalation matrix, update/maintenance process, backup schedule, recovery steps, monitoring guidance, known limitations and operations handbook.",
            "M8",
            "IT Admin",
        ],
        [
            "D12 Final handover and acceptance report",
            "D12 Final handover and acceptance report (separate from Go-Live; not merged into D11)",
            "List of delivered modules, configuration baseline, outstanding items, export instructions, account handover and acceptance record.",
            "M8",
            "LIA project sponsor",
        ],
    ]
    def find_table(start: str) -> Table:
        for t in doc.tables:
            if t.rows and t.rows[0].cells[0].text.strip().startswith(start):
                return t
        raise KeyError(start)

    replace_table(find_table("D"), doc, crosswalk)

    def find_table_header(*starts: str) -> Table:
        for t in doc.tables:
            heads = [c.text.strip() for c in t.rows[0].cells]
            if all(any(h.startswith(s) for h in heads) for s in starts):
                return t
        raise KeyError(starts)

    pay = find_table_header("Instalment", "Due on")
    pay.rows[2].cells[4].text = (
        "UAT readiness notice; Deliverables D3, D4, D5, D6, D7, D8 and D10 accepted in writing; VAT invoice"
    )
    pay.rows[3].cells[4].text = (
        "Signed Go-Live Certificate forming part of Deliverable D9; VAT invoice. Final acceptance (D12) is separate and does not delay this instalment once D9 Go-Live is signed."
    )
    annex_c = find_table_header("Instalment", "In words")
    annex_c.rows[2].cells[4].text = "UAT readiness notice after Milestone M5; D3–D8 and D10 accepted in writing"
    annex_c.rows[3].cells[4].text = "Go-Live Certificate (instrument in D9), Milestone M7"

    set_text_keep_runs(
        para_by_prefix(doc, "Document MBT-LIA-INC-2026-01"),
        "Document MBT-LIA-INC-2026-01, “Inception Report — Student Management System (SMS) Project at "
        "Lebawi International Academy”, Version 1.0 of 27 October 2026, fifteen (15) pages, including its "
        "Annexes A (module scope checklist), B (data templates), C (training timetable), D (hybrid "
        "architecture and server specification), and E (requirements and customization registers, attached "
        "when signed under Milestone M2). The version accepted under Milestone M2 may update implementation "
        "detail. It shall not reduce or override Annex J, including Sections 14 and 17 and Appendix B, "
        "unless the Client approves a formal change order under Article 15. Attached hereto and initialled "
        "on every page by both Parties, and recorded in the Annex Register.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "Document MBT-LIA-TRN-2026-01"),
        "Document MBT-LIA-TRN-2026-01, Version 1.0 of 27 October 2026, seventeen (17) pages: thirteen (13) "
        "training modules T1 to T13 with attendance sheet, evaluation form, competency checklists, and room "
        "and practice-data requirements. Training content shall be consistent with Annex J Section 15 and "
        "Deliverable D10. Attached hereto, initialled by both Parties, and recorded in the Annex Register.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "Document MBT-LIA-FIN-2026-02"),
        "Document MBT-LIA-FIN-2026-02, “Financial Proposal — One-time module licence and implementation”, "
        "of 16 October 2026, five (5) pages, Schedules A and B. Attached for the record of unit prices and "
        "the recalculation rule in Article 3.3. The 59-module total in any earlier catalogue is not applied. "
        "Where it conflicts with Articles 4 and 5 of this Agreement, this Agreement prevails. Annex G shall "
        "not introduce unapproved recurring charges, hosting retainers, SMS, payment-gateway, or other "
        "scope beyond this Agreement and Annex J. Recorded in the Annex Register.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "Letter of the Procurement Department"),
        "Letter of the Procurement Department of Lebawi International Academy, “Notice of Intent to Award "
        "— Student Management System (SMS) Project”, reference ______________, dated ______________ 2026, "
        "addressed to Majo Bridge Technologies and Events PLC. Attached hereto, initialled, and recorded "
        "in the Annex Register. It does not add modules, exclusions, or recurring charges beyond this "
        "Agreement and Annex J.",
    )

    set_text_keep_runs(
        para_by_prefix(doc, "The document entitled “TERMS OF REFERENCE"),
        "Annex J is the complete document titled “Revised Terms of Reference — MaJo e-School Bridge "
        "(49 Modules)”, Version 1.0, October 2026, comprising twenty-three (23) sections and Appendices A "
        f"and B, twenty-one ({TOR_PAGES}) pages in the PDF execution copy attached hereto "
        "(file: docs/agreements/LIA_MaJo_Bridge_Revised_TOR_49_Modules.pdf). It includes the complete "
        "49-module register (Appendix A) and the minimum UAT checklist (Appendix B). Both Parties shall "
        "initial or sign every page of that execution copy. No later or different version applies unless "
        "signed by both Parties.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "In case of inconsistency: this Agreement"),
        "In case of inconsistency: Annex J prevails for functional and technical scope, the 49 included "
        "modules, exclusions, integrations, security, data placement, non-functional requirements, testing, "
        "acceptance, deliverables, training and handover, as stated in Article 2.2. Articles 4 and 5 prevail "
        "only for Contract Price, VAT and payment amounts/timing, and only while payment triggers remain "
        "conditional on the acceptance requirements in this Agreement and Annex J.",
    )

    inputs = find_table_header("Client input", "Due date")
    inputs.rows[6].cells[2].text = "D10 training; M5"
    inputs.rows[7].cells[2].text = "D9 UAT; M6"

    doc.core_properties.title = (
        "MBT-LIA-AGR-2026-01 Rev. 1.2 — Software Licence and Implementation Agreement"
    )
    doc.core_properties.subject = (
        "LIA / MaJo Bridge — Annex J TOR control, annex register, D1–D12 crosswalk"
    )
    doc.core_properties.revision = 3
    doc.save(str(OUT))
    print("Wrote", OUT, "bytes", OUT.stat().st_size)


if __name__ == "__main__":
    main()

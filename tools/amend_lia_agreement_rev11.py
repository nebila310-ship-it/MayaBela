#!/usr/bin/env python3
"""Apply Revision 1.1 of MBT-LIA-AGR-2026-01 to incorporate LIA Revised TOR (49 modules)."""
from __future__ import annotations

import shutil
from copy import deepcopy
from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph
from docx.shared import RGBColor, Pt, Twips
from docx.oxml.ns import qn

SRC = Path(
    "/home/ubuntu/.cursor/projects/workspace/uploads/MaJo_Bridge_LIA_Agreement_e616.docx"
)
OUT = Path("/workspace/docs/agreements/MBT-LIA-AGR-2026-01_Rev1.1.docx")
TOR_SRC = Path(
    "/home/ubuntu/.cursor/projects/workspace/uploads/LIA_MaJo_Bridge_Revised_TOR_49_Modules__1__9da6.pdf"
)
TOR_DST = Path(
    "/workspace/docs/agreements/LIA_MaJo_Bridge_Revised_TOR_49_Modules.pdf"
)

CATALOGUE = {
    "Weighted Markbook": 7,
    "LMS": 17,
    "Grade Workflow": 20,
    "Examinations & Grade Approvals": 6,
    "Exam bank & papers": 9,
    "Academic Management": 5,
    "Curriculum office": 19,
    "Homework": 11,
    "Lesson plans": 18,
    "Report Cards": 8,
    "Timetable": 16,
    "Analytics & exports": 13,
    "e-Books & Materials": 44,
    "Students (SIS)": 21,
    "Attendance": 10,
    "Admissions": 23,
    "Transfers & Promotion": 32,
    "At-risk & insights": 12,
    "Student support": 28,
    "Parents & Link Approvals": 31,
    "Add Student": 22,
    "Student Affairs & Discipline": 27,
    "Student programs": 30,
    "Alumni": 24,
    "Inventory, Procurement & Store": 34,
    "Safeguarding": 26 if False else 29,
    "Reports & Analytics": 51,
    "Go-live & compliance": 57,
    "Audit Log": 54,
    "QA Findings & Plans": 50,
    "Messages": 46,
    "Calendar": 49,
    "Announcements": 45,
    "Library": 43,
    "Events": 47,
    "Gallery": 48,
    "Maya Assistant": 52,
    "Role Permissions": 53,
    "Institution Management": 1,
    "School Management": 2,
    "System Health": 55,
    "Classroom Teachers": 14,
    "Add Teacher": 15,
    "Administration Staff Directory": 37,
    "Add Administration Staff": 38,
    "Student Portal Settings": 25,
    "Student Password Resets": 26,
    "Settings": 58,
    "Dashboard / Profile": 59,
}


def para_by_prefix(doc: Document, prefix: str) -> Paragraph:
    for p in doc.paragraphs:
        if p.text.startswith(prefix):
            return p
    raise KeyError(prefix)


def set_text_keep_runs(p: Paragraph, text: str) -> None:
    """Replace paragraph text, keeping the first run's formatting."""
    if p.runs:
        p.runs[0].text = text
        for r in p.runs[1:]:
            r.text = ""
    else:
        p.add_run(text)


def insert_after(paragraph: Paragraph, text: str, *, heading: bool = False) -> Paragraph:
    new_p = deepcopy(paragraph._p)
    paragraph._p.addnext(new_p)
    new_para = Paragraph(new_p, paragraph._parent)
    if heading:
        new_para.style = paragraph.style
    set_text_keep_runs(new_para, text)
    return new_para


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SRC, OUT)
    if TOR_SRC.exists():
        shutil.copy2(TOR_SRC, TOR_DST)

    doc = Document(str(OUT))

    # Header: mark revision
    for p in doc.sections[0].header.paragraphs:
        if "Software Licence" in p.text:
            set_text_keep_runs(
                p,
                "Software Licence and Implementation Agreement · Rev. 1.1 (10 Nov 2026) · "
                "Lebawi International Academy and Majo Bridge Technologies and Events PLC",
            )

    # Cover table — annexes row
    cover = doc.tables[0]
    cover.rows[7].cells[1].text = (
        "A Module list and prices · B Deliverables and milestones · C Payment schedule · "
        "D Client-provided infrastructure · E Inception Report MBT-LIA-INC-2026-01 · "
        "F Training Modules MBT-LIA-TRN-2026-01 · G Financial Proposal MBT-LIA-FIN-2026-02 · "
        "H Notice of Intent to Award · I Certificate of Recognition (form) · "
        "J LIA Revised TOR — 49 Included Modules (October 2026)"
    )
    cover.rows[2].cells[1].text = (
        "One-time licence of 49 MaJo e-School Bridge modules (LIA Revised TOR, October 2026) "
        "with four login portals, customization, hybrid implementation, data migration, "
        "training, go-live, and one year of support for Lebawi International Academy"
    )

    # Version banner after title block
    p_this = para_by_prefix(doc, "This Software Licence and Implementation Agreement")
    insert_after(
        p_this,
        "This Revision 1.1 of 10 November 2026 G.C. incorporates the Client's Revised Terms of "
        "Reference, “Implementation, Configuration, Integration, Deployment and Support of the "
        "MaJo e-School Bridge Platform — Revised Scope: 49 Included Modules” (October 2026), "
        "attached as Annex J. Commercial terms (price, payment, licence, liability) are unchanged "
        "from Revision 1.0. Functional and technical acceptance follow Annex J. Changes from "
        "Revision 1.0 are marked in Articles 1 to 3, 6 to 10, 12, 13 and 15 and in Annexes A, B and D.",
    )

    # Article 1 definitions
    set_text_keep_runs(
        para_by_prefix(doc, "(a)\t“System”"),
        "(a)\t“System” means the MaJo e-School Bridge software, comprising the forty-nine (49) "
        "Modules listed in Annex A (which are the same forty-nine (49) included modules in Annex J, "
        "Appendix A), the four (4) login portals (Administration/ERP, Teacher, Parent, Student), "
        "the Customizations, and the related in-app manuals, as installed and configured for the Client.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(e)\t“Hybrid Implementation”"),
        "(e)\t“Hybrid Implementation” means the architecture described in Article 9, in Section 6 "
        "and Annex D of the Inception Report, and in Section 9 of Annex J, in which the School Node "
        "runs on the Client's physical server (authoritative copy of sensitive records) and the Cloud "
        "Node runs on the Service Provider's self-hosted cloud server (application delivery, login "
        "routing, and limited published copies only as approved in the Data-Placement Matrix).",
    )
    p_hybrid = para_by_prefix(doc, "(g)\t“Cloud Node”")
    set_text_keep_runs(
        p_hybrid,
        "(g)\t“Cloud Node” means the installation of the System's authentication, role catalogue, "
        "application delivery, notification, training materials, and system-health services on the "
        "Service Provider's self-hosted cloud server. It is not a second master database of student "
        "records. Named student, health, counseling, safeguarding, draft marks, and unpublished "
        "report-card records shall not be stored as a cloud master copy.",
    )
    p_after = insert_after(
        p_hybrid,
        "(g-bis)\t“Revised TOR” or “Annex J” means the Client's document “Revised Terms of Reference "
        "— MaJo e-School Bridge (49 Modules)”, Version 1.0, October 2026, including Appendix A "
        "(module register) and Appendix B (minimum UAT checklist).",
    )
    p_after = insert_after(
        p_after,
        "(g-ter)\t“Data-Placement Matrix” means the schedule, approved in writing by both Parties "
        "before production data is loaded, listing each data category, its master-copy location, any "
        "permitted published or transient copy, backup location, retention, responsible party, and "
        "access method (Annex J, Section 9.1.1).",
    )
    p_after = insert_after(
        p_after,
        "(g-quater)\t“Excluded Modules” means the ten (10) catalogue modules listed in Article 3.2 "
        "and in Annex J, Section 4.2, which are outside this Agreement unless added by a written "
        "variation under Article 15.",
    )

    # Article 2 documents
    set_text_keep_runs(
        para_by_prefix(doc, "(j)\tAnnex I"),
        "(j)\tAnnex I — Form of Certificate of Recognition; and",
    )
    p_j = para_by_prefix(doc, "(j)\tAnnex I")
    insert_after(
        p_j,
        "(k)\tAnnex J — LIA Revised TOR, 49 Included Modules (October 2026), including Appendix A "
        "and Appendix B.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "2.2\tIn the event of conflict"),
        "2.2\tIn the event of conflict or inconsistency, the documents shall prevail in the following "
        "order: (1) Articles 4 and 5 of this Agreement as to Contract Price and payment; (2) the "
        "remaining Articles of this Agreement; (3) Annex J as to functional and technical acceptance "
        "scope, exclusions, hybrid data placement, testing, and handover; (4) Annexes A to D and I; "
        "(5) Annex E (Inception Report) as finalised under Milestone M2; (6) Annexes F to H. The "
        "Contract Price and the payment terms in Articles 4 and 5 prevail over any amount or payment "
        "term in Annexes E to H and in Annex J.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "2.3\tThe Technical Proposal"),
        "2.3\tThe Technical Proposal, the Business Proposal, the 59-module catalogue, and the "
        "Addendum on Hybrid Hosting dated 15 September 2026 are background documents. They describe "
        "the product and may be consulted for interpretation but do not add modules, portals, "
        "transport, GPS, CCTV, or recurring charges beyond those in this Agreement and Annex J. "
        "References in those background papers to “55+ desks” or to excluded transport functions do "
        "not expand the contracted scope.",
    )

    # Article 3.1(a) + 3.2 expansions + 3.3–3.6
    set_text_keep_runs(
        para_by_prefix(doc, "(a)\tgrant to the Client the licence"),
        "(a)\tgrant to the Client the licence described in Article 11 for all forty-nine (49) Modules "
        "in Annex A / Annex J Appendix A and the four (4) login portals;",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(c)\timplement the System under the Hybrid Implementation"),
        "(c)\timplement the System under the Hybrid Implementation: install, configure, and secure "
        "the School Node on the Client's physical server and the Cloud Node on the Service Provider's "
        "self-hosted cloud server, connect them by an encrypted tunnel, produce the Data-Placement "
        "Matrix and architecture pack (Deliverable D3), and demonstrate the one-login test;",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(d)\tconfigure and customize the System"),
        "(d)\tconfigure and customize the System for the Client: school record, academic year and "
        "terms (including Pearson Early Years, Primary, Middle and Secondary where the Client so "
        "directs), grading schemes, approval chains, role-permission matrix, branding, and the "
        "Customizations in the Customization Register; disable or hide the Excluded Modules "
        "(Deliverable D4);",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "3.2\tThe following are outside the scope"),
        "3.2\tThe following are outside the scope of this Agreement unless added by a written "
        "variation under Article 15: the Excluded Modules, namely Campus Management (catalogue 3), "
        "CCTV (catalogue 4), Finance (catalogue 33), Human Resource (catalogue 35), Payroll "
        "(catalogue 36), Transport (catalogue 39), Buses (catalogue 40), Live GPS (catalogue 41), "
        "Register Driver (catalogue 42), and Digital Operations (catalogue 56); the Driver login "
        "portal; hardware and network equipment (which the Client procures under Annex D after "
        "written approval of that specification); recurring third-party charges (SMS gateway, "
        "internet lines, domain renewals, payment gateways, app-store fees); re-typing of records "
        "not provided in the agreed templates; and support, hosting, or subscription after the "
        "Support Period. Inventory, Procurement & Store (catalogue 34) remains included and shall "
        "not enable excluded Finance processing. Library fines that depend on Finance shall not be "
        "enabled. No licence or implementation charge is payable for any Excluded Module or for the "
        "disabled Driver portal.",
    )
    p32 = para_by_prefix(doc, "3.2\tThe following are outside the scope")
    p = insert_after(
        p32,
        "3.3\tAt the kick-off meeting the Parties tick the “Confirmed” column in Annex A against "
        "Annex J, Appendix A. The forty-nine (49) Modules and the unit prices in Annex A are the "
        "priced selection. If, before Milestone M2, the Client removes a Module in writing, the "
        "Contract Price is recalculated by deducting that Module's unit price in Annex A, plus VAT, "
        "and Annex C is adjusted in the same proportions; no other recalculation applies. Adding any "
        "Excluded Module requires a variation under Article 15 stating price, implementation impact, "
        "and acceptance criteria.",
    )
    p = insert_after(
        p,
        "3.4\tThe Service Provider shall ensure that Excluded Modules are disabled or inaccessible "
        "in the Client's production configuration and are not acceptance dependencies. Where an "
        "included Module would otherwise display fees, transport, GPS, CCTV, payroll, HR lifecycle, "
        "or Driver-portal workflows, the Service Provider shall hide or clearly label that feature as "
        "unavailable so that users are not misled.",
    )
    p = insert_after(
        p,
        "3.5\tMaya Assistant (catalogue 52) is an included Module. It shall not be activated against "
        "live Client Data, and no Client Data shall be sent to an external AI or other third-party "
        "service, until the Client has given prior written approval after receiving a written "
        "disclosure of data sources, processing, transfers, limitations, and permissions (Annex J, "
        "Sections 5.H.52, 6 and 10).",
    )
    insert_after(
        p,
        "3.6\tFeatures described in the Service Provider's proposals as “already implemented” remain "
        "subject to demonstration and successful testing on the Client's approved configuration and "
        "permissions (Annex J, Important scope interpretation). Acceptance is of the configured "
        "System, not of a general product claim.",
    )

    # Article 6 dates
    set_text_keep_runs(
        para_by_prefix(doc, "6.3\tMilestone M3 and every later Milestone"),
        "6.3\tMilestone M3 and every later Milestone depend on the Client's physical server being "
        "installed in its room, powered, and on the network by the date in Annex D (or such later "
        "date as the Parties record at kick-off if the Effective Date falls after a printed target "
        "date) and on the Client's other inputs being delivered by the dates in Section 15 of the "
        "Inception Report, as confirmed at kick-off. If an input is late, the Milestones that depend "
        "on it move by the same number of Working Days without penalty to the Service Provider, and "
        "the Service Provider shall not place Client Data on the Cloud Node as a master copy to save "
        "time. Annex J does not invent a delivery date; the dates in Annex B, as confirmed at "
        "kick-off under Article 6.4, are the contractual dates.",
    )

    # Article 7 additions
    set_text_keep_runs(
        para_by_prefix(doc, "(j)\tmaintain the Cloud Node"),
        "(j)\tmaintain the Cloud Node, apply updates with notice in the project group, and update "
        "the School Node in a maintenance window agreed with the IT Administrator, without materially "
        "altering permissions, data location, or core workflows without prior notice and an agreed "
        "validation or rollback;",
    )
    p7j = para_by_prefix(doc, "(j)\tmaintain the Cloud Node")
    p = insert_after(
        p7j,
        "(k)\tdeliver the Data-Placement Matrix, hybrid architecture and data-flow diagrams, "
        "hardening and remote-support procedures, subprocessor list, and incident-escalation "
        "procedure as part of Deliverable D3 / D7;",
    )
    p = insert_after(
        p,
        "(l)\tconfigure multi-factor authentication for privileged accounts (School Admin, IT "
        "Administrator, and such leadership roles as the Parties record in the role-permission "
        "matrix). Classroom teachers, parents, and students are not required to enrol MFA as a "
        "condition of using the System;",
    )
    insert_after(
        p,
        "(m)\tdemonstrate, before Go-Live, the hybrid workflow tests in Annex J, Sections 9.1.1 and "
        "14: sensitive-record isolation on the School Node; approved publication only; role and "
        "tenant separation; connectivity interruption and restoration; and that supplier support "
        "cannot browse named sensitive records from the Cloud Node console.",
    )

    # Article 8 hardware approval
    set_text_keep_runs(
        para_by_prefix(doc, "(b)\tprocure, install, and maintain"),
        "(b)\tprocure, install, and maintain at its own cost the physical server, UPS, server room, "
        "network, internet line, sub-domain, and backup disks specified in Annex D, after written "
        "approval of that specification at kick-off (Annex J, Sections 9.1.1 and 18). Annex D is the "
        "approved specification unless the Parties sign a replacement. The Service Provider shall not "
        "commit the Client to unapproved hardware or recurring third-party costs. Target readiness "
        "is the Annex D date or the kick-off date substituted under Article 6.3;",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "(i)\tobtain any consents from parents"),
        "(i)\tobtain any consents from parents and staff required under applicable law for the "
        "processing of their personal data in the System, including authorisation before publication "
        "of identifiable student images in Gallery or similar parent-facing views; and",
    )

    # Article 9 rewrite/expand
    set_text_keep_runs(
        para_by_prefix(doc, "9.1\tThe System shall be implemented under the Hybrid Implementation"),
        "9.1\tThe System shall be implemented under the Hybrid Implementation. The School Node at "
        "the Client's premises is the authoritative source for sensitive records: student identity "
        "and family/guardian details; admissions and alumni records that identify students; marks, "
        "examinations and report cards; attendance; health, counseling, IEP and safeguarding; "
        "discipline and grievances; and sensitive student documents. The Cloud Node may host "
        "application delivery, software updates, login routing, training materials, and limited "
        "system-health diagnostics that do not expose named student records. Announcements, gallery "
        "items, and parent-facing views may be published or copied to the Cloud Node only after the "
        "Client's express approval of the content and of the Data-Placement Matrix. Draft marks, "
        "unpublished report cards, safeguarding case files, counseling notes, and raw student "
        "documents shall not be stored as a cloud master copy or exposed through cloud administration "
        "tools. A parent-facing copy of an approved report may be released only after the authorised "
        "approval step; the Service Provider shall document what is transferred, how long any copy "
        "remains, and how it is deleted.",
    )
    p91 = para_by_prefix(doc, "9.1\tThe System shall be implemented under the Hybrid Implementation")
    p = insert_after(
        p91,
        "9.1A\tBefore any production Client Data is loaded, the Parties shall sign the Data-Placement "
        "Matrix (Deliverable D3). A change of production system, data location, or backup destination "
        "requires the Client's prior written approval. The Cloud Node shall not have unrestricted "
        "file-share or database access to the School Node. Communication is through an encrypted "
        "HTTPS/TLS tunnel (or another mechanism the Client approves in writing). Off-campus access "
        "uses an outbound tunnel on the Client's sub-domain; no inbound port is opened on the "
        "Client's router.",
    )
    p = insert_after(
        p,
        "9.1B\tThe Service Provider shall document, and demonstrate at UAT, the behaviour of critical "
        "workflows when the school loses internet connectivity, when the School Node is unavailable, "
        "or when the Cloud Node link fails. Staff already signed in on the campus LAN continue to "
        "work on the School Node during an internet outage; new cloud sign-ins and off-campus parent "
        "access wait for the line to return. Offline attendance or mark entry is claimed only to the "
        "extent demonstrated in those tests.",
    )
    insert_after(
        p,
        "9.1C\tBackups: encrypted nightly copy of the School Node to the Client's disks, plus a "
        "weekly off-site disk swap under Annex D. The “Friday snapshot” mentioned in background "
        "addenda is not the contractual frequency. Recovery-point objective: one (1) calendar day. "
        "Recovery-time objective: eight (8) hours for restore of the School Node from the latest "
        "good backup, subject to the Client having kept the disks and the room. A restore test is "
        "Deliverable D7 and is required before Go-Live.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "9.3\tUsers sign in once at the Cloud Node"),
        "9.3\tUsers sign in once at the Cloud Node; the School Node accepts sessions signed by the "
        "Cloud Node. The session-signing key is held by both Parties. Row-level security and the "
        "approved role-permission matrix apply on both nodes. The same School ID and student "
        "identifier are used across included Modules. The Service Provider shall demonstrate that "
        "the hybrid design does not create duplicate student identities, weaken role permissions, or "
        "permit another school's tenant to read the Client's records.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "9.4\tOff-campus access to the School Node"),
        "9.4\tOff-campus access to the School Node is provided through an outbound encrypted tunnel "
        "on the Client's sub-domain; no inbound port is opened on the Client's router. On campus, "
        "staff reach the School Node over the LAN. Outage behaviour is as demonstrated under "
        "Article 9.1B.",
    )

    # Article 10 testing
    set_text_keep_runs(
        para_by_prefix(doc, "10.3\tUAT is run by the Client's officers"),
        "10.3\tUAT is run by the Client's officers using the scenarios in Section 13 of the Inception "
        "Report and the minimum checklist in Annex J, Appendix B, on the Client's own data under the "
        "Client's control. Testing includes functional, integration, permission (positive and "
        "negative), migration reconciliation, security, compatibility, recovery, and hybrid-hosting "
        "tests as listed in Annex J, Section 14. Performance is tested against an agreed user-load "
        "profile; the former target of 1,000 concurrent users and 99.5% availability are operating "
        "targets to be validated and evidenced, not certificates already proven in a laboratory. "
        "Defects are logged with a severity. The Service Provider fixes defects and the Client retests.",
    )
    set_text_keep_runs(
        para_by_prefix(doc, "10.4\tAcceptance and Go-Live criteria"),
        "10.4\tAcceptance and Go-Live criteria: no open Severity-1 or Severity-2 (Critical or High) "
        "defect unless the Client formally accepts a documented workaround; at least ninety percent "
        "(90%) of scenarios passed first time and one hundred percent (100%) after retest; the "
        "forty-nine (49) included Modules configured and demonstrated; the ten (10) Excluded Modules "
        "disabled or inaccessible; roster signed; officers trained; restore drill passed; hybrid "
        "tests in Article 7.1(m) passed; Data-Placement Matrix signed; support card in every office. "
        "On fulfilment, the Client signs the acceptance certificate (D9) and, on the agreed Go-Live "
        "date, the Go-Live Certificate (D10). Go-Live approval and final handover (D11) are separate "
        "from any assertion that a live product already exists.",
    )

    # Article 12 support mapping
    p125 = para_by_prefix(doc, "12.5\tSupport, hosting of the Cloud Node")
    insert_after(
        p125,
        "12.6\tEach reported issue is given a ticket or reference number with severity, owner, "
        "status, action, and closure. Planned maintenance is notified in writing in advance. "
        "Suspected security incidents and data exposure are escalated immediately through the "
        "incident channel in Deliverable D7, without waiting for routine ticket handling. The "
        "severity table in this Article corresponds to Annex J, Section 16 (P1–P4). The hours in "
        "Article 12.3 (Monday to Saturday, 09:00 to 18:00 East Africa Time) are the contracted "
        "support hours.",
    )

    # Article 13 privacy extras
    set_text_keep_runs(
        para_by_prefix(doc, "13.2\tThe Service Provider shall process personal data"),
        "13.2\tThe Service Provider shall process personal data in the System only on the documented "
        "instructions of the Client and in compliance with the Personal Data Protection Proclamation "
        "No. 1321/2024 of Ethiopia and other applicable law; shall implement the technical and "
        "organisational measures in Section 12 of the Inception Report and Annex J, Section 10 "
        "(TLS encryption, disk and backup encryption, row-level security, audit logs, key custody, "
        "least privilege); shall ensure its personnel are bound by confidentiality; shall notify the "
        "Client immediately of a suspected security incident and, in any case within forty-eight (48) "
        "hours, of any personal data breach of which it becomes aware; shall disclose subprocessors "
        "and the hosting country or region of each Cloud Node component; and shall assist the Client "
        "in responding to requests of data subjects. Supplier access to the School Node is "
        "individually assigned, authorised by the Client, limited in time and task, logged, and "
        "revoked when no longer needed.",
    )
    p133 = para_by_prefix(doc, "13.3\tSafeguarding, counseling, and health records")
    insert_after(
        p133,
        "13.5\tPhotographs of identifiable students shall not be published in Gallery or other "
        "parent-facing views without the Client's authorisation. Demonstrations and development use "
        "fictitious or masked data wherever practicable.",
    )

    # Article 15 excluded modules
    set_text_keep_runs(
        para_by_prefix(doc, "15.2\tChanges that are configuration"),
        "15.2\tChanges that are configuration within the existing Modules, correct a defect, or are "
        "required for compliance with the Inception Report or Annex J are made at no extra charge. "
        "New Modules (including any Excluded Module), new integrations, new reports beyond the "
        "configured templates, or re-work caused by late or inaccurate Client inputs are priced in "
        "the variation order by reference to the unit prices in Annex A or at a daily rate to be "
        "agreed. No e-mail, demonstration, verbal request, or product update alone changes the "
        "contracted scope.",
    )

    # Annex A intro
    set_text_keep_runs(
        para_by_prefix(doc, "Forty-nine (49) Modules of MaJo e-School Bridge licensed"),
        "Forty-nine (49) Modules of MaJo e-School Bridge licensed under this Agreement at the "
        "published unit prices of Financial Proposal MBT-LIA-FIN-2026-02 (VAT exclusive), being the "
        "same included register as Annex J, Appendix A. The “Cat.” number is the supplier catalogue "
        "number; gaps 3, 4, 33, 35, 36, 39, 40, 41, 42 and 56 are the Excluded Modules. The four "
        "login portals are included at no module charge; the Driver portal remains disabled under "
        "Article 3.2. The “Confirmed” column is ticked at the kick-off meeting in accordance with "
        "Article 3.3.",
    )

    # Annex A module table — add catalogue numbers
    mod_table = doc.tables[6]
    for row in mod_table.rows[1:]:
        name = row.cells[1].text.strip()
        if name in CATALOGUE:
            cat = CATALOGUE[name]
            row.cells[1].text = f"{name}  (cat. {cat})"

    # Insert exclusions note after annex A portals table? We'll add paragraph after Annex A intro
    p_price = para_by_prefix(doc, "Price categories:")
    insert_after(
        p_price,
        "Excluded (not licensed, not configured, not charged): Campus Management (cat. 3); CCTV "
        "(cat. 4); Finance (cat. 33); Human Resource (cat. 35); Payroll (cat. 36); Transport "
        "(cat. 39); Buses (cat. 40); Live GPS (cat. 41); Register Driver (cat. 42); Digital "
        "Operations (cat. 56); Driver portal.",
    )

    # Annex B deliverable cells
    dtable = doc.tables[8]
    # D3
    dtable.rows[3].cells[1].text = "Hybrid environment / hosting and architecture pack"
    dtable.rows[3].cells[2].text = (
        "School Node installed on the LIA server; Cloud Node prepared; encrypted tunnel and "
        "sub-domain; one-login test; Data-Placement Matrix; architecture and data-flow diagrams; "
        "network/firewall/certificate notes; responsibility matrix; backup job; as-built sheet "
        "(Annex J D3)"
    )
    # D4
    dtable.rows[4].cells[2].text = (
        "School record, academic year, terms (including Pearson structure if directed), grading "
        "schemes, approval chains, role-permission matrix, branding, customizations from D2; "
        "Excluded Modules disabled or inaccessible"
    )
    # D6
    dtable.rows[6].cells[2].text = (
        "Sessions per the Training Modules (MBT-LIA-TRN-2026-01), attendance sheets, in-app manuals, "
        "train-the-trainer; role-based practical exercises; explanation of included vs excluded "
        "workflows (Annex J §15)"
    )
    # D7
    dtable.rows[7].cells[1].text = "Restore drill, security and access-control pack"
    dtable.rows[7].cells[2].text = (
        "Backup restored to a test copy and verified; nightly + weekly-disk procedure; incident "
        "escalation; subprocessor list; MFA on privileged accounts; permission test evidence "
        "(positive and negative); privacy/data-handling notes (Annex J D7)"
    )
    # D8 add integration
    dtable.rows[8].cells[2].text = (
        "Two weeks of one section live: usage, issues found and fixed, parent-link results; "
        "integration checks among included Modules (SIS ↔ admissions/parents/transfers; exams ↔ "
        "markbook ↔ report cards; attendance ↔ at-risk; inventory without Finance)"
    )
    # D9
    dtable.rows[9].cells[2].text = (
        "Scripted scenarios run by LIA officers (Inception Report §13 and Annex J Appendix B), "
        "defect log, retest results, hybrid-hosting tests, performance-profile record, exit-criteria "
        "check"
    )
    # D11
    dtable.rows[11].cells[1].text = "Hypercare closure, operations handover and final acceptance"
    dtable.rows[11].cells[2].text = (
        "Open issues with owners, support channels, escalation path, operations handbook, export "
        "instructions, account handover, list of delivered Modules, known limitations "
        "(Annex J D11–D12)"
    )

    # Annex D intro
    set_text_keep_runs(
        para_by_prefix(doc, "Procured, installed, and maintained by the Client"),
        "Procured, installed, and maintained by the Client at its own cost (Article 8.1(b)), after "
        "written approval of this specification at kick-off. The Service Provider installs the School "
        "Node software on this server with the Client's IT Administrator present. Full detail in "
        "Annex D of the Inception Report. The Service Provider shall not treat background-addendum "
        "mentions of equipment as a Client commitment until this Annex (or a signed replacement) is "
        "approved.",
    )

    # Annex G mention of 3.3 now exists
    set_text_keep_runs(
        para_by_prefix(doc, "Document MBT-LIA-FIN-2026-02"),
        "Document MBT-LIA-FIN-2026-02, “Financial Proposal — One-time module licence and "
        "implementation”, of 16 October 2026, five (5) pages, Schedules A and B. Attached for the "
        "record of unit prices and the recalculation rule in Article 3.3. The 59-module total in any "
        "earlier catalogue is not applied. Where it conflicts with Articles 4 and 5 of this "
        "Agreement, this Agreement prevails.",
    )

    # New Annex J heading at end
    last = doc.paragraphs[-1]
    h = insert_after(last, "ANNEX J — LIA REVISED TOR (49 INCLUDED MODULES)", heading=True)
    h.style = "Heading 1"
    p = insert_after(
        h,
        "The document entitled “TERMS OF REFERENCE — Implementation, Configuration, Integration, "
        "Deployment and Support of the MaJo e-School Bridge Platform — Revised Scope: 49 Included "
        "Modules”, Version 1.0, October 2026, prepared for Lebawi International Academy, including "
        "Appendix A (module register) and Appendix B (minimum UAT checklist), is attached hereto and "
        "initialled on every page by both Parties. File copy: "
        "docs/agreements/LIA_MaJo_Bridge_Revised_TOR_49_Modules.pdf. It is the functional and "
        "technical acceptance baseline under Article 2.2.",
    )
    insert_after(
        p,
        "In case of inconsistency: this Agreement (especially Articles 4, 5, 11, 12 and 19) governs "
        "price, payment, licence, support hours already stated, and liability; Annex J governs the "
        "forty-nine (49) included Modules, the ten (10) exclusions, hybrid data placement, testing, "
        "and handover contents.",
    )

    doc.core_properties.title = (
        "MBT-LIA-AGR-2026-01 Rev. 1.1 — Software Licence and Implementation Agreement"
    )
    doc.core_properties.subject = (
        "Amended to incorporate LIA Revised TOR 49 Modules (October 2026)"
    )
    doc.core_properties.revision = 2

    doc.save(str(OUT))
    print("wrote", OUT, OUT.stat().st_size)


if __name__ == "__main__":
    main()

# LIA Revised TOR (49 modules) vs MaJo–LIA Agreement

**Sources.** Client TOR: October 2026, 49 included / 10 excluded. Agreement we prepared: `MBT-LIA-AGR-2026-01` (unsigned Word). **Amendment issued:** Revision 1.1 of 10 November 2026 (`MBT-LIA-AGR-2026-01_Rev1.1.docx`).

Price, payment (40/40/20), licence, and the 49-module total **4,456,250 ETB VAT inclusive** are unchanged.

## What already matched (no commercial change)

| TOR need | Already in Rev 1.0 |
| --- | --- |
| 49 modules, four portals | Art. 1, 3.1, Annex A |
| Same ten exclusions (Campus, CCTV, Finance, HR, Payroll, Transport, Buses, GPS, Register Driver, Digital Ops) | Art. 3.2 |
| Inventory included, not Finance | Annex A row 25 |
| Hybrid: LIA server holds student records; MaJo self-hosted cloud is not a second SIS | Art. 9 |
| Client owns data; export on exit | Art. 9.2, 9.5 |
| 12-month free support, Mon–Sat 09:00–18:00 EAT, severity table | Art. 12 |
| No SMS / gateway / post-support hosting in the lump sum | Art. 3.2, 4.3, 12.5 |
| Safeguarding off parent/student views | Art. 13.3 |
| UAT then go-live certificates | Art. 10, Annex B |

## Gaps closed in Revision 1.1 (doable on our side)

| TOR gap | What Rev 1.1 does |
| --- | --- |
| TOR not a contract document | **Annex J** + Art. 2.1(k). TOR governs functional/technical acceptance; Articles 4–5 still govern money. |
| Missing **Article 3.3** (Annex A already pointed at it) | Recalculation if a module is dropped before M2; adding an excluded module needs a priced variation. |
| Hide excluded desks so they are not UAT blockers | Art. 3.4; D4 must disable them. Driver portal stays off, **no charge**. |
| Catalogue numbers vs our 1–49 list | Annex A names now show **cat. N** matching TOR Appendix A. |
| Data-placement matrix before production data | Definition + Art. 9.1 / 9.1A; expanded D3. |
| Published parent copies only after approval; no cloud master of drafts/safeguarding | Art. 9.1 tightened to TOR §9.1.1. |
| Nightly backup vs “Friday snapshot” | Art. 9.1C: nightly + weekly off-site disk; RPO 1 day; RTO 8 hours; D7 restore still required. |
| Hardware not committed until spec approved | Art. 8.1(b), Annex D: Annex D **is** the spec; MaJo does not buy the server. |
| MFA for privileged accounts, not teachers | Art. 7.1(l). |
| Maya Assistant / external AI | Art. 3.5: no live Client Data until written approval. |
| Hybrid UAT (isolation, publish, outage) | Art. 7.1(m), 10.3–10.4, Annex J Appendix B folded into D9. |
| 1,000 users / 99.5% as unproven claims | Art. 10.3: operating targets to validate, not a lab certificate. |
| Subprocessors, incident immediacy, gallery photos | Art. 13.2, 13.5. |
| Integration tests among included modules only | D8 expanded; no Finance/transport integration. |
| Dates already printed (6 Nov 2026) if signature is later | Art. 6.3: kick-off may reset Client-input dates. |

## What we did **not** take on

| TOR / addendum ask | Why not in the contract |
| --- | --- |
| MaJo procures server, UPS, or internet | TOR §18: LIA is not forced to buy until spec is approved — that is LIA’s buy, not ours. Annex D stays Client-provided. |
| Enable any of the ten excluded modules | Out of the 4.456m price. Variation + price if they want them later. |
| Transport / live GPS from Hybrid Addendum A | TOR forbids it. Art. 2.3. |
| Put LIA data on shared MaJo Supabase (`hwkiihonthueadbhcvfi`) | Forbidden. Cloud Node is **our self-hosted** node with no student master. |
| Treat 1,000 concurrent / 99.5% as already proven | We will test an agreed profile; we will not certify a number we have not evidenced on LIA’s stack. |
| Activate Maya Assistant on live student records at signing | Included module, **off** until LIA writes yes after disclosure. |
| Recurring hosting / SMS / gateways inside the lump sum | Already excluded; TOR asked us to keep them explicit. |

## Product note (implementation, not extra licence)

MayaBela already ships the 49 included desks. Revision 1.1 commits us to **configure them for LIA, hide the ten exclusions, prove hybrid placement, and pass LIA’s Appendix B UAT**. That is doable. The remaining work is LIA’s server, templates, and named approvers — not new product modules.

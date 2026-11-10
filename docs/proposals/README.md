# Proposals

## Lebawi International Academy — technical proposal

Prepared by **Majo Bridge Technologies and Events** for **Lebawi International Academy**.

- PDF: [MaJo_Bridge_LIA_Technical_Proposal.pdf](MaJo_Bridge_LIA_Technical_Proposal.pdf)
- Printable HTML: [lia-academic-management-technical-proposal.html](lia-academic-management-technical-proposal.html)

The document lists the live 55+ modules and maps the LIA Terms of Reference to the shipped MaJo e-School Bridge desks.

## Lebawi International Academy — hybrid hosting

Physical server in the school **plus** an LIA-owned self-hosted cloud VM (never the MaJo shared Supabase project).

- Printable HTML: [lia-hybrid-hosting-architecture.html](lia-hybrid-hosting-architecture.html)
- PDF: [MaJo_Bridge_LIA_Hybrid_Hosting_Architecture.pdf](MaJo_Bridge_LIA_Hybrid_Hosting_Architecture.pdf)

Recommended option: campus Postgres primary, cloud public proxy + replica, one Flutter API URL. Modules join in `app_documents`; do not split desks across two live writers.

# EDUABA ERP — CURSOR APP DEVELOPMENT INSTRUCTIONS

Use this document as the **SOURCE OF TRUTH** when building the EDUABA ERP app.
Implement ALL roles, wiring, functionality, and cloud sync exactly as specified.
Do not invent alternate hierarchies. Do not skip sync, chat wiring, or approval flows.

## 0. Non-negotiable engineering goals

1. Role hierarchy and privileges must match Section 1 exactly.
2. All module wiring must be automatic based on role + relationships.
3. Active cloud sync must run every **5 seconds** while authenticated/online.
4. Sync must be efficient: delta/incremental, role-scoped, no full dumps every tick.
5. UI must stay live when remote data changes.
6. Offline must queue mutations and reconcile safely when back online.
7. Every feature must be covered by data models, APIs, permissions, and sync channels.

## 1. Organizational structure

```
MAJO BRIDGE TECHNOLOGY (System Owner)
→ SCHOOL OWNER / BOARD
→ GENERAL MANAGER
→ DEPUTY GENERAL MANAGER
   ├── PRINCIPAL
   │     → VICE PRINCIPAL
   │           ├── STUDENT AFFAIRS
   │           ├── SECTION DIRECTOR
   │           │     ├── SUBJECT TEACHER
   │           │     └── HOMEROOM TEACHER
   │           └── REGISTRAR
   ├── QUALITY ASSURANCE
   ├── FINANCE MANAGER
   │     → PROCUREMENT
   │           → STORE KEEPER
   └── HUMAN RESOURCES
         ├── TRANSPORT HEAD
         │     → DRIVER
         └── STAFFS
```

External: PARENT, STUDENT

## 2–4. Capabilities, flows, chat

See product conversation for full privilege matrices, grade/attendance/parent-link/ebook/transport/inventory/discipline flows, and permissioned chat channels.

## 5. Cloud sync (mandatory)

### Behavior
- Background CloudSyncEngine every 5s while session authenticated.
- Keep local cache fresh for role-visible modules.
- UI auto-refresh from reactive local store.
- Global service (not page-mounted).

### Efficiency
1. Incremental / delta (`last_sync_at` / sync_cursor / collection versions)
2. Role-scoped channels
3. Entity subscriptions (class_id, student_ids, route_id, …)
4. Compact payloads / patches
5. Conditional requests (ETag / version hash → 304)
6. Batch multiplex across collections
7. Priority lanes (chat, attendance, GPS, notifications, approvals high)
8. Write-behind outbox each tick
9. Conflict: server authoritative for approvals/fees/GPS/final attendance; never overwrite approved/published grades client-side
10. Backoff when offline; resume 5s when healthy; idempotency keys
11. Skip empty no-op via cursors; compress; gallery metadata-first
12. Auth token + server RBAC

### Architecture
```
login → start CloudSyncEngine
every 5s:
  1) flush outbox
  2) pull delta by cursor + role scope
  3) apply patches to local store
  4) emit reactive UI updates
  5) advance sync_cursor
```

Optional WebSocket/push acceleration; **5s reconciliation remains required**.

## 6–7. Checklist & acceptance tests

See product conversation for checklist items 1–14 and acceptance tests 1–12.

## 8. Hierarchy snapshot

Majo Bridge → School Owner/Board → GM → Deputy GM  
├── Principal → VP → Student Affairs | Section Director | Registrar  
│                         └── Subject Teacher | Homeroom Teacher  
├── Quality Assurance  
├── Finance Manager → Procurement → Store Keeper  
└── HR → Transport Head → Driver  
       └── Staffs  

External: Parent, Student

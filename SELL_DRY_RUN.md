# MayaBela customer dry-run checklist

Use this on **https://mayabela.pages.dev** (hard-refresh: Ctrl+Shift+R) with school **TB-001** (or your pilot school).

Mark each row Pass / Fail. Fix Fail before selling.

## 0. Security sign-off (already verified)

| Check | Expected | Result |
|-------|----------|--------|
| Anon key cannot list school docs | 0 rows / denied | ☐ |
| User A school only sees A data | No cross-school rows | ☐ |
| Cross-school write | 403 / denied | ☐ |
| `auth_secrets` not readable by clients | Empty / denied | ☐ |

## 1. First login & password (no OTP)

| Step | Expected | Result |
|------|----------|--------|
| Enroll a new teacher/staff with temp password | Unique temp (≥10 chars) shown once | ☐ |
| First login | Forced **Change password** screen | ☐ |
| Change password | Current (if not forced) + new + confirm — **no OTP** | ☐ |
| Login again with new password | Dashboard opens; no forced change | ☐ |
| Settings → Change password | Changes without OTP | ☐ |

## 2. Grades: enter → approve → parent sees

| Step | Expected | Result |
|------|----------|--------|
| Teacher enters subject grade | Score saved as draft | ☐ |
| Teacher submits / publish | Status = pending approval (not parent-visible) | ☐ |
| Section Director opens approval queue | Pending item visible | ☐ |
| SD approves | Status approved + published to parents | ☐ |
| Linked parent opens grades | Sees approved grade only | ☐ |

## 3. Parent link

| Step | Expected | Result |
|------|----------|--------|
| Parent signs up / links with student ID + correct DOB | Pending link created | ☐ |
| Wrong DOB | Rejected; no link | ☐ |
| Owner / registrar / SD approves link | Parent can open child modules | ☐ |
| Rejected link | Parent stays blocked for that child | ☐ |

## 4. Attendance

| Step | Expected | Result |
|------|----------|--------|
| Teacher saves class attendance (P/A/L) | Session saved for that date | ☐ |
| Admin attendance report (day) | Counts match session | ☐ |
| Admin / reports range export | Present/absent/late totals sensible | ☐ |

## 5. Transport / GPS

| Step | Expected | Result |
|------|----------|--------|
| Bus exists for school; driver assigned | Bus + driver on transport pages | ☐ |
| Driver shares live location (device GPS) | Parent map shows fresh position | ☐ |
| Stop sharing / stale (>2 min) | Position not treated as live | ☐ |

## 6. Ops polish (quick)

| Step | Expected | Result |
|------|----------|--------|
| Finance dashboard charts | Last-7-days income from real paid fees | ☐ |
| Institution / School pages | Real pages (not “Coming soon”) | ☐ |
| Reports → PDF | Downloads a real `.pdf` | ☐ |
| Procurement / storekeeper inventory | Live stock updates across sessions | ☐ |
| Librarian messaging | Can message VP / SD / QA | ☐ |

## 7. Sell package (non-code)

Full pack: [`docs/SELL_PACKAGE.md`](docs/SELL_PACKAGE.md) · School handout: [`docs/SUPPORT_NOTE_FOR_SCHOOL.md`](docs/SUPPORT_NOTE_FOR_SCHOOL.md)

| Item | Done |
|------|------|
| Demo school + sample roster ready for demo | ☐ |
| Pricing / contract / seats (see sell package §1) | ☐ |
| Onboarding: create school → roles → first passwords (§3) | ☐ |
| Support note shared with school admin | ☐ |
| Pilot on web (APK optional — see sell package §4 if build fails) | ☐ |
| Supabase backup / production project confirmed | ☐ |

## Automated coverage

Run locally:

```bash
flutter test test/sell_critical_flows_test.dart test/polish_pass_1_7_test.dart
flutter test --tags sell_audit
```

These cover grade approve→publish, parent link, attendance, GPS positions, and polish 1–7 offline.

---

## Results log — 4 Aug 2026 (agent + prior session)

| Section | Result | Notes |
|---------|--------|-------|
| 0. Security / RLS | **Pass** | Prior live verify: anon=0, school isolation, cross-write 403 |
| 1–5 Critical flows | **Pass (automated)** | `test/sell_critical_flows_test.dart` green |
| 6. Ops polish | **Pass (automated)** | `test/polish_pass_1_7_test.dart` green |
| Live login page | **Pass** | https://mayabela.pages.dev loads; School ID / phone / password fields present |
| Live full role walk (1–6 interactive) | **Needs you** | Flutter web role dropdown + cloud password not completed in agent browser (DOM/canvas desync). Log in as **Owner** with school admin credentials and tick rows above. |
| 7. Sell package | **In progress** | Quote filled; WhatsApp support draft ready — send via link below |

**Send support note (WhatsApp to school admin 0911000003):**  
Open [`docs/PILOT_WHATSAPP_LINK.txt`](docs/PILOT_WHATSAPP_LINK.txt) or message text in [`docs/PILOT_WHATSAPP_MESSAGE.txt`](docs/PILOT_WHATSAPP_MESSAGE.txt).  
Also attach [`docs/SUPPORT_NOTE_FOR_SCHOOL.md`](docs/SUPPORT_NOTE_FOR_SCHOOL.md).

**First-customer quote:** [`docs/FIRST_CUSTOMER_QUOTE.md`](docs/FIRST_CUSTOMER_QUOTE.md)

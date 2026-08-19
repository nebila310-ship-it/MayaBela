# MayaBela sell package

Customer-facing commercial pack for pilots and paid schools.  
Live web: **https://mayabela.pages.dev**  
Support: **+251 911 646 444** · `nabilmaya6464@gmail.com`

---

## 1. Pricing (ETB)

Matches Platform Console billing fields (`ratePerStudentMonthEtb`, `minimumMonthlyEtb`, `contractedSeats`).

### Standard (default in product)

| Item | Amount |
|------|--------|
| Per active student / month | **8 ETB** |
| Minimum monthly bill | **500 ETB** |
| Formula | `max(activeStudents × rate, minimum)` when students > 0; **0** if no students |

**Examples**

| Active students | Monthly bill |
|-----------------|--------------|
| 0 | 0 ETB |
| 40 | 500 ETB (minimum) |
| 100 | 800 ETB |
| 500 | 4,000 ETB |

### Contract seats (optional)

Set **contracted seats** in Platform Console to cap the sold capacity.  
Overage is flagged in the console (school can still operate; you invoice the overage or raise the seat cap).

### Suggested commercial tiers (for quotes)

Use these as proposal language; store the chosen rate on the school record.

| Tier | Seats | Rate / student / mo | Min monthly | Notes |
|------|-------|---------------------|-------------|--------|
| **Pilot** | ≤ 150 | 8 ETB | 500 ETB | 30–60 days, APK + web |
| **Standard** | ≤ 500 | 8 ETB | 500 ETB | Full modules |
| **Campus+** | custom | negotiated (≥ 8) | negotiated | Multi-campus, training |

Annual option (optional quote): **10 months prepaid = 2 months courtesy** on the estimated monthly bill.

### What’s billed

- Billable = **active / enrolled** students for that school  
- Teachers, parents, drivers, staff accounts are **not** billed per seat  
- Inactive / transferred-out students are not billable

---

## 2. What’s included vs not

### Included

- Web ERP (owner / staff) at mayabela.pages.dev  
- Mobile / pilot APK for parents, teachers, drivers, staff  
- School isolation (RLS), roles & permissions (EDUABA matrix)  
- Students, attendance, grades (approve → publish), parent links  
- Fees view, transport / bus live location, inventory & procurement  
- Reports (Excel / CSV / PDF), announcements, messaging, Maya Assistant  
- Platform Console: create school, seats, rate, subscription expiry  
- Unique temp passwords; forced first-login change (**no OTP** for password change)  
- Onboarding checklist in Platform Console  

### Not included (unless separately contracted)

- Custom development / new modules  
- On-site hardware (biometric devices, school servers)  
- SMS / voice gateway fees (carrier or third-party)  
- Google Play / App Store developer account fees  
- Data migration from a third-party SIS beyond the agreed pilot scope  
- 24/7 phone SLA (see support hours below)

---

## 3. Onboarding (create school → go-live)

### A. You (Maya / Platform owner) — Day 0

1. Open **Platform Console** (Majo Bridge / owner login).  
2. **Add school**: School ID, name, city, grades, campuses.  
3. Set **rate**, **minimum monthly**, **contracted seats**, **subscription expiry**.  
4. Set school **admin phone** + **initial temp password** (unique; share once).  
5. Confirm school status = **Active** and subscription not expired.  
6. Watch Platform Console **Onboarding** checklist until complete:
   logo → admin credentials → first student → first parent linked → school active.

### B. School admin — Day 1

1. Web login: School ID + admin phone + temp password.  
2. **Change password** (no OTP) — required on first login.  
3. Create structure: campuses, classes/sections if needed.  
4. Enroll **students** (IDs + DOB — parents need DOB to link).  
5. Add **classroom teachers** and **administration staff** (role-initial IDs).  
6. Share each new user’s temp password once; they must change on first login.  
7. Approve first **parent link** requests.  
8. Optional: buses + drivers; assign Bus Link IDs for parents.

### C. First operational week

| Day | Owner / admin focus |
|-----|---------------------|
| 1 | Rosters + staff logins working |
| 2 | Teachers: attendance + enter grades |
| 3 | Section Director: approve grades → parents see |
| 4 | Parents: link child + fees + bus (if used) |
| 5 | Reports PDF/Excel; inventory smoke if used |

Full acceptance walkthrough: [`../SELL_DRY_RUN.md`](../SELL_DRY_RUN.md).

### Go-live handoff sheet (fill per school)

```
School ID: _______________
School name: _______________
Admin name / phone: _______________
Temp password shared: [ ] yes (destroyed after change)
Rate / seats / expiry: _______________
Pilot contacts at school: _______________
Pilot end date: _______________
```

---

## 4. Pilot APK & store

### Pilot delivery (use web now)

**Primary pilot channel: web ERP** — https://mayabela.pages.dev  
No install. Hard-refresh after deploys: **Ctrl+Shift+R**.

### Pilot APK (Android sideload)

Script: `build-pilot-apk.cmd` → `build\app\outputs\flutter-apk\app-release.apk`  
App id: `com.mayabela.app` · version from `pubspec.yaml` (currently **1.0.3+4**).

```bat
cmd /c "set MAYABELA_NOPAUSE=1&& build-pilot-apk.cmd"
```

**Status (Aug 2026):** release APK build is **blocked** on Flutter **3.44.2** + AGP **9**  
(`flutter-gradle-plugin` → `afterEvaluate` after project already evaluated).  
`add_2_calendar` is pinned to **3.0.1** (3.1.1 also breaks AGP 9 script compilation).

Until that toolchain issue is fixed (Flutter upgrade or AGP workaround):

1. Run the school pilot on **web**  
2. Optionally give teachers/parents the web URL as a home-screen shortcut  
3. Re-run `build-pilot-apk.cmd` after a Flutter stable that supports AGP 9 cleanly

### Web (always available)

No install needed: **https://mayabela.pages.dev**  
Hard-refresh after deploys: **Ctrl+Shift+R**.

### Google Play / App Store (later)

| Step | Owner |
|------|--------|
| Create Play Console / Apple Developer account | You |
| Signing keystore (Android) — keep offline backup | You |
| Privacy policy URL + support URL | You (use this doc + phone) |
| Screenshots: parent, teacher, admin web | You / designer |
| Closed testing track → pilot school testers | You |
| iOS: TestFlight after Apple setup | Optional phase 2 |

Do **not** publish a public store listing until the school dry-run in `SELL_DRY_RUN.md` is signed off.

---

## 5. Support note (give to the school)

**MayaBela support**

- Phone / WhatsApp: **+251 911 646 444**  
- Email: **nabilmaya6464@gmail.com**  
- Web: https://mayabela.pages.dev  

**Hours:** Mon–Sat, 9:00–18:00 East Africa Time (urgent outages: call/WhatsApp).

**Before you contact us**

1. Note School ID and role (Owner / Teacher / Parent / Driver).  
2. Hard-refresh web (**Ctrl+Shift+R**) or reinstall pilot APK.  
3. Confirm password was changed after first login (min 10 characters).  
4. For parent link issues: student ID + exact date of birth.

**We help with**

- Login / password / first-time access  
- Role access (who can see which module)  
- Sync / “data missing” across devices  
- Pilot APK install and web ERP navigation  
- Billing fields (seats, rate, subscription expiry)

**School handles**

- Day-to-day student, grade, and attendance data entry  
- Approving parent links and grade workflows  
- Parent communication content  
- Local Wi‑Fi / device GPS permission for bus tracking  

**Security reminder**

- Never share the Platform Console owner password with school staff.  
- Share staff temp passwords once, then require change (no OTP needed).  
- Do not post School IDs + admin passwords in public groups.

---

## 6. One-page quote template

Blank template:

```
To: ___________________________ School
Re: MayaBela school management — Pilot / Standard

Access: Web ERP + pilot APK (Android)
Billing: ____ ETB / active student / month
         Minimum ____ ETB / month
         Contracted seats: ____
Subscription through: ____ / ____ / ______

Includes: [list from §2 Included]
Support: +251 911 646 444 · nabilmaya6464@gmail.com

Accepted by: _________________ Date: ________
MayaBela: _________________ Date: ________
```

### Filled quote — first customer (Maya School / TB-001)

```
To: Maya School (School ID: TB-001)
Re: MayaBela school management — Pilot

Access: Web ERP (https://mayabela.pages.dev)
        Android APK when toolchain build is unblocked (see §4)

Billing: 8 ETB / active student / month
         Minimum 500 ETB / month
         Contracted seats: 150 (Pilot tier)
Subscription through: 03 / 10 / 2026   (60-day pilot from 04 Aug 2026)

Includes:
- Web ERP (owner / staff)
- School isolation (RLS), EDUABA roles & permissions
- Students, attendance, grades (approve → publish), parent links
- Fees view, transport / bus live location, inventory & procurement
- Reports (Excel / CSV / PDF), announcements, messaging, Maya Assistant
- Unique temp passwords; forced first-login change (no OTP for password change)
- Support Mon–Sat 9:00–18:00 EAT

Not included: custom modules, SMS gateway fees, store listing fees, 24/7 SLA

Support: +251 911 646 444 · nabilmaya6464@gmail.com

Accepted by: _________________ Date: ________
MayaBela: _________________ Date: 04 / 08 / 2026
```

Standalone copy: [`FIRST_CUSTOMER_QUOTE.md`](FIRST_CUSTOMER_QUOTE.md)

---

## 7. Internal checklist before sending a quote

- [x] `SELL_DRY_RUN.md` started on production (login + TB-001; finish role walk with your owner login)
- [ ] Pilot APK built from current `pubspec` version (blocked — web pilot OK)
- [ ] School record: rate, min, seats, expiry set in Platform Console
- [ ] Admin temp password generated (unique) and ready to hand over once
- [ ] Support note (§5) shared with school admin — draft ready (`PILOT_WHATSAPP_MESSAGE.txt`)
- [ ] Supabase project backup / access confirmed

Related: [`SELL_DRY_RUN.md`](../SELL_DRY_RUN.md) · [`SUPABASE_SETUP.md`](../SUPABASE_SETUP.md)

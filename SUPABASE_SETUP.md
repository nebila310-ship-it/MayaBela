# MayaBela — Supabase setup

This project is a **copy** of eduaba. The original Firebase app at `C:\Users\nebil\eduaba` is untouched so you can compare both.

## 1. Create a Supabase project

1. Open [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Create a project (e.g. `mayabela`)
3. Copy **Project URL** and **anon public** key
4. Also copy the **service_role** key (server-only; never ship in the Flutter app)

## 2. Configure Flutter

Edit `lib/supabase_options.dart` or run with:

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## 3. Apply schema

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
```

Or paste `supabase/migrations/20260725120000_app_documents.sql` into the SQL editor.

## 4. Deploy edge functions

```bash
npx supabase functions deploy school-login
npx supabase functions deploy school-change-password
npx supabase functions deploy school-upsert-account
npx supabase functions deploy school-upsert-registry
npx supabase functions deploy school-delete-account
npx supabase functions deploy school-register-parent
npx supabase functions deploy school-request-password-reset
npx supabase functions deploy school-confirm-password-reset
npx supabase functions deploy school-refresh-claims
npx supabase functions deploy platform-owner-pin
npx supabase functions deploy platform-list-schools
npx supabase functions deploy platform-create-school
npx supabase functions deploy platform-update-school
npx supabase functions deploy platform-upload-logo
npx supabase functions deploy maya-assistant-chat
```

Optional secret for Maya AI:

```bash
npx supabase secrets set MAYA_AI_API_KEY=your_gemini_key
```

Password reset email (set SMTP **or** Resend; do not email the new password):

```bash
npx supabase secrets set MAIL_FROM="MayaBela <noreply@yourdomain.com>"
npx supabase secrets set SMTP_HOST=smtp.yourdomain.com
npx supabase secrets set SMTP_PORT=587
npx supabase secrets set SMTP_USER=your_smtp_user
npx supabase secrets set SMTP_PASS=your_smtp_password
```

If you use Resend instead of SMTP:

```bash
npx supabase secrets set MAIL_FROM="MayaBela <noreply@yourdomain.com>"
npx supabase secrets set RESEND_API_KEY=re_...
```

## 5. Migrate Firebase data (read-only on Firebase)

1. Place a Firebase **service account JSON** and set:

```bash
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccount.json
node tools/export_firestore.mjs
```

2. Import into Supabase:

```bash
set SUPABASE_URL=https://xxxx.supabase.co
set SUPABASE_SERVICE_ROLE_KEY=eyJ...
npm install @supabase/supabase-js firebase-admin
node tools/import_to_supabase.mjs
```

This **reads** Firebase only; it does not change the Firebase project.

## 6. Run MayaBela

```bash
flutter pub get
flutter run
```

Keep eduaba running against Firebase for side-by-side comparison.

## 6. Production hardening (phase 1–2)

Applied migration: `supabase/migrations/20260818120000_prod_hardening_phase1_2.sql`

**Push secret rotation** (required — old secret was removed from the trigger):

```bash
set SUPABASE_URL=https://hwkiihonthueadbhcvfi.supabase.co
set SUPABASE_SERVICE_ROLE_KEY=eyJ...
node tools/rotate_push_secret.mjs
```

Then set the printed value as `PUSH_TRIGGER_SECRET` in Supabase Edge secrets.

**Platform owner PIN:** edge functions now require plaintext `ownerPin` (never a downloaded hash). Unlock the platform console before list/create/update/logo.

## 7. Production hardening (phase 3)

Applied migration: `supabase/migrations/20260819120000_prod_hardening_phase3.sql`

- Document PK is `(collection, school_id, doc_id)` so two schools can both have `STU-1001`.
- Parents can **view** fees for linked children but cannot write fee rows.
- Parent attendance/homework reads match the child's class, not school-wide PII.
- Stale inventory/fee snapshots (older `updated_at`) are rejected instead of overwriting newer stock.

## 8. Remaining ops

**Push secret:** `node tools/rotate_push_secret.mjs --apply`

**Load test (staging only):** set `STAGING_SUPABASE_URL` + `STAGING_ANON_KEY`, then `tools\run_k6_staging.cmd`. Production project ref is blocked.


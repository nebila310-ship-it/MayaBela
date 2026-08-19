# MayaBela

School management app (parents, teachers, staff) — **Supabase** backend.

This is a full copy of the eduaba / MaJo e-School Bridge Flutter app. The original Firebase project at `C:\Users\nebil\eduaba` is left unchanged for comparison.

## Quick start

1. Follow [SUPABASE_SETUP.md](SUPABASE_SETUP.md) to create a project, push migrations, and deploy edge functions.
2. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `lib/supabase_options.dart` (or `--dart-define`).
3. Optionally migrate Firebase data with `tools/export_firestore.mjs` + `tools/import_to_supabase.mjs`.
4. Run:

```bash
flutter pub get
flutter run
```

## Package

- Flutter package name: `mayabela`
- Android applicationId: `com.mayabela.app`

## Sell / pilot

- Commercial pack (pricing, onboarding, APK, support): [docs/SELL_PACKAGE.md](docs/SELL_PACKAGE.md)
- School support handout: [docs/SUPPORT_NOTE_FOR_SCHOOL.md](docs/SUPPORT_NOTE_FOR_SCHOOL.md)
- Live dry-run checklist: [SELL_DRY_RUN.md](SELL_DRY_RUN.md)
- Pilot APK: `build-pilot-apk.cmd` → `build/app/outputs/flutter-apk/app-release.apk`
- Live web: https://mayabela.pages.dev

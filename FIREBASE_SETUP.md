# Firebase setup for eduaba

The app supports **Firebase Phone Auth (OTP)** and **Firestore sync** when configured. Without Firebase, it uses **SharedPreferences** for local persistence and **demo OTP**.

## 1. Create a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a project (e.g. `eduaba-school`)
3. Add an **Android** app with package name: `com.example.eduaba`
4. Add an **iOS** app if needed (bundle ID from Xcode)

## 2. FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
dart run flutterfire configure
```

This generates `lib/firebase_options.dart` and downloads `android/app/google-services.json`.

After configure, set in the generated `firebase_options.dart` (or add manually):

```dart
const bool kFirebaseConfigured = true;
```

## 3. Enable Phone Authentication

1. Firebase Console → **Authentication** → **Sign-in method**
2. Enable **Phone**
3. Add test phone numbers for development (optional)

## 4. Firestore

1. Firebase Console → **Firestore Database** → Create database
2. Start in **test mode** for development, then add security rules for production

Collections used by the app:

| Collection | Purpose |
|------------|---------|
| `app_auth_accounts` | Registered parent/staff accounts |
| `parent_link_requests` | Parent–child link requests (pending/approved/rejected) |
| `student_medical` | Medical info per student |
| `users`, `students`, … | Full school data via `FirestoreSchoolRepository` |

## 5. Build and test OTP

```bash
flutter pub get
flutter run
```

- **Forgot password** → Send OTP → enter SMS code
- **Settings → Change password** → same flow

On a real device with Firebase configured, SMS is sent by Firebase. Without Firebase, the app shows a **demo OTP** in the UI.

## 6. Persistence behavior

| Data | Local (always) | Firestore (when configured) |
|------|----------------|-----------------------------|
| New parent accounts | SharedPreferences | `app_auth_accounts` |
| Parent link requests | SharedPreferences | `parent_link_requests` |
| Student medical | SharedPreferences | `student_medical` |
| School roster | In-memory seed | Full Firestore sync |

Restart the app after parent signup — the account and pending link should still appear for admin approval.

## Troubleshooting

- **Gradle / google-services**: `google-services.json` must exist in `android/app/`. The Gradle plugin applies only when that file is present.
- **OTP not received**: Check Phone Auth is enabled, use a test number, or verify billing/SHA-1 in Firebase Console.
- **Firestore permission denied**: Update Firestore rules to allow authenticated or test reads/writes during development.

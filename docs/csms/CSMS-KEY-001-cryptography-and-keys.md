# CSMS-KEY-001 — Cryptography and key management

## In the client

- TLS is terminated by the hosted vendor. The app does not ship a private CA.
- The **anon / publishable** key is compiled into the client. It is not a secret; RLS is the boundary. Rotation: CSO issues a new anon key in the vendor console and a new app build; old JWTs expire.
- The **service-role** key is forbidden in Dart, HTML, and mobile binaries. `tools/insa_internal_evaluation.sh` greps for it.

## At the edge / database

- Passwords: bcrypt (school login) with a 10-character minimum.
- Platform-owner PIN: PBKDF2-SHA256, 210,000 iterations; legacy salted SHA-256 still verifies once then upgrades.
- Login rate-limit: 8 attempts / 15 minutes per username+role+school.
- MFA TOTP: 30-second window; recovery codes stored hashed.
- JWT school and role claims live in `app_metadata` only (`jwt_school_id()` ignores `user_metadata`).

## Rotation / incident

1. Suspected service-role leak: disable the key in the vendor console (P1, CSMS-IRP-001). Do not paste the key into chat.
2. Anon-key leak is not by itself a breach; confirm RLS still holds (run CAAT) then rotate if the key was also used to spam Auth.
3. PIN compromise: CSO sets a new PIN hash via the owner console; old PIN stops working.

Live schools keep working during anon-key rotation because both keys can overlap until the new build is out.

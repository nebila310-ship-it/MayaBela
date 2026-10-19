# Phase 1 security hardening — release notes

This branch contains security changes only. It has **not** been merged or deployed.

## Required deployment preparation (do not deploy until completed)

1. Configure a dedicated **non-production staging Supabase project** with the same migration set and Edge Functions as the release candidate.
2. Add repository Actions secrets:
   - `STAGING_SUPABASE_URL`
   - `STAGING_ANON_KEY`
   - `STAGING_SERVICE_ROLE_KEY`
3. Add repository Actions variables only after the dedicated disposable test project is ready:
   - `RLS_TEST_PROJECT_REF` — exact project ref matching the staging URL hostname.
   - `ALLOW_DESTRUCTIVE_RLS_TESTS=YES` — explicit opt-in acknowledging that the test seeds and deletes fixture data. Leave unset until the target is verified as a dedicated, disposable non-production project.
4. Configure the Supabase Edge Function secret `PLATFORM_PIN_SETUP_SECRET` with a strong, randomly generated value before any new platform-owner PIN is initialized. Keep it out of source code and never use it as a school password. Rotate or remove it after the first PIN is securely initialized. Existing configured owner PINs do not require this secret for verification or changes.
5. Apply the new migration to the dedicated test project first, then run `node tools/test_rls_isolation.mjs` only after verifying the exact URL/project-ref match and intentionally setting `ALLOW_DESTRUCTIVE_RLS_TESTS=YES`.
6. Verify school onboarding uses `platform-create-school` for first-school/first-admin creation. `school-upsert-account` now rejects unauthenticated bootstrap attempts by design.
7. Run the Flutter test suite, static analysis, and release build; the GitHub integration does not execute these commands locally.

## Changes in this branch

- Re-enables server-side throttling for platform PIN buckets that previously bypassed the database rate-limit function.
- Uses PBKDF2-SHA256 with 210,000 iterations for new owner PIN hashes; legacy salted SHA-256 hashes are upgraded after successful verification.
- Requires a deployment-provisioned one-time secret for initial owner PIN setup, because a client-generated OTP is not server-side authorization.
- Removes anonymous first-admin bootstrap from the general account upsert endpoint.
- Changes the teacher read helper's unclassified-collection fallback from allow to deny; scopes account profiles, conversations, notifications, and push tokens to the signed-in teacher unless an explicit school-wide permission applies.
- Makes the RLS isolation test reject non-canonical/custom URLs, require an exact non-production project-ref confirmation and explicit destructive-test opt-in, and fail closed when required CI variables/secrets are missing or staging is unreachable.
- Adds integration checks for unknown collection denial and anonymous first-admin bootstrap rejection.

## Important safety boundary

Do not apply this migration to production or deploy the Edge Functions until staging tests pass and the school onboarding flow has been checked. This branch does not change production Supabase data, production secrets, repository visibility, or deployment settings.

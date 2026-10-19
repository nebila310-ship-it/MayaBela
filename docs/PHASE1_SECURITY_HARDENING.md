# Phase 1 security hardening — release notes

This branch contains security changes only. It has **not** been merged or deployed.

## Required deployment preparation (do not deploy until completed)

1. Configure a dedicated **non-production staging Supabase project** with the same migration set and Edge Functions as the release candidate.
2. Add repository Actions secrets:
   - `STAGING_SUPABASE_URL`
   - `STAGING_ANON_KEY`
   - `STAGING_SERVICE_ROLE_KEY`
3. Configure the Supabase Edge Function secret `PLATFORM_PIN_SETUP_SECRET` with a strong, randomly generated value before any new platform-owner PIN is initialized. Keep it out of source code and never use it as a school password. Existing configured owner PINs do not require this secret for verification or changes.
4. Apply the new migration to staging first, then run `node tools/test_rls_isolation.mjs` against staging only.
5. Verify school onboarding uses `platform-create-school` for first-school/first-admin creation. `school-upsert-account` now rejects unauthenticated bootstrap attempts by design.
6. Run the Flutter test suite, static analysis, and release build; the GitHub integration does not execute these commands locally.

## Changes in this branch

- Re-enables server-side throttling for platform PIN buckets that previously bypassed the database rate-limit function.
- Uses PBKDF2-SHA256 with 210,000 iterations for new owner PIN hashes; legacy salted SHA-256 hashes are upgraded after successful verification.
- Requires a deployment-provisioned one-time secret for initial owner PIN setup, because a client-generated OTP is not server-side authorization.
- Removes anonymous first-admin bootstrap from the general account upsert endpoint.
- Changes the teacher read helper's unclassified-collection fallback from allow to deny.
- Makes the staging RLS isolation test fail when credentials are missing or staging cannot be reached.
- Adds integration checks for unknown collection denial and anonymous first-admin bootstrap rejection.

## Important safety boundary

Do not apply this migration to production or deploy the Edge Functions until staging tests pass and the school onboarding flow has been checked. This branch does not change production Supabase data, production secrets, repository visibility, or deployment settings.

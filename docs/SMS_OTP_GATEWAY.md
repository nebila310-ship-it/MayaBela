# Paid SMS OTP (password reset)

Forgot-password codes are sent by a **paid SMS gateway** from a Supabase Edge Function. The Flutter app never receives the code and does not open the phone’s Messages app.

Live reset path:

1. User enters **School ID** + registered phone.
2. `school-send-otp` looks up the school account, stores a hashed 6-digit code (10 minutes), and texts it.
3. User types the code + new password.
4. `school-reset-password-otp` checks the hash and updates `auth_secrets`.

## 1. Apply the migration

In the Supabase SQL editor, run:

`supabase/migrations/20260907220000_auth_otp_challenges.sql`

This keeps OTP hashes in the server-only collection `auth_otp_challenges` (same protection as passwords).

## 2. Create a paid SMS account

**Africa’s Talking** (best fit for Ethiopia / +251):

1. Sign up at [africastalking.com](https://africastalking.com).
2. Open **SMS** → copy **Username** and **API Key**.
3. Optional: register a sender ID (e.g. `MayaBela`). Until it is approved, omit `AT_SENDER` and the default short code is used.
4. Add credit. Each OTP is one SMS (billed by Africa’s Talking, not included in Supabase Pro).

**Twilio** (international fallback):

1. Create a Twilio account and buy/verify a **From** number that can send to +251.
2. Copy Account SID, Auth Token, and the From number.

## 3. Set Edge Function secrets

Supabase Dashboard → **Edge Functions** → **Secrets**, or CLI:

```bash
npx supabase secrets set SMS_PROVIDER=africas_talking
npx supabase secrets set AT_USERNAME=your_at_username
npx supabase secrets set AT_API_KEY=your_at_api_key
# optional:
npx supabase secrets set AT_SENDER=MayaBela
```

Twilio instead:

```bash
npx supabase secrets set SMS_PROVIDER=twilio
npx supabase secrets set TWILIO_ACCOUNT_SID=ACxxxxxxxx
npx supabase secrets set TWILIO_AUTH_TOKEN=your_token
npx supabase secrets set TWILIO_FROM=+1xxxxxxxxxx
```

If `SMS_PROVIDER` is omitted, the function picks Africa’s Talking when `AT_API_KEY` is set, otherwise Twilio.

## 4. Deploy the functions

```bash
npx supabase functions deploy school-send-otp
npx supabase functions deploy school-reset-password-otp
```

Also listed in [SUPABASE_SETUP.md](../SUPABASE_SETUP.md).

## 5. Check it

1. Hard-refresh https://mayabela.pages.dev
2. Forgot password → School ID + a registered `09xxxxxxxx` phone
3. The phone should receive: `MayaBela code: ######. It expires in 10 minutes.`
4. The app must **not** show the digits.
5. Enter the code and a new password (≥ 10 characters), then sign in.

Rate limit: 8 sends / 15 minutes per school+phone. Five wrong codes burn the challenge; request a new SMS.

## Debug only

If the gateway secrets are missing, **debug builds** still show an in-app demo code so local testing works. Release builds fail with “Real SMS is not connected yet.”

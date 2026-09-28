/// Supabase project config for MayaBela.
///
/// Defaults are the live project (`hwkiihonthueadbhcvfi`).
/// Override via `--dart-define=SUPABASE_URL=...` and
/// `--dart-define=SUPABASE_ANON_KEY=...` if needed (see `deploy-web-release.cmd`).
///
/// An empty dart-define (common when GitHub Actions secrets are unset) must
/// fall back to these defaults. `String.fromEnvironment` only uses
/// [defaultValue] when the define is omitted, not when it is set to `""`.
///
/// Never put the **service_role** key here — client builds use the anon key only.
const bool kSupabaseConfigured = bool.fromEnvironment(
  'SUPABASE_CONFIGURED',
  defaultValue: true,
);

const String _kDefaultSupabaseUrl =
    'https://hwkiihonthueadbhcvfi.supabase.co';
const String _kDefaultSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2lpaG9udGh1ZWFkYmhjdmZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNjI4MzcsImV4cCI6MjEwMDczODgzN30.eD6RjusSvYm-3vm4QDiiRtEAihmFvznf5ZkeumJDGdY';

String _envOrDefault(String fromEnv, String fallback) =>
    fromEnv.isEmpty ? fallback : fromEnv;

String get kSupabaseUrl => _envOrDefault(
      const String.fromEnvironment('SUPABASE_URL'),
      _kDefaultSupabaseUrl,
    );

String get kSupabaseAnonKey => _envOrDefault(
      const String.fromEnvironment('SUPABASE_ANON_KEY'),
      _kDefaultSupabaseAnonKey,
    );

bool get kSupabaseReady {
  if (!kSupabaseConfigured) return false;
  if (kSupabaseUrl.contains('YOUR_PROJECT_REF')) return false;
  if (kSupabaseAnonKey.contains('YOUR_SUPABASE')) return false;
  return kSupabaseUrl.startsWith('https://') && kSupabaseAnonKey.isNotEmpty;
}

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

/// School branding object URL.
///
/// `school-files` is a private bucket, so `/object/public/` 404s in the
/// browser. Use the authenticated endpoint plus the anon key headers from
/// [schoolBrandingImageHeaders].
String schoolBrandingPublicUrl(String schoolId, {required String file}) {
  final id = schoolId.trim().toUpperCase();
  final name = file.trim().isEmpty ? 'logo.jpg' : file.trim();
  return '$kSupabaseUrl/storage/v1/object/authenticated/school-files/'
      'schools/$id/branding/$name';
}

/// Rewrite a stored public storage URL so [Image.network] can load it.
String schoolBrandingViewableUrl(String url) {
  return url.replaceFirst(
    '/storage/v1/object/public/school-files/',
    '/storage/v1/object/authenticated/school-files/',
  );
}

/// Headers so the private branding object can be fetched without a school JWT.
Map<String, String>? schoolBrandingImageHeaders(String url) {
  if (!url.contains('/storage/v1/object/')) return null;
  if (url.contains('token=')) return null;
  return {
    'Authorization': 'Bearer $kSupabaseAnonKey',
    'apikey': kSupabaseAnonKey,
  };
}

bool get kSupabaseReady {
  if (!kSupabaseConfigured) return false;
  if (kSupabaseUrl.contains('YOUR_PROJECT_REF')) return false;
  if (kSupabaseAnonKey.contains('YOUR_SUPABASE')) return false;
  return kSupabaseUrl.startsWith('https://') && kSupabaseAnonKey.isNotEmpty;
}

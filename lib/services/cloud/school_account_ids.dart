/// Cloud document ids for school-scoped auth accounts.
///
/// Must stay in sync with `accountDocId` in
/// `supabase/functions/_shared/school_auth.ts`.
String schoolAccountDocId(String schoolId, String username) {
  final sid = schoolId.trim().toUpperCase();
  final key = username.trim().toLowerCase();
  if (sid.isEmpty) return key;
  return '${sid}__$key';
}

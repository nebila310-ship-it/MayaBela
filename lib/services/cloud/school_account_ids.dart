import 'package:mayabela/utils/phone_utils.dart';

/// Cloud document ids for school-scoped auth accounts.
///
/// Must stay in sync with `accountDocId` in
/// `supabase/functions/_shared/school_auth.ts`.
String schoolAccountDocId(String schoolId, String username) {
  final sid = schoolId.trim().toUpperCase();
  final trimmed = username.trim().toLowerCase();
  final key = PhoneUtils.normalizeLocal(trimmed) ?? trimmed;
  if (sid.isEmpty) return key;
  return '${sid}__$key';
}

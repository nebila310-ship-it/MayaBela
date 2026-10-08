/// `STU-1013`, `stu-1013`, and `1013` are the same roster id.
bool studentIdsMatch(String? a, String? b) {
  final na = (a ?? '').trim().toUpperCase();
  final nb = (b ?? '').trim().toUpperCase();
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  String strip(String value) =>
      value.startsWith('STU-') ? value.substring(4) : value;
  final sa = strip(na);
  final sb = strip(nb);
  return sa.isNotEmpty && sa == sb;
}

/// Parses numeric grade from labels like "Grade 7", "G7", "7", "Grade 12".
int? parseGradeNumber(String? gradeLabel) {
  if (gradeLabel == null) return null;
  final trimmed = gradeLabel.trim();
  if (trimmed.isEmpty) return null;

  final direct = int.tryParse(trimmed);
  if (direct != null) return direct;

  final match = RegExp(r'(\d{1,2})').firstMatch(trimmed);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

bool isGradeEligibleForStudentPortal({
  required String? gradeLabel,
  required int minimumGrade,
}) {
  final gradeNumber = parseGradeNumber(gradeLabel);
  if (gradeNumber == null) return false;
  return gradeNumber >= minimumGrade;
}

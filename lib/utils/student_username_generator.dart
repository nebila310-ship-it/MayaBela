import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';

String studentIdLast4(String studentId) {
  final digits = studentId.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 4) return digits.substring(digits.length - 4);
  return digits.padLeft(4, '0');
}

String firstNameToken(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return 'student';
  final first = parts.first.toLowerCase();
  final cleaned = first.replaceAll(RegExp(r'[^a-z0-9]'), '');
  return cleaned.isEmpty ? 'student' : cleaned;
}

String buildStudentUsername({
  required String fullName,
  required String studentId,
  StudentUsernameFormat format = StudentUsernameFormat.firstNameLast4Id,
}) {
  return switch (format) {
    StudentUsernameFormat.firstNameLast4Id =>
      '${firstNameToken(fullName)}${studentIdLast4(studentId)}',
  };
}

String generateUniqueStudentUsername({
  required String fullName,
  required String studentId,
  StudentUsernameFormat format = StudentUsernameFormat.firstNameLast4Id,
  bool Function(String username)? isTaken,
}) {
  final base = buildStudentUsername(
    fullName: fullName,
    studentId: studentId,
    format: format,
  );
  final taken = isTaken ?? AuthService.isUsernameTaken;
  if (!taken(base)) return base;

  for (var suffix = 1; suffix < 100; suffix++) {
    final candidate = '$base$suffix';
    if (!taken(candidate)) return candidate;
  }
  return '${base}_${DateTime.now().millisecondsSinceEpoch % 10000}';
}

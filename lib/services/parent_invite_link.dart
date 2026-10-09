import 'package:flutter/foundation.dart';

/// Live parent-registration URL that works on any phone or browser.
class ParentInvitePrefill {
  const ParentInvitePrefill({
    required this.schoolId,
    this.studentId,
    this.dobText,
  });

  final String schoolId;
  final String? studentId;

  /// DD/MM/YYYY when the invite included a date of birth.
  final String? dobText;
}

class ParentInviteLink {
  ParentInviteLink._();

  static const liveOrigin = 'https://majobridge.com';
  static const pagesOrigin = 'https://mayabela.pages.dev';

  static String formatDob(DateTime dob) {
    final day = dob.day.toString().padLeft(2, '0');
    final month = dob.month.toString().padLeft(2, '0');
    return '$day/$month/${dob.year}';
  }

  static DateTime? parseDob(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      try {
        return DateTime(
          int.parse(value.substring(0, 4)),
          int.parse(value.substring(5, 7)),
          int.parse(value.substring(8, 10)),
        );
      } catch (_) {
        return null;
      }
    }
    final parts = value.split(RegExp(r'[/-]'));
    if (parts.length != 3) return null;
    try {
      final first = int.parse(parts[0]);
      final second = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      // Invite links and the parent form use DD/MM/YYYY.
      if (parts[2].length == 4) {
        return DateTime(year, second, first);
      }
      return DateTime(first, second, year);
    } catch (_) {
      return null;
    }
  }

  /// Prefer the site the staff member is on; otherwise the public domain.
  static String originForShare() {
    if (kIsWeb) {
      final origin = Uri.base.origin.trim();
      final host = Uri.base.host.toLowerCase();
      if (origin.startsWith('http') &&
          (host.contains('majobridge.com') ||
              host.contains('mayabela.pages.dev') ||
              host.endsWith('.pages.dev'))) {
        return origin;
      }
    }
    return liveOrigin;
  }

  static String build({
    required String schoolId,
    required String studentId,
    DateTime? dateOfBirth,
    String? origin,
  }) {
    final params = <String, String>{
      'role': 'parent',
      'school': schoolId.trim().toUpperCase(),
      'student': studentId.trim().toUpperCase(),
    };
    if (dateOfBirth != null) {
      params['dob'] = formatDob(dateOfBirth);
    }
    final base = Uri.parse(origin ?? originForShare());
    return base
        .replace(
          path: base.path.isEmpty ? '/' : base.path,
          queryParameters: params,
        )
        .toString();
  }

  static ParentInvitePrefill? parse(Uri uri) {
    final query = <String, String>{};
    query.addAll(uri.queryParameters);
    final fragment = uri.fragment;
    if (fragment.contains('?')) {
      query.addAll(Uri.splitQueryString(fragment.split('?').last));
    } else if (fragment.contains('=')) {
      query.addAll(Uri.splitQueryString(fragment));
    }
    final school =
        (query['school'] ?? query['schoolId'] ?? '').trim().toUpperCase();
    final student =
        (query['student'] ?? query['studentId'] ?? '').trim().toUpperCase();
    final role = (query['role'] ?? '').trim().toLowerCase();
    if (school.isEmpty) return null;
    if (role != 'parent' && student.isEmpty) return null;
    final rawDob = (query['dob'] ?? query['dateOfBirth'] ?? '').trim();
    String? dobText;
    if (rawDob.isNotEmpty) {
      final parsed = parseDob(rawDob);
      dobText = parsed != null ? formatDob(parsed) : rawDob;
    }
    return ParentInvitePrefill(
      schoolId: school,
      studentId: student.isEmpty ? null : student,
      dobText: dobText,
    );
  }
}

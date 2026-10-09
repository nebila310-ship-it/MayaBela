import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/parent_invite_link.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Verify a child for parent signup on any device.
///
/// Local roster first (school PC already has the student). If that misses,
/// call the public `school-verify-student` function and remember the hit so
/// the rest of the signup/link flow can keep using [StudentRegistryService].
class ParentStudentVerifyService {
  ParentStudentVerifyService._();
  static final instance = ParentStudentVerifyService._();

  Future<AdminStudentRecord?> Function({
    required String schoolId,
    required String studentId,
    required DateTime dateOfBirth,
  })?
  debugCloudOverride;

  @visibleForTesting
  bool debugAllowNetwork = true;

  @visibleForTesting
  void debugReset() {
    debugCloudOverride = null;
    debugAllowNetwork = true;
  }

  Future<AdminStudentRecord?> verify({
    required String schoolId,
    required String studentId,
    required DateTime dateOfBirth,
  }) async {
    final localOk = StudentRegistryService.instance.verifyStudent(
      schoolId: schoolId,
      studentId: studentId,
      dateOfBirth: dateOfBirth,
    );
    if (localOk) {
      return StudentRegistryService.instance.lookupById(studentId);
    }

    final cloud = await _fetchCloud(
      schoolId: schoolId,
      studentId: studentId,
      dateOfBirth: dateOfBirth,
    );
    if (cloud == null) return null;
    StudentRegistryService.instance.rememberVerifiedStudent(cloud);
    return cloud;
  }

  Future<AdminStudentRecord?> _fetchCloud({
    required String schoolId,
    required String studentId,
    required DateTime dateOfBirth,
  }) async {
    try {
      if (debugCloudOverride != null) {
        return debugCloudOverride!(
          schoolId: schoolId,
          studentId: studentId,
          dateOfBirth: dateOfBirth,
        );
      }
      if (!debugAllowNetwork) return null;
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      if (!SupabaseBootstrap.isInitialized) return null;
      final res = await SupabaseBootstrap.client.functions.invoke(
        'school-verify-student',
        body: {
          'schoolId': schoolId.trim().toUpperCase(),
          'studentId': studentId.trim().toUpperCase(),
          'dateOfBirth':
              '${dateOfBirth.year.toString().padLeft(4, '0')}-'
              '${dateOfBirth.month.toString().padLeft(2, '0')}-'
              '${dateOfBirth.day.toString().padLeft(2, '0')}',
        },
      );
      return recordFromCloud(res.data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('school-verify-student failed: $e');
      }
      return null;
    }
  }

  @visibleForTesting
  static AdminStudentRecord? recordFromCloud(Object? data) {
    if (data is! Map) return null;
    if (data['ok'] != true) return null;
    final id = data['studentId']?.toString().trim().toUpperCase() ?? '';
    final school = data['schoolId']?.toString().trim().toUpperCase() ?? '';
    final name = data['fullName']?.toString().trim() ?? '';
    if (id.isEmpty || school.isEmpty || name.isEmpty) return null;
    final dob =
        ParentInviteLink.parseDob(data['dateOfBirth']?.toString() ?? '') ??
        DateTime.now();
    final className = data['className']?.toString().trim() ?? '';
    final grade = data['grade']?.toString().trim() ?? '';
    return AdminStudentRecord(
      studentId: id,
      fullName: name,
      grade: grade.isNotEmpty ? grade : className,
      className: className.isNotEmpty ? className : grade,
      schoolId: school,
      dateOfBirth: dob,
      fatherName: _optional(data['fatherName']),
      fatherPhone: _optional(data['fatherPhone']),
      motherName: _optional(data['motherName']),
      motherPhone: _optional(data['motherPhone']),
      guardianName: _optional(data['guardianName']),
      guardianPhone: _optional(data['guardianPhone']),
    );
  }

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

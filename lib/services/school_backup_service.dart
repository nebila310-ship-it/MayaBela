import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// School-held JSON snapshot of the live registers.
///
/// Daily records live in the cloud. This export is the copy the school should
/// also keep on its own computer or school server so Fenote Raey is not locked
/// to one place.
class SchoolBackupService {
  SchoolBackupService._();
  static final instance = SchoolBackupService._();

  Map<String, dynamic> buildSchoolBackup({String? schoolId}) {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim().toUpperCase();
    final school = SchoolRegistryService.instance.lookup(sid);
    final students = StudentRegistryService.instance
        .registrySnapshot()
        .where((s) => s.schoolId.toUpperCase() == sid)
        .toList();
    final teachers =
        TeacherRegistryService.instance.teachersForSchool(sid, includeInactive: true);
    final employees = EmployeeRegistryService.instance
        .employeesForSchool(sid, includeInactive: true);
    final drivers = DriverRegistryService.instance.driversForSchool(sid);

    Map<String, dynamic> stripSecrets(Map<String, dynamic> row) {
      final copy = Map<String, dynamic>.from(row);
      copy.remove('initialPassword');
      copy.remove('photoPath');
      return copy;
    }

    return {
      'format': 'maya_school_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'schoolId': sid,
      'recommended': {
        'cloud': 'Keep daily work in the MaJo Bridge cloud (Supabase).',
        'schoolCopy':
            'Also store this JSON on a school computer or school server.',
        'cadence': 'Weekly full JSON + after payroll, exams, or large enrollments.',
      },
      'school': school?.toJson(),
      'students': students.map((s) => stripSecrets(s.toMap())).toList(),
      'teachers': teachers.map((t) => stripSecrets(t.toMap())).toList(),
      'employees': employees.map((e) => e.toMap()).toList(),
      'drivers': drivers.map((d) => stripSecrets(d.toMap())).toList(),
      'counts': {
        'students': students.length,
        'teachers': teachers.length,
        'employees': employees.length,
        'drivers': drivers.length,
      },
    };
  }

  Future<void> shareSchoolJsonBackup() async {
    final payload = buildSchoolBackup();
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final schoolId = payload['schoolId'] as String? ?? 'school';
    final file = await _writeTemp('${schoolId.toLowerCase()}_school_backup.json', json);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Fenote Raey school backup',
      text:
          'School JSON backup for $schoolId. Keep one copy in the cloud and one '
          'on a school computer or school server.',
    );
    await SchoolAuditLogService.instance.log(
      action: 'school_backup_exported',
      detail: 'JSON school backup',
    );
  }

  Future<File> _writeTemp(String name, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(contents);
    return file;
  }
}

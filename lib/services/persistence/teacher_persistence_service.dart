import 'dart:async';

import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Persists admin-created teacher records and class assignments.
class TeacherPersistenceService {
  TeacherPersistenceService._();
  static final instance = TeacherPersistenceService._();

  static const _registryKey = 'persisted_teacher_registry';
  static const _nextIdKey = 'persisted_teacher_next_id';

  Future<void> loadRegistryIntoService() async {
    final rows = await LocalJsonStore.readList(_registryKey);
    final nextId = await LocalJsonStore.readInt(_nextIdKey);
    if (rows.isEmpty) return;

    final parsed = <AdminTeacherRecord>[];
    for (final map in rows) {
      try {
        parsed.add(AdminTeacherRecord.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      TeacherRegistryService.instance.applyPersistedTeachers(
        parsed,
        nextId: nextId,
      );
    }
  }

  Future<void> saveRegistryFromService({
    bool pushCloud = true,
    bool notifyStaff = true,
    String? syncTeacherId,
    bool requireCloudSuccess = false,
  }) async {
    final teachers = TeacherRegistryService.instance.registrySnapshot();
    await LocalJsonStore.writeList(
      _registryKey,
      teachers.map((teacher) => teacher.toMap()).toList(),
    );
    await LocalJsonStore.writeInt(
      _nextIdKey,
      TeacherRegistryService.instance.nextTeacherIdCounter,
    );
    if (pushCloud) {
      final syncId = syncTeacherId?.trim().toUpperCase();
      final cloudTargets = syncId == null || syncId.isEmpty
          ? teachers
          : teachers.where((t) => t.teacherId.toUpperCase() == syncId);
      for (final teacher in cloudTargets) {
        await CloudAppStore.instance.pushTeacherRegistryRecord(
          teacher,
          requireSuccess: requireCloudSuccess,
        );
      }
    }
    if (notifyStaff) {
      StaffRegistryNotifier.instance.notifyChanged();
    }
    unawaited(AuthService.persistRegistryLoginAccounts());
  }

  /// Removes staff/teacher from registry + cloud and frees their login phone.
  /// Call after clearing class assignments / homeroom replacements.
  Future<void> deleteStaffAndFreePhone(AdminTeacherRecord teacher) async {
    final loginKey = (teacher.loginUsername?.trim().isNotEmpty == true
            ? teacher.loginUsername!
            : (teacher.phone ?? ''))
        .trim();
    if (loginKey.isNotEmpty) {
      await AuthService.revokeRegisteredAccount(
        loginKey,
        schoolId: teacher.schoolId,
      );
    }
    TeacherRegistryService.instance.removeTeacher(teacher.teacherId);
    await CloudAppStore.instance.deleteTeacherRegistryRecord(teacher.teacherId);
    await saveRegistryFromService(pushCloud: false);
  }
}

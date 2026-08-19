import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Persists the student registry (admin-created/edited students) and medical fields.
class StudentPersistenceService {
  StudentPersistenceService._();
  static final instance = StudentPersistenceService._();

  static const _registryKey = 'persisted_student_registry';
  static const _nextIdKey = 'persisted_student_next_id';
  static const _medicalKey = 'persisted_student_medical';

  Future<void> loadRegistryIntoService() async {
    final rows = await LocalJsonStore.readList(_registryKey);
    final nextId = await LocalJsonStore.readInt(_nextIdKey);
    if (rows.isEmpty) return;

    final parsed = <AdminStudentRecord>[];
    for (final map in rows) {
      try {
        parsed.add(AdminStudentRecord.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      StudentRegistryService.instance.applyPersistedStudents(
        parsed,
        nextId: nextId,
      );
    }
  }

  Future<void> saveRegistryFromService({
    bool pushCloud = true,
    String? syncStudentId,
    bool requireCloudSuccess = false,
    bool immediateUpload = false,
  }) async {
    final students = StudentRegistryService.instance.registrySnapshot();
    await LocalJsonStore.writeList(
      _registryKey,
      students.map((s) => s.toMap()).toList(),
    );
    await LocalJsonStore.writeInt(
      _nextIdKey,
      StudentRegistryService.instance.nextStudentIdCounter,
    );
    if (pushCloud) {
      final syncId = syncStudentId?.trim().toUpperCase();
      final cloudTargets = syncId == null || syncId.isEmpty
          ? students
          : students.where((s) => s.studentId.toUpperCase() == syncId);
      for (final student in cloudTargets) {
        await CloudAppStore.instance.pushStudentRegistryRecord(
          student,
          requireSuccess: requireCloudSuccess,
          immediate: immediateUpload || requireCloudSuccess,
        );
      }
    }
  }

  Future<void> loadMedicalOverrides() async {
    final map = await LocalJsonStore.readMap(_medicalKey);
    if (map == null || map.isEmpty) return;

    for (final entry in map.entries) {
      final studentId = entry.key.toUpperCase();
      final data = entry.value;
      if (data is! Map) continue;
      final record = StudentRegistryService.instance.lookupById(studentId);
      if (record == null) continue;

      StudentRegistryService.instance.updateStudent(
        record.copyWith(
          hasMedicalCondition: data['hasMedicalCondition'] as bool? ?? false,
          medicalConditionDetails: data['medicalConditionDetails'] as String?,
          otherMedicalInfo: data['otherMedicalInfo'] as String?,
        ),
      );
    }
  }

  Future<void> saveMedicalForStudent(
    AdminStudentRecord student, {
    bool pushCloud = true,
  }) async {
    final map =
        await LocalJsonStore.readMap(_medicalKey) ?? <String, dynamic>{};
    map[student.studentId.toUpperCase()] = {
      'hasMedicalCondition': student.hasMedicalCondition,
      if (student.medicalConditionDetails != null)
        'medicalConditionDetails': student.medicalConditionDetails,
      if (student.otherMedicalInfo != null)
        'otherMedicalInfo': student.otherMedicalInfo,
    };
    await LocalJsonStore.writeMap(_medicalKey, map);
    if (pushCloud) {
      await CloudAppStore.instance.pushStudentMedical(student);
    }
  }
}

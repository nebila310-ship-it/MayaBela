import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Admin transfer operations — registry updates plus runtime sync.
class TransferService {
  TransferService._();
  static final instance = TransferService._();

  final _students = StudentRegistryService.instance;
  final _teachers = TeacherRegistryService.instance;
  final _drivers = DriverRegistryService.instance;
  final _classes = ClassStructureService.instance;
  final _data = SchoolDataService.instance;

  Future<bool> transferStudentToSection({
    required String studentId,
    required String toGrade,
    required String toSection,
  }) async {
    final section = toSection.trim();
    if (section.isEmpty) return false;
    await _classes.ensureSectionForGrade(toGrade, section);
    final className = StudentRegistryService.buildClassName(toGrade, section);
    final homeroomId = _data.homeroomTeacherIdForClass(className);
    _students.transferStudent(
      studentId: studentId,
      grade: toGrade.trim(),
      section: section,
      homeroomTeacherId: homeroomId,
    );
    _data.syncChildFromRegistry(studentId);
    return true;
  }

  Future<bool> transferStudentToGrade({
    required String studentId,
    required String toGrade,
    required String toSection,
  }) =>
      transferStudentToSection(
        studentId: studentId,
        toGrade: toGrade,
        toSection: toSection,
      );

  bool transferStudentTransport({
    required String studentId,
    required String toDriverId,
  }) {
    if (_drivers.lookupById(toDriverId) == null) return false;
    _students.transferStudentTransport(
      studentId: studentId,
      toDriverId: toDriverId,
    );
    _data.syncChildFromRegistry(studentId);
    return true;
  }

  bool transferStudentCampus({
    required String studentId,
    required String toCampus,
  }) {
    if (toCampus.trim().isEmpty) return false;
    _students.transferStudentCampus(
      studentId: studentId,
      toCampus: toCampus,
    );
    _data.syncChildFromRegistry(studentId);
    return true;
  }

  Future<bool> transferTeacherSection({
    required String teacherId,
    required String fromClassName,
    required String toGrade,
    required String toSection,
  }) async {
    final section = toSection.trim();
    if (section.isEmpty) return false;
    await _classes.ensureSectionForGrade(toGrade, section);
    final toClassName = StudentRegistryService.buildClassName(toGrade, section);
    _teachers.transferTeacherClass(
      teacherId: teacherId,
      fromClassName: fromClassName,
      toClassName: toClassName,
    );
    final updated = _teachers.lookupById(teacherId);
    if (updated == null) return false;
    _data.syncTeacherFromRegistry(updated);
    return true;
  }

  Future<bool> transferTeacherGrade({
    required String teacherId,
    required String fromClassName,
    required String toGrade,
    required String toSection,
  }) =>
      transferTeacherSection(
        teacherId: teacherId,
        fromClassName: fromClassName,
        toGrade: toGrade,
        toSection: toSection,
      );

  bool transferTeacherCampus({
    required String teacherId,
    required String toCampus,
  }) {
    if (toCampus.trim().isEmpty) return false;
    _teachers.transferTeacherCampus(
      teacherId: teacherId,
      toCampus: toCampus,
    );
    final updated = _teachers.lookupById(teacherId);
    if (updated == null) return false;
    _data.syncTeacherFromRegistry(updated);
    return true;
  }

  bool transferDriverBus({
    required String fromDriverId,
    required String toDriverId,
  }) {
    final ok = _drivers.swapDriverBuses(
      fromDriverId: fromDriverId,
      toDriverId: toDriverId,
    );
    if (!ok) return false;
    _data.syncAllStudentsFromRegistry();
    return true;
  }
}

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

enum ParentTransportLinkError {
  notParent,
  studentNotFound,
  accessDenied,
  busNotFound,
  wrongSchool,
}

class ParentTransportLinkResult {
  const ParentTransportLinkResult.success(this.driver)
      : error = null;

  const ParentTransportLinkResult.failure(this.error) : driver = null;

  final AdminDriverRecord? driver;
  final ParentTransportLinkError? error;

  bool get ok => error == null;
}

/// Lets parents link their approved children to a school bus (Bus Link ID).
class ParentTransportService {
  ParentTransportService._();
  static final instance = ParentTransportService._();

  bool canManageStudent(String studentId) {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != AuthService.roleParent) return false;

    final normalized = studentId.trim().toUpperCase();
    if (normalized.isEmpty) return false;

    EnrollmentService.instance.ensureSeeded();
    final allowed = EnrollmentService.instance
        .approvedStudentIdsForParent(user.username)
        .map((id) => id.toUpperCase())
        .toSet();

    return allowed.contains(normalized);
  }

  AdminDriverRecord? linkedDriverForStudent(String studentId) {
    final record = StudentRegistryService.instance.lookupById(studentId);
    if (record == null ||
        !record.transportEnabled ||
        record.transportId == null ||
        record.transportId!.trim().isEmpty) {
      return null;
    }
    return DriverRegistryService.instance
        .resolveTransportReference(record.transportId!);
  }

  ParentTransportLinkResult linkStudentToBus({
    required String studentId,
    required String busLinkId,
  }) {
    if (!canManageStudent(studentId)) {
      return const ParentTransportLinkResult.failure(
        ParentTransportLinkError.accessDenied,
      );
    }

    final trimmed = busLinkId.trim();
    if (trimmed.isEmpty) {
      return const ParentTransportLinkResult.failure(
        ParentTransportLinkError.busNotFound,
      );
    }

    final validation = ParentInviteService.instance.validateTransportId(
      trimmed,
      schoolId: AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId,
    );
    if (validation == 'not_found') {
      return const ParentTransportLinkResult.failure(
        ParentTransportLinkError.busNotFound,
      );
    }
    if (validation == 'wrong_school') {
      return const ParentTransportLinkResult.failure(
        ParentTransportLinkError.wrongSchool,
      );
    }

    final driver =
        DriverRegistryService.instance.resolveTransportReference(trimmed);
    if (driver == null) {
      return const ParentTransportLinkResult.failure(
        ParentTransportLinkError.busNotFound,
      );
    }

    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) {
      return const ParentTransportLinkResult.failure(
        ParentTransportLinkError.studentNotFound,
      );
    }

    StudentRegistryService.instance.updateStudent(
      student.copyWith(
        transportEnabled: true,
        transportId: driver.busId,
      ),
    );
    SchoolDataService.instance.syncChildFromRegistry(studentId);
    return ParentTransportLinkResult.success(driver);
  }

  ParentTransportLinkError? unlinkStudentFromBus({required String studentId}) {
    if (!canManageStudent(studentId)) {
      return ParentTransportLinkError.accessDenied;
    }

    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) {
      return ParentTransportLinkError.studentNotFound;
    }

    StudentRegistryService.instance.updateStudent(
      student.copyWith(
        transportEnabled: false,
        clearTransportId: true,
      ),
    );
    SchoolDataService.instance.syncChildFromRegistry(studentId);
    return null;
  }
}

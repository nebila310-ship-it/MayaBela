import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/enrolment_excel_import.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

/// Writes Fenote enrolment Excel rows into the same registries as Add Student /
/// Add Teacher / Add Administration Staff. Software issues the IDs.
class EnrolmentImportService {
  EnrolmentImportService._();
  static final instance = EnrolmentImportService._();

  bool get canImportStudents =>
      ModuleAccess.canManage('students') ||
      GoliveService.instance.canImportStudents;

  bool get canImportStaff =>
      ModuleAccess.canHireStaff || GoliveService.instance.canManageDesk;

  Future<EnrolmentImportResult> importDraft(
    EnrolmentWorkbookDraft draft, {
    EnrolmentImportScope scope = EnrolmentImportScope.all,
    String? schoolId,
  }) async {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '')
        .trim()
        .toUpperCase();
    if (sid.isEmpty) {
      throw StateError('Sign in to a school before importing enrolment Excel.');
    }

    final skipped = List<String>.from(draft.skipped);
    final createdStudents = <String>[];
    final createdTeachers = <String>[];
    final createdStaff = <String>[];

    final wantStudents = scope == EnrolmentImportScope.all ||
        scope == EnrolmentImportScope.students;
    final wantTeachers = scope == EnrolmentImportScope.all ||
        scope == EnrolmentImportScope.teachers;
    final wantStaff = scope == EnrolmentImportScope.all ||
        scope == EnrolmentImportScope.staff;

    if (wantStudents) {
      if (!canImportStudents) {
        throw StateError('Only registrars and owners can import students.');
      }
      createdStudents.addAll(
        await _importStudents(draft.students, sid, skipped),
      );
    }
    if (wantTeachers) {
      if (!canImportStaff) {
        throw StateError('Only HR and owners can import teachers.');
      }
      createdTeachers.addAll(
        await _importTeachers(draft.teachers, sid, skipped, asStaff: false),
      );
    }
    if (wantStaff) {
      if (!canImportStaff) {
        throw StateError('Only HR and owners can import administration staff.');
      }
      createdStaff.addAll(
        await _importTeachers(
          [
            for (final row in draft.staff)
              EnrolmentTeacherDraft(
                fullName: row.fullName,
                email: row.email,
                phone: row.phone,
                employeeId: row.employeeId,
                campus: row.campus,
                roles: const [],
                source: row.source,
              ),
          ],
          sid,
          skipped,
          asStaff: true,
          staffRolesByIndex: [for (final row in draft.staff) row.staffRoles],
        ),
      );
    }

    return EnrolmentImportResult(
      createdStudentIds: createdStudents,
      createdTeacherIds: createdTeachers,
      createdStaffIds: createdStaff,
      skipped: skipped,
    );
  }

  Future<List<String>> _importStudents(
    List<EnrolmentStudentDraft> rows,
    String sid,
    List<String> skipped,
  ) async {
    final created = <String>[];
    final registry = StudentRegistryService.instance;
    for (final row in rows) {
      final duplicate = registry.studentsForSchool(sid).any(
            (student) =>
                student.fullName.trim().toLowerCase() ==
                    row.fullName.trim().toLowerCase() &&
                student.className.trim().toLowerCase() ==
                    row.className.trim().toLowerCase(),
          );
      if (duplicate) {
        skipped.add('${row.fullName} (same name + class)');
        continue;
      }
      final section = StudentRegistryService.parseClassNameParts(row.className)
              ?.section ??
          '';
      if (row.grade != EnrolmentExcelImport.unassigned && section.isNotEmpty) {
        await ClassStructureService.instance.ensureSectionForGrade(
          row.grade,
          section,
        );
      }
      final record = registry.addStudent(
        schoolId: sid,
        fullName: row.fullName,
        grade: row.grade,
        className: row.className,
        dateOfBirth: row.dateOfBirth,
        gender: row.gender,
        fatherName: row.fatherName,
        fatherPhone: row.fatherPhone,
        motherName: row.motherName,
        motherPhone: row.motherPhone,
        guardianName: row.guardianName,
        guardianPhone: row.guardianPhone,
        emergencyContact1Name: row.emergencyContact1Name,
        emergencyPhone1: row.emergencyPhone1,
        emergencyContact2Name: row.emergencyContact2Name,
        emergencyPhone2: row.emergencyPhone2,
        homeroomTeacherId: row.homeroomTeacherId,
        academicYear: row.academicYear,
        house: row.house,
        fundingType: row.fundingType,
        campus: row.campus,
        hasMedicalCondition: row.hasMedicalCondition,
        medicalConditionDetails: row.medicalConditionDetails,
        otherMedicalInfo: row.otherMedicalInfo,
        transportEnabled: row.transportEnabled,
        transportId: row.transportId,
      );
      SchoolDataService.instance.syncChildFromRegistry(record.studentId);
      created.add(record.studentId);
    }
    if (created.isNotEmpty) {
      await StudentPersistenceService.instance.saveRegistryFromService(
        syncStudentId: created.last,
        pushCloud: true,
        requireCloudSuccess: false,
      );
    }
    return created;
  }

  Future<List<String>> _importTeachers(
    List<EnrolmentTeacherDraft> rows,
    String sid,
    List<String> skipped, {
    required bool asStaff,
    List<List<String>> staffRolesByIndex = const [],
  }) async {
    final created = <String>[];
    final registry = TeacherRegistryService.instance;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final staffRoles = asStaff
          ? (i < staffRolesByIndex.length
              ? staffRolesByIndex[i]
              : const <String>[])
          : const <String>[];
      final loginKey = PhoneUtils.loginKey(row.phone);
      final phoneStatus = await AuthService.preparePhoneForStaffRegistration(
        loginKey,
        schoolId: sid,
      );
      if (phoneStatus == 'exists') {
        skipped.add('${row.fullName} (phone already registered)');
        continue;
      }
      if (phoneStatus == 'invalid_phone') {
        skipped.add('${row.fullName} (invalid phone)');
        continue;
      }
      final existingPhone = registry.lookupByPhone(row.phone, schoolId: sid);
      if (existingPhone != null) {
        skipped.add('${row.fullName} (same phone)');
        continue;
      }
      if (row.employeeId != null && row.employeeId!.trim().isNotEmpty) {
        final emp = row.employeeId!.trim().toLowerCase();
        final taken = registry.teachersForSchool(sid).any(
              (t) => (t.employeeId ?? '').trim().toLowerCase() == emp,
            );
        if (taken) {
          skipped.add('${row.fullName} (existing HR ID)');
          continue;
        }
      }

      final tempPassword = AuthService.generateTempPassword();
      var teacher = registry.addTeacher(
        schoolId: sid,
        fullName: row.fullName,
        email: row.email,
        phone: row.phone,
        employeeId: row.employeeId,
        subjects: row.subjects,
        assignedClass: row.assignedClass,
        roles: row.roles,
        loginUsername: loginKey,
        initialPassword: tempPassword,
        classAssignments: row.classAssignments,
        campus: row.campus,
        staffRoles: staffRoles,
      );
      final createdId = teacher.teacherId;
      final authError = AuthService.registerTeacherAccount(
        fullName: row.fullName,
        schoolId: sid,
        email: row.email,
        phone: row.phone.trim(),
        linkedTeacherId: createdId,
        password: tempPassword,
      );
      if (authError != null) {
        registry.removeTeacher(createdId);
        skipped.add(
          '${row.fullName} (${authError == 'exists' ? 'phone already registered' : authError})',
        );
        continue;
      }
      registry.saveCredentials(
        teacherId: createdId,
        initialPassword: tempPassword,
        loginUsername: loginKey,
      );
      teacher = registry.lookupById(createdId) ?? teacher;
      AuthService.syncTeacherAuthProfile(teacher);
      if (staffRoles.isNotEmpty) {
        final account = AuthService.findUser(loginKey);
        if (account != null) {
          final perms = SchoolRoleCatalogService.instance
              .permissionsForRoles(staffRoles, schoolId: sid)
              .toList()
            ..sort();
          account.staffRoles = List<String>.from(staffRoles);
          account.staffPermissions = perms;
        }
      }
      created.add(createdId);
    }
    if (created.isNotEmpty) {
      await TeacherPersistenceService.instance.saveRegistryFromService(
        syncTeacherId: created.last,
        pushCloud: true,
        requireCloudSuccess: false,
      );
    }
    return created;
  }
}

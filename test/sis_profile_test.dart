import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_sis_profile.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/services/transfer_workflow_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSupportService.resetForTests();
    DosaService.resetForTests();
    TransferWorkflowService.instance.applyPersistedData(requests: []);
    AuthService.currentUser = RegisteredUser(
      username: 'registrar.sis',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('SIS snapshot reads academic, health, grouping, and documents', () async {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'SIS Profile Child',
      grade: 'Grade 4',
      className: 'Grade 4A',
      dateOfBirth: DateTime(2016, 3, 1),
      house: 'Blue',
      hasMedicalCondition: true,
      medicalConditionDetails: 'Asthma',
      otherMedicalInfo: 'Inhaler in bag',
    );

    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentId: student.studentId,
        studentName: student.fullName,
        className: student.className,
        academicYear: '2025/2026',
        term: 'Term 1',
        subjects: [
          SubjectGrade(subject: 'Math', score: 88, maxScore: 100),
          SubjectGrade(subject: 'English', score: 90, maxScore: 100),
        ],
      ),
    ]);

    DisciplineService.instance.applyPersistedData([
      DisciplineCase(
        id: 'dc-sis-1',
        schoolId: 'TB-001',
        studentId: student.studentId,
        studentName: student.fullName,
        className: student.className,
        reporterId: 't1',
        reporterName: 'Teacher',
        reporterRole: 'homeroom',
        kind: DisciplineCaseKind.behaviour,
        title: 'Late to assembly',
        description: 'Twice this week',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
    ]);

    await StudentSupportService.instance.addHealthRecord(
      studentId: student.studentId,
      type: HealthRecordType.clinicVisit,
      title: 'Nurse visit',
      details: 'Used inhaler',
      schoolId: 'TB-001',
    );
    await StudentSupportService.instance.addStudentDocument(
      studentId: student.studentId,
      title: 'Birth certificate',
      category: 'identity',
      filePath: 'student_documents/birth.pdf',
      schoolId: 'TB-001',
    );

    final club = await DosaService.instance.createClub(
      name: 'Science Club',
      schoolId: 'TB-001',
    );
    await DosaService.instance.joinClub(
      clubId: club.id,
      studentId: student.studentId,
      schoolId: 'TB-001',
    );

    TransferWorkflowService.instance.applyPersistedData(
      requests: [
        TransferRequest(
          id: 'tr-sis-1',
          kind: TransferRequestKind.external,
          studentId: student.studentId,
          studentName: student.fullName,
          fromGrade: student.grade,
          fromClassName: student.className,
          fromCampus: student.campus,
          reason: 'Family moving',
          requestedBy: 'registrar',
          requestedByName: 'Registrar',
          createdAt: DateTime(2026, 9, 1),
          externalOutcome: ExternalTransferOutcome.left,
        ),
      ],
    );

    final sis = StudentSisProfile.load(student.studentId);
    expect(sis, isNotNull);
    expect(sis!.student.hasMedicalCondition, isTrue);
    expect(sis.student.house, 'Blue');
    expect(sis.academicHistory, isNotEmpty);
    expect(sis.academicHistory.first.average, 89);
    expect(sis.disciplineCases.single.title, 'Late to assembly');
    expect(sis.healthRecords.single.title, 'Nurse visit');
    expect(sis.documents.single.title, 'Birth certificate');
    expect(sis.clubNames, contains('Science Club'));
    expect(sis.groupingSummary, contains('House Blue'));
    expect(sis.groupingSummary, contains('Science Club'));
    expect(sis.movements.single.summary, contains('withdrawal'));
    expect(StudentLifecycleStatus.left.label, 'Withdrawn');
  });

  test('addStudent stores health fields used by the SIS profile', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Health Enroll Child',
      grade: 'Grade 2',
      className: 'Grade 2B',
      dateOfBirth: DateTime(2018, 5, 5),
      hasMedicalCondition: true,
      medicalConditionDetails: 'Allergy',
    );
    expect(student.hasMedicalCondition, isTrue);
    expect(
      AdminStudentRecord.fromMap(student.toMap()).medicalConditionDetails,
      'Allergy',
    );
  });
}

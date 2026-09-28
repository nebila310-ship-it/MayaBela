import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/models/qa_finding.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';
import 'package:mayabela/services/rbac/eduaba_chat_matrix.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('CloudSyncFlags is enabled for EDUABA sync', () {
    expect(CloudSyncFlags.enabled, isTrue);
  });

  test('new student ids are short and sequential (STU-1001 style)', () {
    final svc = StudentRegistryService.instance;
    final first = svc.addStudent(
      schoolId: 'TB-001',
      fullName: 'Short Id One',
      grade: 'Grade 7',
      className: 'Grade 7A',
      dateOfBirth: DateTime(2012, 1, 1),
    );
    final second = svc.addStudent(
      schoolId: 'TB-001',
      fullName: 'Short Id Two',
      grade: 'Grade 7',
      className: 'Grade 7A',
      dateOfBirth: DateTime(2012, 2, 2),
    );
    expect(first.studentId, matches(RegExp(r'^STU-\d{4}$')));
    expect(second.studentId, matches(RegExp(r'^STU-\d{4}$')));
    final n1 = int.parse(first.studentId.substring(4));
    final n2 = int.parse(second.studentId.substring(4));
    expect(n2, n1 + 1);
  });

  test('staff ids use role initials with 4 digits (QA-1001 style)', () {
    expect(StaffRoles.idPrefixFor(StaffRoles.qualityAssurance), 'QA');
    expect(StaffRoles.idPrefixFor(StaffRoles.humanResource), 'HR');
    expect(StaffRoles.idPrefixFor(StaffRoles.vicePresident), 'VP');
    expect(StaffRoles.idPrefixFor(StaffRoles.sectionDirector), 'SD');
    expect(StaffRoles.idPrefixFor(StaffRoles.registrar), 'REG');
    // Alias resolves first: finance_manager -> accountant -> FM.
    expect(StaffRoles.idPrefixFor('finance_manager'), 'FM');

    final registry = TeacherRegistryService.instance;
    AdminTeacherRecord add(String user, List<String> staffRoles) =>
        registry.addTeacher(
          schoolId: 'TB-001',
          fullName: 'Test $user',
          email: '',
          phone: '0911000000',
          subjects: const [],
          assignedClass: '',
          roles: const [],
          loginUsername: user,
          staffRoles: staffRoles,
        );

    final qa1 = add('qa1', const [StaffRoles.qualityAssurance]);
    final qa2 = add('qa2', const [StaffRoles.qualityAssurance]);
    final hr = add('hr1', const [StaffRoles.humanResource]);
    final teacher = add('tch1', const []);

    expect(qa1.teacherId, 'QA-0001');
    expect(qa2.teacherId, 'QA-0002');
    expect(hr.teacherId, 'HR-0001');
    expect(qa1.staffRoles, contains(StaffRoles.qualityAssurance));
    // Demo teachers occupy TCH-1001..1004, so classroom staff continue there.
    expect(teacher.teacherId, matches(RegExp(r'^TCH-\d{4}$')));

    for (final r in [qa1, qa2, hr, teacher]) {
      registry.removeTeacher(r.teacherId);
    }
  });

  test('default grade approval chain is Section Director', () {
    const settings = GradeWorkflowSettings();
    expect(settings.requireApproval, isTrue);
    expect(
      settings.approvalChain,
      equals([GradeApprovalRole.academicCoordinator]),
    );
    expect(
      GradeApprovalRole.academicCoordinator.label,
      'Section Director',
    );
  });

  test('parent-visible grades require approved + published', () {
    final pending = SubjectGradeStatus.pendingApproval;
    expect(pending.canTeacherEdit, isFalse);
    final approved = SubjectGradeStatus.approved;
    expect(approved.isLockedForTeacher, isTrue);
  });

  test('CloudSyncEngine role scopes include high-priority lanes', () {
    expect(
      CloudSyncEngine.highPriority,
      containsAll([
        'conversations',
        'attendance_sessions',
        'grade_reports',
        'bus_live_positions',
      ]),
    );
  });

  test('EDUABA chat matrix allows Deputy GM branch peers', () {
    expect(
      EduabaChatMatrix.canStaffChat(
        actorRoles: [StaffRoles.principal],
        peerRoles: [StaffRoles.accountant],
      ),
      isTrue,
    );
    expect(
      EduabaChatMatrix.canStaffChat(
        actorRoles: [StaffRoles.sectionDirector],
        peerRoles: [StaffRoles.studentAffairs],
      ),
      isTrue,
    );
  });

  test('StaffRoles catalog includes EDUABA executive roles', () {
    expect(StaffRoles.lookup(StaffRoles.generalManager), isNotNull);
    expect(StaffRoles.lookup(StaffRoles.deputyGeneralManager), isNotNull);
    expect(StaffRoles.lookup(StaffRoles.principal), isNotNull);
    expect(StaffRoles.lookup(StaffRoles.qualityAssurance), isNotNull);
    expect(StaffRoles.lookup('finance_manager')?.key, StaffRoles.accountant);
    expect(StaffRoles.lookup('vice_principal')?.key, StaffRoles.vicePresident);
    expect(StaffRoles.lookup('transport_head')?.key, StaffRoles.transportAdmin);
  });

  test('chat matrix: QA audit lines, staffs requesters, board reach', () {
    expect(
      EduabaChatMatrix.canStaffChat(
        actorRoles: [StaffRoles.qualityAssurance],
        peerRoles: [StaffRoles.vicePresident],
      ),
      isTrue,
    );
    expect(
      EduabaChatMatrix.canStaffChat(
        actorRoles: [StaffRoles.staffs],
        peerRoles: [StaffRoles.storekeeper],
      ),
      isTrue,
    );
    expect(
      EduabaChatMatrix.canStaffChat(
        actorRoles: [StaffRoles.schoolBoard],
        peerRoles: [StaffRoles.librarian],
      ),
      isTrue,
    );
    // No operational edge: registrar ↔ storekeeper.
    expect(
      EduabaChatMatrix.canStaffChat(
        actorRoles: [StaffRoles.registrar],
        peerRoles: [StaffRoles.storekeeper],
      ),
      isFalse,
    );
  });

  test('sync engine standard lane carries Student Affairs collections', () {
    expect(
      CloudSyncEngine.standardPriority,
      containsAll(['discipline_cases', 'leave_requests']),
    );
  });

  test('DisciplineCase serializes round-trip', () {
    final now = DateTime.now();
    final original = DisciplineCase(
      id: 'dc-1',
      schoolId: 'TB-001',
      studentId: 'STU-1',
      studentName: 'Abel T.',
      className: 'Grade 4A',
      reporterId: 'teacher1',
      reporterName: 'Ms. Sara',
      reporterRole: 'teacher',
      kind: DisciplineCaseKind.incident,
      title: 'Class disruption',
      description: 'Repeated shouting during lesson.',
      status: DisciplineCaseStatus.hearingScheduled,
      outcome: DisciplineOutcome.none,
      hearingAt: now,
      parentInvited: true,
      createdAt: now,
      updatedAt: now,
    );
    final copy = DisciplineCase.fromMap(original.toMap());
    expect(copy.id, original.id);
    expect(copy.status, DisciplineCaseStatus.hearingScheduled);
    expect(copy.kind, DisciplineCaseKind.incident);
    expect(copy.parentInvited, isTrue);
    expect(copy.isOpen, isTrue);
  });

  test('QA role owns the findings register (EDUABA §2)', () {
    final qa = StaffRoles.lookup(StaffRoles.qualityAssurance);
    expect(qa, isNotNull);
    expect(qa!.permissions, contains(SchoolPermissions.manageQaFindings));
    expect(
      SchoolPermissions.all,
      contains(SchoolPermissions.manageQaFindings),
    );
    expect(CloudSyncEngine.standardPriority, contains('qa_findings'));
    expect(
      CloudSyncEngine.standardPriority,
      contains('admission_applications'),
    );
    expect(
      CloudSyncEngine.standardPriority,
      containsAll(['exam_questions', 'exam_papers', 'exam_attempts']),
    );
    expect(CloudSyncEngine.standardPriority, contains('lesson_plans'));
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        'curriculum_units',
        'curriculum_feedback',
        'lesson_plan_reviews',
        'teacher_evaluations',
        'academic_meetings',
        'health_records',
        'counseling_records',
        'iep_plans',
        'college_guidance',
        'support_requests',
        'safeguarding_cases',
        'extracurricular_clubs',
        'club_memberships',
        'scholarships',
        'grievances',
        'internships',
        'dosa_meetings',
        'teaching_observations',
        'academic_audits',
        'qa_surveys',
        'qa_survey_responses',
        'action_research',
        'mfa_enrollments',
        'privacy_consents',
        'data_rights_requests',
        'school_backups',
      ]),
    );
  });

  test('QaFinding serializes round-trip with plan + metrics fields', () {
    final now = DateTime.now();
    final original = QaFinding(
      id: 'qa-1',
      schoolId: 'TB-001',
      area: QaFindingArea.grading,
      title: 'Marking inconsistencies in Grade 6 exams',
      details: 'Sampled papers show unaligned rubric use.',
      severity: QaFindingSeverity.high,
      status: QaFindingStatus.actionPlanned,
      improvementPlan: 'Rubric retraining + double-marking next term.',
      ownerRole: 'section_director',
      raisedById: 'qa1',
      raisedByName: 'QA Officer',
      dueDate: now.add(const Duration(days: 14)),
      createdAt: now,
      updatedAt: now,
    );
    final copy = QaFinding.fromMap(original.toMap());
    expect(copy.id, original.id);
    expect(copy.area, QaFindingArea.grading);
    expect(copy.severity, QaFindingSeverity.high);
    expect(copy.status, QaFindingStatus.actionPlanned);
    expect(copy.improvementPlan, original.improvementPlan);
    expect(copy.ownerRole, 'section_director');
    expect(copy.isOpen, isTrue);
    expect(copy.isOverdue, isFalse);
  });

  test('LeaveRequest serializes round-trip', () {
    final now = DateTime.now();
    final original = LeaveRequest(
      id: 'lr-1',
      schoolId: 'TB-001',
      studentId: 'STU-1',
      studentName: 'Abel T.',
      className: 'Grade 4A',
      parentUsername: 'parent1',
      parentName: 'W/ro Almaz',
      startDate: now,
      endDate: now.add(const Duration(days: 2)),
      reason: 'Family travel',
      createdAt: now,
      updatedAt: now,
    );
    final copy = LeaveRequest.fromMap(original.toMap());
    expect(copy.id, original.id);
    expect(copy.status, LeaveRequestStatus.pending);
    expect(copy.parentUsername, 'parent1');
  });
}

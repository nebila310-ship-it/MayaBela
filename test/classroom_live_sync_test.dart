import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/cloud/conversation_document.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/lms_classroom_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/setup/dashboard_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  test('parent sees class discussion by linked student even without names', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.live',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-LIVE-1'],
    );

    final conversation = Conversation(
      id: 'group-grade-4a-class-discussion',
      name: 'Grade 4A class discussion',
      role: 'Group',
      isGroup: true,
      messages: const [],
      linkedStudentIds: const ['stu-live-1'],
    );

    expect(conversation.isVisibleToRole(AuthService.roleParent), isTrue);
  });

  test('student sees class discussion by linkedStudentIds', () {
    AuthService.currentUser = RegisteredUser(
      username: 'student.live',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      linkedStudentId: 'STU-LIVE-1',
    );

    final conversation = Conversation(
      id: 'group-grade-4a-class-discussion',
      name: 'Grade 4A class discussion',
      role: 'Group',
      isGroup: true,
      messages: const [],
      linkedStudentIds: const ['STU-LIVE-1'],
    );

    expect(conversation.isVisibleToRole(AuthService.roleStudent), isTrue);
  });

  test('class discussion cloud map stamps studentIds for student RLS', () {
    final doc = ConversationDocument.fromConversation(
      Conversation(
        id: 'group-4a',
        name: '4A class discussion',
        role: 'Group',
        isGroup: true,
        messages: const [],
        linkedStudentIds: const ['STU-LIVE-1', 'STU-LIVE-2'],
      ),
    );
    final map = doc.toMap();
    expect(map['studentIds'], ['STU-LIVE-1', 'STU-LIVE-2']);
    expect(map['linkedStudentIds'], ['STU-LIVE-1', 'STU-LIVE-2']);
  });

  test('newer pending grade report replaces stale local approved copy', () {
    const studentName = 'Live Sync Grade Student';
    const className = 'Grade 9LS';
    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: studentName,
        className: className,
        term: 'Term 1',
        studentId: 'STU-LS-9',
        subjects: [
          SubjectGrade(
            subject: 'Mathematics',
            score: 70,
            maxScore: 100,
            status: SubjectGradeStatus.approved,
          ),
        ],
      ),
    ]);

    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: studentName,
        className: className,
        term: 'Term 1',
        studentId: 'STU-LS-9',
        subjects: [
          SubjectGrade(
            subject: 'Mathematics',
            score: 91,
            maxScore: 100,
            status: SubjectGradeStatus.pendingApproval,
            submittedAt: DateTime.utc(2026, 10, 8, 9),
          ),
        ],
      ),
    ]);

    final pending = SchoolDataService.instance.pendingGradeApprovals();
    expect(
      pending.any(
        (item) =>
            item.report.studentName == studentName &&
            item.subject == 'Mathematics' &&
            item.subjectGrade.status == SubjectGradeStatus.pendingApproval &&
            item.subjectGrade.score == 91,
      ),
      isTrue,
    );
  });

  test('attendance cloud map includes roster studentIds', () {
    final map = AppDataMaps.attendanceSessionToMap(
      AttendanceSession(
        className: 'Grade 4A',
        date: DateTime.utc(2026, 10, 8),
        conductedBy: 'Abebe',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Liya',
            studentId: 'STU-LIVE-1',
            status: AttendanceStatus.absent,
            updatedAt: DateTime.utc(2026, 10, 8, 8),
          ),
          StudentAttendanceEntry(
            studentName: 'Yonas',
            studentId: 'STU-LIVE-2',
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );
    expect(map['studentIds'], containsAll(['STU-LIVE-1', 'STU-LIVE-2']));
  });

  test('pulled absent mark wins over local demo present without timestamp', () {
    final date = DateTime.utc(2026, 10, 8);
    SchoolDataService.instance.applyPersistedAttendance([
      AttendanceSession(
        className: 'Grade 9LS',
        date: date,
        conductedBy: 'Seed',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Live Sync Child',
            studentId: 'STU-LS-ATT',
            status: AttendanceStatus.present,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      ),
    ]);
    SchoolDataService.instance.applyPersistedAttendance([
      AttendanceSession(
        className: 'Grade 9LS',
        date: date,
        conductedBy: 'Abebe',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Live Sync Child',
            studentId: 'STU-LS-ATT',
            status: AttendanceStatus.absent,
          ),
        ],
      ),
    ]);

    final session = SchoolDataService.instance.getAttendanceSession(
      'Grade 9LS',
      date,
    );
    expect(session, isNotNull);
    expect(session!.entries.single.status, AttendanceStatus.absent);
  });

  test('live attendance is not replaced by an unmatched local roster', () {
    final date = DateTime.utc(2026, 10, 8);
    SchoolDataService.instance.applyPersistedAttendance([
      AttendanceSession(
        className: 'Grade 9LS-ROSTER',
        date: date,
        conductedBy: 'Abebe',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Exact Taken Child',
            studentId: 'STU-LS-EXACT',
            status: AttendanceStatus.absent,
            updatedAt: DateTime.utc(2026, 10, 8, 8),
          ),
        ],
      ),
    ]);

    final view = SchoolDataService.instance.attendanceRegisterView(
      className: 'Grade 9LS-ROSTER',
      date: date,
    );
    expect(
      view.entries.any(
        (entry) =>
            entry.studentId == 'STU-LS-EXACT' &&
            entry.status == AttendanceStatus.absent,
      ),
      isTrue,
    );
  });

  test('parent homework uses JWT class names on a fresh phone', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.hw',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-HW-1'],
    );
    AuthService.applyCloudAccessScope(
      linkedClassNames: const ['Grade 4A'],
      linkedStudentIds: const ['STU-HW-1'],
    );
    SchoolDataService.instance.applyPersistedHomework([
      HomeworkItem(
        id: 'HW-LIVE-1',
        className: '4A',
        subject: 'English',
        description: 'Read chapter 2',
        teacherName: 'Abebe',
        teacherId: 'TCH-1004',
        postedAt: DateTime.utc(2026, 10, 8),
      ),
    ]);

    expect(AuthService.accessClassNamesForSync(), contains('Grade 4A'));
    expect(
      SchoolDataService.instance.getHomeworkForParent().map((h) => h.id),
      contains('HW-LIVE-1'),
    );
  });

  test('daily activity cloud map includes studentIds', () {
    final map = DailyActivityReport(
      id: 'DA-LIVE-1',
      studentId: 'STU-LIVE-1',
      studentName: 'Liya',
      className: 'Grade 4A',
      date: DateTime.utc(2026, 10, 8),
      selectedOptionIds: const ['focus'],
      teacherComment: 'Good day',
      teacherName: 'Abebe',
    ).toMap();
    expect(map['studentId'], 'STU-LIVE-1');
    expect(map['studentIds'], ['STU-LIVE-1']);
  });

  test(
    'parent and student dashboards include daily activity and discussion',
    () {
      registerAllDashboards();
      final parentIds = sectionDefinitionsFor(
        AuthService.roleParent,
      ).expand((s) => s.entryIds).toSet();
      final studentIds = sectionDefinitionsFor(
        AuthService.roleStudent,
      ).expand((s) => s.entryIds).toSet();
      expect(parentIds, containsAll(['daily_activities', 'class_discussion']));
      expect(studentIds, containsAll(['daily_activities', 'class_discussion']));
      expect(
        DashboardRegistry.find(AuthService.roleParent, 'class_discussion'),
        isNotNull,
      );
      expect(
        DashboardRegistry.find(AuthService.roleStudent, 'daily_activities'),
        isNotNull,
      );
    },
  );

  test('ensureClassDiscussion restamps parents onto an existing thread', () {
    const className = 'Grade 5B';
    SchoolDataService.instance.ensureNamedGroupConversation(
      groupName: LmsClassroomService.discussionTitle(className),
      parentNames: const [],
      staffIds: const [],
      linkedStudentIds: const [],
    );

    final id = LmsClassroomService.instance.ensureClassDiscussion(className);
    final conversation = SchoolDataService.instance.getConversation(id);
    expect(conversation, isNotNull);
    expect(conversation!.linkedStudentIds, isNotEmpty);
  });

  test('teacher homework push drops other-class seed rows', () {
    final kept = CloudAppStore.teacherWritableByClass(
      items: [
        HomeworkItem(
          id: 'hw-keep',
          className: 'Grade 5B',
          subject: 'Math',
          description: 'Live homework',
          teacherName: 'Abebe',
          teacherId: 'TCH-KEEP',
          postedAt: DateTime.utc(2026, 10, 9),
        ),
        HomeworkItem(
          id: 'hw-1',
          className: 'Grade 4A',
          subject: 'English',
          description: 'Demo seed',
          teacherName: 'Seed',
          teacherId: 'TCH-SEED',
          postedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      classNameOf: (item) => item.className,
      roleKey: AuthService.roleTeacher,
      assignedClasses: const ['5B'],
    );
    expect(kept.map((item) => item.id), ['hw-keep']);
  });

  test('teacher JWT classes union with registry classes', () {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      linkedTeacherId: 'TCH-1001',
    );
    AuthService.applyCloudAccessScope(assignedClassNames: const ['Grade 9QA']);
    final names = AuthService.accessClassNamesForSync();
    expect(names, containsAll(['Grade 4A', 'Grade 5B', 'Grade 9QA']));
  });

  test('parent homework class picker includes JWT classes', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.hw2',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-HW-2'],
    );
    AuthService.applyCloudAccessScope(
      linkedClassNames: const ['Grade 4A'],
      linkedStudentIds: const ['STU-HW-2'],
    );
    expect(
      SchoolDataService.instance.homeworkClassOptionsForViewer(),
      contains('Grade 4A'),
    );
  });

  test('admin grade queue keeps this-school pending when names collide', () {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-OTHER-Q',
        fullName: 'Queue Twin Student',
        grade: '9',
        className: 'Grade 9QA',
        schoolId: 'OTHER-001',
        dateOfBirth: DateTime(2012, 1, 1),
      ),
      AdminStudentRecord(
        studentId: 'STU-OURS-Q',
        fullName: 'Queue Twin Student',
        grade: '9',
        className: 'Grade 9QA',
        schoolId: 'FR-001',
        dateOfBirth: DateTime(2012, 1, 1),
      ),
    ]);
    AuthService.currentUser = RegisteredUser(
      username: 'admin.queue',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'FR-001',
    );
    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: 'Queue Twin Student',
        className: 'Grade 9QA',
        term: 'Term 1',
        studentId: 'STU-OURS-Q',
        subjects: [
          SubjectGrade(
            subject: 'Mathematics',
            score: 88,
            maxScore: 100,
            status: SubjectGradeStatus.pendingApproval,
            submittedAt: DateTime.utc(2026, 10, 9, 8),
          ),
        ],
      ),
    ]);

    final pending = SchoolDataService.instance.adminGradeReviewItems(
      schoolId: 'FR-001',
    );
    expect(
      pending.any(
        (item) =>
            item.report.studentId == 'STU-OURS-Q' &&
            item.subject == 'Mathematics' &&
            item.subjectGrade.status == SubjectGradeStatus.pendingApproval,
      ),
      isTrue,
    );
  });

  test('grade cloud id uses student name when studentId is missing', () {
    expect(
      CloudAppStore.gradeDocIdForTest({
        'studentName': 'Abebe Tesfaye',
        'className': 'Grade 4A',
        'term': 'Term 1',
      }),
      'Abebe_Tesfaye_Grade_4A_Term_1',
    );
    expect(
      CloudAppStore.gradeDocIdForTest({
        'studentId': 'STU-1',
        'studentName': 'Abebe Tesfaye',
        'className': 'Grade 4A',
        'term': 'Term 1',
      }),
      isNot(
        CloudAppStore.gradeDocIdForTest({
          'studentId': 'STU-2',
          'studentName': 'Chaltu Lemma',
          'className': 'Grade 4A',
          'term': 'Term 1',
        }),
      ),
    );
  });

  test('attendance teacher push keeps only assigned-class sessions', () {
    final kept = CloudAppStore.teacherWritableByClass(
      items: [
        AttendanceSession(
          className: 'Grade 5B',
          date: DateTime.utc(2026, 10, 9),
          conductedBy: 'Abebe',
          entries: const [],
        ),
        AttendanceSession(
          className: 'Grade 4A',
          date: DateTime.utc(2026, 10, 9),
          conductedBy: 'Seed',
          entries: const [],
        ),
      ],
      classNameOf: (session) => session.className,
      roleKey: AuthService.roleTeacher,
      assignedClasses: const ['Grade 5B'],
    );
    expect(kept.map((session) => session.className), ['Grade 5B']);
  });
}

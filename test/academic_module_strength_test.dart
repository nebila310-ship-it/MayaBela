import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/attendance_intelligence_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/grade_audit_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/lms_classroom_service.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/report_card_pdf_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GradeAuditService.resetForTests();
    ExamService.resetForTests();
    LessonPlanService.resetForTests();
    AttendanceIntelligenceService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'director.term',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    GradeAuditService.resetForTests();
    ExamService.resetForTests();
    LessonPlanService.resetForTests();
    AttendanceIntelligenceService.resetForTests();
  });

  test('missing-marks board lists blank categories and draft workflow', () {
    const className = 'Grade 7A-TERM';
    StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Amina Term',
      grade: '7',
      className: className,
      dateOfBirth: DateTime(2013, 3, 1),
    );
    final result = MarkbookService.instance.enterClassAssessments(
      className: className,
      subject: 'Science',
      teacherId: 'director.term',
      assessmentsByStudent: {
        'Amina Term': [
          AssessmentMark(
            categoryId: 'quiz',
            label: 'Quizzes',
            weightPercent: 15,
            score: 80,
          ),
          AssessmentMark(
            categoryId: 'homework',
            label: 'Homework',
            weightPercent: 10,
          ),
        ],
      },
    );
    expect(result.saved, 1);

    final gaps = MarkbookService.instance.missingMarks(
      className: className,
      subject: 'Science',
    );
    expect(gaps, isNotEmpty);
    expect(gaps.first.studentName, 'Amina Term');
    expect(gaps.first.blankCategories, isNotEmpty);
    expect(gaps.first.workflowOpen, isTrue);
  });

  test('grade audit filter matches class, subject, teacher, and date', () async {
    await GradeAuditService.instance.log(
      action: GradeAuditAction.submitted,
      schoolId: 'TB-001',
      className: 'Grade 7A-TERM',
      subject: 'Science',
      studentName: 'Amina Term',
      actorName: 'Ms Hana',
      detail: '80 → 82',
    );
    await GradeAuditService.instance.log(
      action: GradeAuditAction.approved,
      schoolId: 'TB-001',
      className: 'Grade 8B-TERM',
      subject: 'Math',
      studentName: 'Belen Term',
      actorName: 'Mr Kaleb',
    );

    final filtered = GradeAuditService.instance.filtered(
      schoolId: 'TB-001',
      className: 'Grade 7A-TERM',
      subject: 'Science',
      teacherName: 'Hana',
    );
    expect(filtered, hasLength(1));
    expect(filtered.single.detail, '80 → 82');
    expect(
      GradeAuditService.instance.filtered(
        schoolId: 'TB-001',
        teacherName: 'nobody',
      ),
      isEmpty,
    );
  });

  test('class-set report cards publish, rank, and bulk PDF', () async {
    final data = SchoolDataService.instance;
    const className = 'Grade 6C-TERM';
    StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Sara Rank',
      grade: '6',
      className: className,
      dateOfBirth: DateTime(2014, 1, 1),
    );
    StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Dawit Rank',
      grade: '6',
      className: className,
      dateOfBirth: DateTime(2014, 2, 1),
    );
    final first = data.openTermGradeReport(
      studentName: 'Sara Rank',
      className: className,
      term: 'Term 1',
      academicYear: '2026',
    );
    first.subjects.add(
      SubjectGrade(subject: 'Science', score: 90, maxScore: 100),
    );
    final second = data.openTermGradeReport(
      studentName: 'Dawit Rank',
      className: className,
      term: 'Term 1',
      academicYear: '2026',
    );
    second.subjects.add(
      SubjectGrade(subject: 'Science', score: 70, maxScore: 100),
    );

    expect(data.rankForStudent('Sara Rank', className), 1);
    expect(data.rankForStudent('Dawit Rank', className), 2);

    final published = MarkbookService.instance.publishClassReportCards(
      className: className,
    );
    expect(published, 2);
    expect(first.reportCardPublished, isTrue);
    expect(second.reportCardPublished, isTrue);

    final bytes = await ReportCardPdfService.instance.buildClassSetBytes(
      reports: [first, second],
      schoolName: 'Test School',
      ranks: {
        'Sara Rank': 1,
        'Dawit Rank': 2,
      },
    );
    expect(bytes.length, greaterThan(400));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(
      ReportCardPdfService.instance.fileNameForClass(className, 'Term 1'),
      'grade_reports_Grade_6C_TERM_Term_1.pdf',
    );
  });

  test('period attendance identity includes cover teacher and early leave', () {
    final data = SchoolDataService.instance;
    const className = 'Grade 9P-TERM';
    final day = DateTime.utc(2026, 11, 23);
    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Ms Hana',
        notifyParents: false,
        periodKey: 'slot_math_2',
        periodLabel: 'Period 2 · Mathematics',
        coverTeacherName: 'Mr Cover',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Period Cut',
            studentId: 'STU-PC1',
            status: AttendanceStatus.earlyLeave,
            updatedAt: DateTime.utc(2026, 11, 23, 10),
          ),
        ],
      ),
      isTrue,
    );
    final session = data.getAttendanceSession(
      className,
      day,
      periodKey: 'slot_math_2',
    )!;
    expect(session.coverTeacherName, 'Mr Cover');
    expect(session.entries.single.status, AttendanceStatus.earlyLeave);

    final mapped = AppDataMaps.attendanceSessionToMap(session);
    expect(mapped['periodKey'], 'slot_math_2');
    expect(mapped['coverTeacherName'], 'Mr Cover');
    final roundTrip = AppDataMaps.attendanceSessionFromMap(mapped);
    expect(roundTrip.coverTeacherName, 'Mr Cover');
    expect(roundTrip.entries.single.status, AttendanceStatus.earlyLeave);

    final snap = data.attendanceSnapshotForStudent(
      studentName: 'Period Cut',
      className: className,
      includePeriodSessions: true,
    );
    expect(snap.earlyLeave, 1);
    expect(snap.sessions, 1);
  });

  test('at-risk counts period cuts when the daily register is present', () {
    final data = SchoolDataService.instance;
    const className = 'Grade 9R-TERM';
    const student = 'Cut Kid';
    data.saveAttendanceSession(
      className: className,
      date: DateTime.utc(2026, 11, 16),
      conductedBy: 'Ms Hana',
      notifyParents: false,
      entries: [
        StudentAttendanceEntry(
          studentName: student,
          status: AttendanceStatus.present,
          taken: true,
        ),
      ],
    );
    data.saveAttendanceSession(
      className: className,
      date: DateTime.utc(2026, 11, 16),
      conductedBy: 'Ms Hana',
      notifyParents: false,
      periodKey: 'slot_eng_1',
      periodLabel: 'Period 1 · English',
      entries: [
        StudentAttendanceEntry(
          studentName: student,
          status: AttendanceStatus.absent,
          taken: true,
        ),
      ],
    );
    data.saveAttendanceSession(
      className: className,
      date: DateTime.utc(2026, 11, 17),
      conductedBy: 'Ms Hana',
      notifyParents: false,
      entries: [
        StudentAttendanceEntry(
          studentName: student,
          status: AttendanceStatus.present,
          taken: true,
        ),
      ],
    );
    data.saveAttendanceSession(
      className: className,
      date: DateTime.utc(2026, 11, 17),
      conductedBy: 'Ms Hana',
      notifyParents: false,
      periodKey: 'slot_eng_1',
      periodLabel: 'Period 1 · English',
      entries: [
        StudentAttendanceEntry(
          studentName: student,
          status: AttendanceStatus.absent,
          taken: true,
        ),
      ],
    );

    final snap = data.attendanceSnapshotForStudent(
      studentName: student,
      className: className,
      includePeriodSessions: true,
    );
    expect(snap.periodAbsent, 2);

    final profiles = AttendanceIntelligenceService.instance.profiles(
      className: className,
    );
    expect(profiles, isNotEmpty);
    expect(
      profiles.first.patterns.any((p) => p.kind == AbsencePatternKind.periodCuts),
      isTrue,
    );
  });

  test('exam sitting absentee does not become a markbook zero', () async {
    final paper = await ExamService.instance.createPaper(
      title: 'Term science paper',
      className: 'Grade 4A-TERM',
      subject: 'Science',
      sittingMode: ExamSittingMode.offline,
      room: 'Hall 2',
      invigilatorName: 'Ms Invigilator',
      schoolId: 'TB-001',
    );
    expect(paper.room, 'Hall 2');
    expect(paper.invigilatorName, 'Ms Invigilator');

    final attempt = await ExamService.instance.flagSitting(
      paperId: paper.id,
      studentName: 'Absent Sit',
      flag: ExamSittingFlag.absent,
      className: 'Grade 4A-TERM',
    );
    expect(attempt.sittingFlag, ExamSittingFlag.absent);
    expect(
      ExamService.instance.pushAttemptToMarkbook(attempt.id),
      isFalse,
    );
    expect(
      () => ExamService.instance.recordStaffOfflineResult(
        paperId: paper.id,
        studentName: 'Absent Sit',
        percent: 0,
      ),
      throwsStateError,
    );
  });

  test('LMS course feed and late-work inbox use existing homework', () {
    final data = SchoolDataService.instance;
    const className = 'Grade 5F-TERM';
    StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Late Learner',
      grade: '5',
      className: className,
      dateOfBirth: DateTime(2015, 2, 2),
    );
    LessonPlanService.instance.applyPersistedData([
      LessonPlan(
        id: 'LP-TERM-1',
        schoolId: 'TB-001',
        title: 'Fractions',
        className: className,
        subject: 'Math',
        weekStart: DateTime.utc(2026, 11, 16),
        createdAt: DateTime.utc(2026, 11, 16),
        updatedAt: DateTime.utc(2026, 11, 16),
      ),
    ]);
    data.addHomework(
      className: className,
      subject: 'Math',
      title: 'Worksheet 4',
      description: 'Finish page 12',
      teacherName: 'Ms Hana',
      teacherId: 'TCH-1',
      dueDate: DateTime.utc(2026, 11, 1),
    );

    final feed = LmsClassroomService.instance.courseFeed(
      className: className,
      subject: 'Math',
      schoolId: 'TB-001',
    );
    expect(feed.map((item) => item.kind), contains(LmsFeedKind.lesson));
    expect(feed.map((item) => item.kind), contains(LmsFeedKind.homework));

    final late = LmsClassroomService.instance.lateWorkInbox(
      schoolId: 'TB-001',
      className: className,
      subject: 'Math',
    );
    expect(late, isNotEmpty);
    expect(late.first.studentName, 'Late Learner');
    expect(late.first.homeworkTitle, 'Worksheet 4');
  });

  test('at-risk intervention notes notify homeroom and track follow-up', () {
    final item = AttendanceIntelligenceService.instance.addIntervention(
      studentName: 'Cut Kid',
      className: 'Grade 9R-TERM',
      note: 'Called mother. Agreed daily check-in.',
      kind: RiskInterventionKind.parentMeeting,
      followUpAt: DateTime.utc(2026, 12, 1),
      notifyHomeroom: true,
    );
    expect(item.notifyHomeroom, isTrue);
    expect(
      AttendanceIntelligenceService.instance
          .interventionsFor(studentName: 'Cut Kid')
          .single
          .note,
      contains('daily check-in'),
    );
    expect(
      AttendanceIntelligenceService.instance.markParentFollowedUp(item.id),
      isTrue,
    );
    expect(
      AttendanceIntelligenceService.instance
          .interventionsFor(studentName: 'Cut Kid')
          .single
          .parentFollowedUp,
      isTrue,
    );
    expect(
      SchoolDataService.instance.announcementsSnapshot().any(
        (a) => a.title.contains('At-risk follow-up'),
      ),
      isTrue,
    );
  });
}

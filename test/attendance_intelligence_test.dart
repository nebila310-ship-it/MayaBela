import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/attendance_intelligence_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const andClass = 'Grade 9Z-AND';
  const fridayClass = 'Grade 9Z-FRI';
  const hiddenClass = 'Grade 9Z-HID';
  const insightClass = 'Grade 9Z-INS';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'vp.intel',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('profile serializes with patterns and risk level', () {
    final original = StudentRiskProfile(
      studentName: 'Amina Hailu',
      className: andClass,
      studentId: 'STU-9001',
      level: RiskLevel.atRisk,
      present: 2,
      late: 0,
      absent: 4,
      sessions: 6,
      absenceRate: 4 / 6,
      lateRate: 0,
      attendanceRate: 2 / 6,
      consecutiveAbsences: 3,
      gradeAverage: 41,
      hasGrades: true,
      patterns: const [
        AbsencePattern(
          kind: AbsencePatternKind.consecutiveAbsences,
          label: '3 consecutive absences',
        ),
      ],
    );
    final copy = StudentRiskProfile.fromMap(original.toMap());
    expect(copy.level, RiskLevel.atRisk);
    expect(copy.absenceRate, closeTo(4 / 6, 0.0001));
    expect(copy.patterns, hasLength(1));
    expect(copy.patterns.first.kind, AbsencePatternKind.consecutiveAbsences);
    expect(copy.isAtRisk, isTrue);
  });

  test('at-risk requires low grades AND high absence', () {
    final monday = DateTime.utc(2026, 8, 3);
    _seedSessions(
      className: andClass,
      students: {
        'Amina Hailu': [
          AttendanceStatus.absent,
          AttendanceStatus.absent,
          AttendanceStatus.absent,
          AttendanceStatus.absent,
        ],
        'Bekele Tadesse': [
          AttendanceStatus.absent,
          AttendanceStatus.absent,
          AttendanceStatus.absent,
          AttendanceStatus.absent,
        ],
        'Chaltu Lemma': [
          AttendanceStatus.present,
          AttendanceStatus.present,
          AttendanceStatus.present,
          AttendanceStatus.present,
        ],
      },
      start: monday,
    );
    _seedGrades(andClass, {
      'Amina Hailu': 38,
      'Bekele Tadesse': 82,
      'Chaltu Lemma': 36,
    });

    final intel = AttendanceIntelligenceService.instance;
    final flags = intel.atRiskFlags(className: andClass);
    expect(flags.map((p) => p.studentName), ['Amina Hailu']);

    final amina = intel
        .profiles(className: andClass)
        .firstWhere((p) => p.studentName == 'Amina Hailu');
    expect(amina.level, RiskLevel.atRisk);
    expect(amina.patterns.any((p) => p.kind == AbsencePatternKind.consecutiveAbsences), isTrue);
    expect(amina.patterns.any((p) => p.kind == AbsencePatternKind.chronicAbsence), isTrue);

    final bekele = intel
        .profiles(className: andClass)
        .firstWhere((p) => p.studentName == 'Bekele Tadesse');
    expect(bekele.level, RiskLevel.attendanceWatch);

    final chaltu = intel
        .profiles(className: andClass)
        .firstWhere((p) => p.studentName == 'Chaltu Lemma');
    expect(chaltu.level, RiskLevel.academicWatch);
  });

  test('weekday cluster is detected from existing sessions', () {
    final fridays = [
      DateTime.utc(2026, 8, 7),
      DateTime.utc(2026, 8, 14),
      DateTime.utc(2026, 8, 21),
      DateTime.utc(2026, 8, 28),
    ];
    SchoolDataService.instance.applyPersistedAttendance([
      for (final day in fridays)
        AttendanceSession(
          className: fridayClass,
          date: day,
          conductedBy: 'Ms. Test',
          entries: [
            StudentAttendanceEntry(
              studentName: 'Dawit Friday',
              status: AttendanceStatus.absent,
            ),
          ],
        ),
    ]);
    _seedGrades(fridayClass, {'Dawit Friday': 70});

    final profile = AttendanceIntelligenceService.instance
        .profiles(className: fridayClass)
        .firstWhere((p) => p.studentName == 'Dawit Friday');
    expect(
      profile.patterns.any((p) => p.kind == AbsencePatternKind.weekdayCluster),
      isTrue,
    );
  });

  test('students and parents never see at-risk flags', () {
    _seedSessions(
      className: hiddenClass,
      students: {
        'Hidden Risk': [
          AttendanceStatus.absent,
          AttendanceStatus.absent,
          AttendanceStatus.absent,
          AttendanceStatus.absent,
        ],
      },
      start: DateTime.utc(2026, 8, 3),
    );
    _seedGrades(hiddenClass, {'Hidden Risk': 30});
    expect(
      AttendanceIntelligenceService.instance.atRiskCount(className: hiddenClass),
      1,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'sara',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
    );
    expect(
      AttendanceIntelligenceService.instance.profiles(className: hiddenClass),
      isEmpty,
    );
    expect(
      AttendanceIntelligenceService.instance.teacherInsights(className: hiddenClass),
      isEmpty,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.sara',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      AttendanceIntelligenceService.instance.atRiskFlags(className: hiddenClass),
      isEmpty,
    );
  });

  test('teacher insights compare high-absence marks to the rest of the class', () {
    _seedSessions(
      className: insightClass,
      students: {
        'Low Both': [
          AttendanceStatus.absent,
          AttendanceStatus.absent,
          AttendanceStatus.absent,
          AttendanceStatus.present,
        ],
        'Present High': [
          AttendanceStatus.present,
          AttendanceStatus.present,
          AttendanceStatus.present,
          AttendanceStatus.present,
        ],
      },
      start: DateTime.utc(2026, 8, 3),
    );
    _seedGrades(insightClass, {
      'Low Both': 40,
      'Present High': 90,
    });

    final insight = AttendanceIntelligenceService.instance
        .teacherInsights(className: insightClass)
        .single;
    expect(insight.atRiskCount, 1);
    expect(insight.highAbsenceGradeAverage, 40);
    expect(insight.othersGradeAverage, 90);
    expect(insight.note, contains('high absence'));
  });

  test('analytics never write grades or exam scores', () {
    final before = SchoolDataService.instance.getAllGradeReports().length;
    AttendanceIntelligenceService.instance.profiles(className: insightClass);
    AttendanceIntelligenceService.instance.teacherInsights(className: insightClass);
    expect(SchoolDataService.instance.getAllGradeReports(), hasLength(before));
  });

  test('at-risk rides the attendance module', () {
    expect(ModuleAccess.canView('at_risk'), isTrue);
    expect(ModuleAccess.canManage('at_risk'), isTrue);
    expect(ModuleAccess.normalize('at_risk'), 'attendance');
    expect(ModuleAccess.normalize('attendance_insights'), 'attendance');

    AuthService.currentUser = RegisteredUser(
      username: 'owner.intel',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('at_risk'));
    expect(ids, contains('attendance'));
  });
}

void _seedSessions({
  required String className,
  required Map<String, List<AttendanceStatus>> students,
  required DateTime start,
}) {
  final days = students.values.map((s) => s.length).fold<int>(0, (a, b) => a > b ? a : b);
  SchoolDataService.instance.applyPersistedAttendance([
    for (var i = 0; i < days; i++)
      AttendanceSession(
        className: className,
        date: start.add(Duration(days: i)),
        conductedBy: 'Ms. Test',
        entries: [
          for (final entry in students.entries)
            if (i < entry.value.length)
              StudentAttendanceEntry(
                studentName: entry.key,
                status: entry.value[i],
              ),
        ],
      ),
  ]);
}

void _seedGrades(String className, Map<String, double> averages) {
  SchoolDataService.instance.applyPersistedGradeReports([
    for (final entry in averages.entries)
      StudentGradeReport(
        studentName: entry.key,
        className: className,
        term: 'Term 1',
        subjects: [
          SubjectGrade(subject: 'Science', score: entry.value, maxScore: 100),
        ],
      ),
  ]);
}

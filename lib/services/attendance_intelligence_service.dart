import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';

/// Rule-based attendance intelligence on top of live sessions + Phase B grades.
/// Does not write attendance, markbook scores, or admissions fields.
class AttendanceIntelligenceService {
  AttendanceIntelligenceService._();
  static final instance = AttendanceIntelligenceService._();

  final _data = SchoolDataService.instance;

  bool get _isPublicReader {
    final role = AuthService.currentUser?.roleKey;
    return role == AuthService.roleStudent || role == AuthService.roleParent;
  }

  Set<String>? _scopeClasses({
    String? className,
    Iterable<String>? classNames,
  }) {
    if (className != null && className.trim().isNotEmpty) {
      return {className.trim()};
    }
    if (classNames != null) {
      return classNames.map((n) => n.trim()).where((n) => n.isNotEmpty).toSet();
    }
    return null;
  }

  /// Classroom teachers only see assigned classes unless they can open the
  /// staff attendance module school-wide.
  Set<String>? _roleScope(Set<String>? requested) {
    if (_isPublicReader) return const {};
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleTeacher) {
      final staff = AuthService.currentUser?.staffRoles ?? const <String>[];
      if (staff.isEmpty) {
        final mine = TeacherAccessService.instance.myClasses
            .map((a) => a.className)
            .toSet();
        if (requested == null) return mine;
        return requested.intersection(mine);
      }
    }
    return requested;
  }

  List<StudentRiskProfile> profiles({
    String? className,
    Iterable<String>? classNames,
  }) {
    if (_isPublicReader) return const [];
    final allowed = _roleScope(_scopeClasses(
      className: className,
      classNames: classNames,
    ));
    if (allowed != null && allowed.isEmpty) return const [];

    final roster = <String, _StudentKey>{};
    for (final session in _data.attendanceSnapshot()) {
      if (allowed != null && !allowed.contains(session.className)) continue;
      for (final entry in session.entries) {
        final key = '${session.className}\u0000${entry.studentName}';
        roster[key] = _StudentKey(session.className, entry.studentName);
      }
    }
    for (final report in _data.getAllGradeReports()) {
      if (allowed != null && !allowed.contains(report.className)) continue;
      final key = '${report.className}\u0000${report.studentName}';
      roster.putIfAbsent(
        key,
        () => _StudentKey(report.className, report.studentName),
      );
    }

    final out = <StudentRiskProfile>[];
    for (final item in roster.values) {
      out.add(_profileFor(item.className, item.studentName));
    }
    out.sort((a, b) {
      final level = b.level.index.compareTo(a.level.index);
      if (level != 0) return level;
      return a.studentName.compareTo(b.studentName);
    });
    return out;
  }

  List<StudentRiskProfile> atRiskFlags({
    String? className,
    Iterable<String>? classNames,
  }) {
    return profiles(className: className, classNames: classNames)
        .where((p) => p.isAtRisk)
        .toList();
  }

  int atRiskCount({String? className, Iterable<String>? classNames}) =>
      atRiskFlags(className: className, classNames: classNames).length;

  List<StudentRiskProfile> patterns({
    String? className,
    Iterable<String>? classNames,
  }) {
    return profiles(className: className, classNames: classNames)
        .where((p) => p.patterns.isNotEmpty)
        .toList();
  }

  List<TeacherClassInsight> teacherInsights({
    String? className,
    Iterable<String>? classNames,
  }) {
    if (_isPublicReader) return const [];
    final all = profiles(className: className, classNames: classNames);
    final byClass = <String, List<StudentRiskProfile>>{};
    for (final p in all) {
      byClass.putIfAbsent(p.className, () => []).add(p);
    }
    final names = byClass.keys.toList()..sort();
    return [
      for (final name in names) _insightForClass(name, byClass[name]!),
    ];
  }

  StudentRiskProfile _profileFor(String className, String studentName) {
    final snap = _data.attendanceSnapshotForStudent(
      studentName: studentName,
      className: className,
    );
    final sessions = snap.sessions;
    final absenceRate = sessions == 0 ? 0.0 : snap.absent / sessions;
    final lateRate = sessions == 0 ? 0.0 : snap.late / sessions;
    final consecutive = _maxConsecutiveAbsences(className, studentName);
    final weekday = _weekdayCluster(className, studentName);
    StudentGradeReport? gradeReport;
    for (final r in _data.getGradeReportsForClass(className)) {
      if (r.studentName == studentName) {
        gradeReport = r;
        break;
      }
    }
    gradeReport ??= _data.getGradeReportForStudent(studentName);
    final hasGrades = gradeReport != null && gradeReport.subjects.isNotEmpty;
    final gradeAvg = hasGrades ? gradeReport.average : null;

    final enoughSessions =
        sessions >= AttendanceIntelligenceThresholds.minSessionsForRate;
    final highAbsence = enoughSessions &&
        (absenceRate >= AttendanceIntelligenceThresholds.highAbsenceRate ||
            consecutive >=
                AttendanceIntelligenceThresholds.consecutiveAbsenceThreshold);
    final lowGrades = hasGrades &&
        (gradeAvg ?? 100) < AttendanceIntelligenceThresholds.lowGradeThreshold;

    final patterns = <AbsencePattern>[];
    if (consecutive >=
        AttendanceIntelligenceThresholds.consecutiveAbsenceThreshold) {
      patterns.add(
        AbsencePattern(
          kind: AbsencePatternKind.consecutiveAbsences,
          label: '$consecutive consecutive absences',
          detail: 'Streak of missed days in $className',
        ),
      );
    }
    if (enoughSessions &&
        absenceRate >= AttendanceIntelligenceThresholds.highAbsenceRate) {
      patterns.add(
        AbsencePattern(
          kind: AbsencePatternKind.chronicAbsence,
          label:
              '${(absenceRate * 100).round()}% absence rate over $sessions sessions',
        ),
      );
    }
    if (enoughSessions &&
        lateRate >= AttendanceIntelligenceThresholds.frequentLateRate) {
      patterns.add(
        AbsencePattern(
          kind: AbsencePatternKind.frequentLate,
          label: '${(lateRate * 100).round()}% late arrivals',
        ),
      );
    }
    if (weekday != null) {
      patterns.add(weekday);
    }

    final RiskLevel level;
    if (highAbsence && lowGrades) {
      level = RiskLevel.atRisk;
    } else if (highAbsence) {
      level = RiskLevel.attendanceWatch;
    } else if (lowGrades) {
      level = RiskLevel.academicWatch;
    } else {
      level = RiskLevel.clear;
    }

    return StudentRiskProfile(
      studentName: studentName,
      className: className,
      studentId: gradeReport?.studentId,
      level: level,
      present: snap.present,
      late: snap.late,
      absent: snap.absent,
      sessions: sessions,
      absenceRate: absenceRate,
      lateRate: lateRate,
      attendanceRate: snap.rate,
      consecutiveAbsences: consecutive,
      gradeAverage: gradeAvg,
      hasGrades: hasGrades,
      patterns: patterns,
    );
  }

  TeacherClassInsight _insightForClass(
    String className,
    List<StudentRiskProfile> students,
  ) {
    final withSessions = students.where((s) => s.sessions > 0).toList();
    final present = students.fold<int>(0, (n, s) => n + s.present);
    final late = students.fold<int>(0, (n, s) => n + s.late);
    final absent = students.fold<int>(0, (n, s) => n + s.absent);
    final sessionMarks = present + late + absent;
    final attendanceRate = sessionMarks == 0 ? 0.0 : present / sessionMarks;
    final absenceRate = sessionMarks == 0 ? 0.0 : absent / sessionMarks;
    final graded = students.where((s) => s.hasGrades).toList();
    final gradeAverage = graded.isEmpty
        ? null
        : graded.map((s) => s.gradeAverage!).reduce((a, b) => a + b) /
            graded.length;
    final highAbsence = students.where((s) => s.highAbsence).toList();
    final others = students.where((s) => s.hasGrades && !s.highAbsence).toList();
    final highAbsenceGraded = highAbsence.where((s) => s.hasGrades).toList();
    final highAbsenceGradeAverage = highAbsenceGraded.isEmpty
        ? null
        : highAbsenceGraded
                .map((s) => s.gradeAverage!)
                .reduce((a, b) => a + b) /
            highAbsenceGraded.length;
    final othersGradeAverage = others.isEmpty
        ? null
        : others.map((s) => s.gradeAverage!).reduce((a, b) => a + b) /
            others.length;

    String note;
    if (students.isEmpty) {
      note = 'No attendance or grade rows for this class yet.';
    } else if (highAbsenceGradeAverage != null &&
        othersGradeAverage != null &&
        highAbsenceGradeAverage + 5 < othersGradeAverage) {
      note =
          'Students with high absence average ${highAbsenceGradeAverage.toStringAsFixed(0)}% '
          'versus ${othersGradeAverage.toStringAsFixed(0)}% for the rest of the class.';
    } else if ((gradeAverage ?? 100) <
            AttendanceIntelligenceThresholds.lowGradeThreshold &&
        absenceRate >= AttendanceIntelligenceThresholds.highAbsenceRate) {
      note = 'Class marks and attendance are both weak.';
    } else if (withSessions.isEmpty) {
      note = 'Grades are on file; take attendance so absence can be compared.';
    } else {
      note = 'Rule-based snapshot from existing attendance and markbook data.';
    }

    return TeacherClassInsight(
      className: className,
      studentCount: students.length,
      attendanceRate: attendanceRate,
      absenceRate: absenceRate,
      gradeAverage: gradeAverage,
      atRiskCount: students.where((s) => s.isAtRisk).length,
      highAbsenceCount: highAbsence.length,
      lowGradeCount: students.where((s) => s.lowGrades).length,
      highAbsenceGradeAverage: highAbsenceGradeAverage,
      othersGradeAverage: othersGradeAverage,
      note: note,
    );
  }

  int _maxConsecutiveAbsences(String className, String studentName) {
    final history = _data.getAttendanceHistory(className)
      ..sort((a, b) => a.date.compareTo(b.date));
    var maxStreak = 0;
    var streak = 0;
    for (final session in history) {
      AttendanceStatus? status;
      for (final entry in session.entries) {
        if (entry.studentName == studentName) {
          status = entry.status;
          break;
        }
      }
      if (status == AttendanceStatus.absent) {
        streak += 1;
        if (streak > maxStreak) maxStreak = streak;
      } else if (status != null) {
        streak = 0;
      }
    }
    return maxStreak;
  }

  AbsencePattern? _weekdayCluster(String className, String studentName) {
    final counts = <int, int>{};
    var total = 0;
    for (final session in _data.getAttendanceHistory(className)) {
      for (final entry in session.entries) {
        if (entry.studentName != studentName) continue;
        if (entry.status != AttendanceStatus.absent) continue;
        counts[session.date.weekday] = (counts[session.date.weekday] ?? 0) + 1;
        total += 1;
      }
    }
    if (total < AttendanceIntelligenceThresholds.minAbsencesForCluster) {
      return null;
    }
    var bestDay = 1;
    var best = 0;
    counts.forEach((day, n) {
      if (n > best) {
        best = n;
        bestDay = day;
      }
    });
    if (best / total < AttendanceIntelligenceThresholds.weekdayClusterShare) {
      return null;
    }
    const names = {
      DateTime.monday: 'Mondays',
      DateTime.tuesday: 'Tuesdays',
      DateTime.wednesday: 'Wednesdays',
      DateTime.thursday: 'Thursdays',
      DateTime.friday: 'Fridays',
      DateTime.saturday: 'Saturdays',
      DateTime.sunday: 'Sundays',
    };
    return AbsencePattern(
      kind: AbsencePatternKind.weekdayCluster,
      label: '${names[bestDay] ?? 'One weekday'} account for $best of $total absences',
    );
  }
}

class _StudentKey {
  const _StudentKey(this.className, this.studentName);
  final String className;
  final String studentName;
}

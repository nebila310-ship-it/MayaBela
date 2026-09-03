/// LIA Phase F — attendance intelligence and rule-based at-risk flags.
/// Computed from existing attendance_sessions + Phase B grade reports.
/// Not a grade store and not a second attendance ledger.

enum RiskLevel { clear, academicWatch, attendanceWatch, atRisk }

enum AbsencePatternKind {
  consecutiveAbsences,
  chronicAbsence,
  frequentLate,
  weekdayCluster,
}

class AbsencePattern {
  const AbsencePattern({
    required this.kind,
    required this.label,
    this.detail,
  });

  final AbsencePatternKind kind;
  final String label;
  final String? detail;

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'label': label,
        if (detail != null) 'detail': detail,
      };

  factory AbsencePattern.fromMap(Map<String, dynamic> map) {
    return AbsencePattern(
      kind: AbsencePatternKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => AbsencePatternKind.chronicAbsence,
      ),
      label: map['label'] as String? ?? '',
      detail: map['detail'] as String?,
    );
  }
}

class StudentRiskProfile {
  const StudentRiskProfile({
    required this.studentName,
    required this.className,
    required this.level,
    required this.present,
    required this.late,
    required this.absent,
    required this.sessions,
    required this.absenceRate,
    required this.lateRate,
    required this.attendanceRate,
    required this.consecutiveAbsences,
    required this.patterns,
    this.studentId,
    this.gradeAverage,
    this.hasGrades = false,
  });

  final String studentName;
  final String className;
  final String? studentId;
  final RiskLevel level;
  final int present;
  final int late;
  final int absent;
  final int sessions;
  final double absenceRate;
  final double lateRate;
  final double attendanceRate;
  final int consecutiveAbsences;
  final double? gradeAverage;
  final bool hasGrades;
  final List<AbsencePattern> patterns;

  bool get isAtRisk => level == RiskLevel.atRisk;

  bool get highAbsence {
    final enough =
        sessions >= AttendanceIntelligenceThresholds.minSessionsForRate;
    return (enough &&
            absenceRate >= AttendanceIntelligenceThresholds.highAbsenceRate) ||
        consecutiveAbsences >=
            AttendanceIntelligenceThresholds.consecutiveAbsenceThreshold;
  }

  bool get lowGrades =>
      hasGrades &&
      (gradeAverage ?? 100) < AttendanceIntelligenceThresholds.lowGradeThreshold;

  Map<String, dynamic> toMap() => {
        'studentName': studentName,
        'className': className,
        if (studentId != null) 'studentId': studentId,
        'level': level.name,
        'present': present,
        'late': late,
        'absent': absent,
        'sessions': sessions,
        'absenceRate': absenceRate,
        'lateRate': lateRate,
        'attendanceRate': attendanceRate,
        'consecutiveAbsences': consecutiveAbsences,
        if (gradeAverage != null) 'gradeAverage': gradeAverage,
        'hasGrades': hasGrades,
        'patterns': patterns.map((p) => p.toMap()).toList(),
      };

  factory StudentRiskProfile.fromMap(Map<String, dynamic> map) {
    return StudentRiskProfile(
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String? ?? '',
      studentId: map['studentId'] as String?,
      level: RiskLevel.values.firstWhere(
        (v) => v.name == map['level'],
        orElse: () => RiskLevel.clear,
      ),
      present: (map['present'] as num?)?.toInt() ?? 0,
      late: (map['late'] as num?)?.toInt() ?? 0,
      absent: (map['absent'] as num?)?.toInt() ?? 0,
      sessions: (map['sessions'] as num?)?.toInt() ?? 0,
      absenceRate: (map['absenceRate'] as num?)?.toDouble() ?? 0,
      lateRate: (map['lateRate'] as num?)?.toDouble() ?? 0,
      attendanceRate: (map['attendanceRate'] as num?)?.toDouble() ?? 0,
      consecutiveAbsences: (map['consecutiveAbsences'] as num?)?.toInt() ?? 0,
      gradeAverage: (map['gradeAverage'] as num?)?.toDouble(),
      hasGrades: map['hasGrades'] as bool? ?? false,
      patterns: (map['patterns'] as List?)
              ?.whereType<Map>()
              .map((e) => AbsencePattern.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}

class TeacherClassInsight {
  const TeacherClassInsight({
    required this.className,
    required this.studentCount,
    required this.attendanceRate,
    required this.absenceRate,
    required this.atRiskCount,
    required this.highAbsenceCount,
    required this.lowGradeCount,
    required this.note,
    this.gradeAverage,
    this.highAbsenceGradeAverage,
    this.othersGradeAverage,
  });

  final String className;
  final int studentCount;
  final double attendanceRate;
  final double absenceRate;
  final double? gradeAverage;
  final int atRiskCount;
  final int highAbsenceCount;
  final int lowGradeCount;
  final double? highAbsenceGradeAverage;
  final double? othersGradeAverage;
  final String note;

  Map<String, dynamic> toMap() => {
        'className': className,
        'studentCount': studentCount,
        'attendanceRate': attendanceRate,
        'absenceRate': absenceRate,
        if (gradeAverage != null) 'gradeAverage': gradeAverage,
        'atRiskCount': atRiskCount,
        'highAbsenceCount': highAbsenceCount,
        'lowGradeCount': lowGradeCount,
        if (highAbsenceGradeAverage != null)
          'highAbsenceGradeAverage': highAbsenceGradeAverage,
        if (othersGradeAverage != null) 'othersGradeAverage': othersGradeAverage,
        'note': note,
      };
}

/// Shared rule constants. ML scoring is out of scope for Phase F.
abstract final class AttendanceIntelligenceThresholds {
  static const lowGradeThreshold = 50.0;
  static const highAbsenceRate = 0.15;
  static const consecutiveAbsenceThreshold = 3;
  static const frequentLateRate = 0.25;
  static const minSessionsForRate = 3;
  static const weekdayClusterShare = 0.6;
  static const minAbsencesForCluster = 3;
}

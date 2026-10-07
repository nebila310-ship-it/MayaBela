import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

class RankedStudentReport {
  const RankedStudentReport({
    required this.report,
    required this.rank,
  });

  final StudentGradeReport report;
  final int rank;

  double get average => report.average;
}

class SectionTopScorers {
  const SectionTopScorers({
    required this.gradeLevel,
    required this.section,
    required this.className,
    required this.students,
  });

  final String gradeLevel;
  final String section;
  final String className;
  final List<RankedStudentReport> students;
}

class GradeTopScorers {
  const GradeTopScorers({
    required this.gradeLevel,
    required this.gradeTopTen,
    required this.sections,
  });

  final String gradeLevel;
  final List<RankedStudentReport> gradeTopTen;
  final List<SectionTopScorers> sections;
}

class SectionUnderperformers {
  const SectionUnderperformers({
    required this.gradeLevel,
    required this.section,
    required this.className,
    required this.students,
  });

  final String gradeLevel;
  final String section;
  final String className;
  final List<StudentGradeReport> students;
}

class GradeUnderperformers {
  const GradeUnderperformers({
    required this.gradeLevel,
    required this.sections,
  });

  final String gradeLevel;
  final List<SectionUnderperformers> sections;

  int get totalCount =>
      sections.fold(0, (sum, section) => sum + section.students.length);
}

class GradeAnalyticsSnapshot {
  const GradeAnalyticsSnapshot({
    required this.topScorers,
    required this.underperformers,
  });

  final List<GradeTopScorers> topScorers;
  final List<GradeUnderperformers> underperformers;
}

class CategoryAverage {
  const CategoryAverage({
    required this.categoryId,
    required this.label,
    required this.average,
    required this.count,
  });

  final String categoryId;
  final String label;
  final double average;
  final int count;
}

class GradeAttendanceRow {
  const GradeAttendanceRow({
    required this.studentName,
    required this.className,
    required this.gradeAverage,
    required this.attendanceRate,
    required this.sessions,
  });

  final String studentName;
  final String className;
  final double gradeAverage;
  final double attendanceRate;
  final int sessions;
}

class TermTrendPoint {
  const TermTrendPoint({
    required this.term,
    this.academicYear,
    required this.average,
    required this.subjectCount,
  });

  final String term;
  final String? academicYear;
  final double average;
  final int subjectCount;
}

class GradeAnalyticsService {
  GradeAnalyticsService._();
  static final instance = GradeAnalyticsService._();

  static const underperformThreshold = 50.0;
  static const topCount = 10;

  final _structure = ClassStructureService.instance;
  final _data = SchoolDataService.instance;

  GradeAnalyticsSnapshot buildSnapshot({Iterable<String>? classNames}) {
    final byClass = _scoredReportsByClass(classNames);
    final classesByGrade = <String, List<String>>{};
    for (final className in byClass.keys) {
      final parsed = _parseClassName(className);
      final gradeLevel = parsed?.$1 ?? className;
      classesByGrade.putIfAbsent(gradeLevel, () => []).add(className);
    }

    final gradeLevels = classesByGrade.keys.toList()..sort(_compareGrades);
    final topScorers = <GradeTopScorers>[];
    final underperformers = <GradeUnderperformers>[];

    for (final gradeLevel in gradeLevels) {
      final classList = classesByGrade[gradeLevel]!..sort();
      final sectionTops = <SectionTopScorers>[];
      final gradePool = <StudentGradeReport>[];

      for (final className in classList) {
        final classReports = List<StudentGradeReport>.from(
          byClass[className] ?? const [],
        )..sort((a, b) => b.average.compareTo(a.average));
        final top = classReports
            .where((r) => r.average >= underperformThreshold)
            .take(topCount)
            .toList();
        gradePool.addAll(top);
        final parsed = _parseClassName(className);
        sectionTops.add(
          SectionTopScorers(
            gradeLevel: gradeLevel,
            section: parsed?.$2.isNotEmpty == true ? parsed!.$2 : className,
            className: className,
            students: _withRanks(top),
          ),
        );
      }

      gradePool.sort((a, b) => b.average.compareTo(a.average));
      final seen = <String>{};
      final gradeTop = <StudentGradeReport>[];
      for (final report in gradePool) {
        final key = (report.studentId?.trim().isNotEmpty ?? false)
            ? 'id:${report.studentId!.trim().toUpperCase()}'
            : 'name:${report.studentName.trim().toLowerCase()}';
        if (seen.add(key)) {
          gradeTop.add(report);
        }
        if (gradeTop.length >= topCount) break;
      }

      if (gradeTop.isNotEmpty ||
          sectionTops.any((section) => section.students.isNotEmpty)) {
        topScorers.add(
          GradeTopScorers(
            gradeLevel: gradeLevel,
            gradeTopTen: _withRanks(gradeTop),
            sections: sectionTops,
          ),
        );
      }

      final underSections = <SectionUnderperformers>[];
      for (final className in classList) {
        final parsed = _parseClassName(className);
        final low = (byClass[className] ?? const [])
            .where((r) => r.average < underperformThreshold)
            .toList()
          ..sort((a, b) => a.average.compareTo(b.average));
        if (low.isNotEmpty) {
          underSections.add(
            SectionUnderperformers(
              gradeLevel: gradeLevel,
              section: parsed?.$2.isNotEmpty == true ? parsed!.$2 : className,
              className: className,
              students: low,
            ),
          );
        }
      }

      if (underSections.isNotEmpty) {
        underperformers.add(
          GradeUnderperformers(
            gradeLevel: gradeLevel,
            sections: underSections,
          ),
        );
      }
    }

    return GradeAnalyticsSnapshot(
      topScorers: topScorers,
      underperformers: underperformers,
    );
  }

  Map<String, List<StudentGradeReport>> _scoredReportsByClass(
    Iterable<String>? classNames,
  ) {
    final schoolClasses = _data.getAllClassNames();
    var classes = schoolClasses;
    if (classNames != null) {
      final allowed = [
        for (final name in classNames)
          if (name.trim().isNotEmpty) name.trim(),
      ];
      if (allowed.isNotEmpty) {
        classes = [
          for (final name in allowed)
            if (schoolClasses.isEmpty ||
                schoolClasses.any(
                  (className) => StudentRegistryService.classNamesMatch(
                    className,
                    name,
                  ),
                ))
              name,
        ];
      }
    }
    if (classes.isEmpty) {
      final fromReports = <String>{};
      for (final report in _data.getAllGradeReports()) {
        if (_rankingReport(report) == null) continue;
        fromReports.add(report.className);
      }
      classes = fromReports.toList()..sort();
    }

    final byClass = <String, List<StudentGradeReport>>{};
    for (final className in classes) {
      final scored = [
        for (final report in _data.getGradeReportsForClass(className))
          if (_rankingReport(report) case final ranked?) ranked,
      ];
      if (scored.isNotEmpty) {
        byClass[className] = scored;
      }
    }
    return byClass;
  }

  /// Ranking uses approved (locked) marks only. Draft and pending stay off
  /// the leaderboard until Section Director approval.
  StudentGradeReport? _rankingReport(StudentGradeReport report) {
    final approved = approvedSubjectsForAverage(report);
    if (approved.isEmpty) return null;
    if (approved.length == report.subjects.length) return report;
    return report.copyWith(subjects: approved);
  }

  static List<SubjectGrade> approvedSubjectsForAverage(
    StudentGradeReport report,
  ) {
    return [
      for (final subject in report.subjects)
        if (subject.status == SubjectGradeStatus.approved) subject,
    ];
  }

  List<RankedStudentReport> rankingsForClass(String className) {
    final reports = [
      for (final report in _data.getGradeReportsForClass(className))
        if (_rankingReport(report) case final ranked?) ranked,
    ]..sort((a, b) => b.average.compareTo(a.average));
    return _withRanks(reports);
  }

  List<StudentGradeReport> underperformersForClass(String className) {
    return [
      for (final report in _data.getGradeReportsForClass(className))
        if (_rankingReport(report) case final ranked?)
          if (ranked.average < underperformThreshold) ranked,
    ]..sort((a, b) => a.average.compareTo(b.average));
  }

  bool _reportInClass(StudentGradeReport report, String? className) {
    if (className == null || className.trim().isEmpty) return true;
    return StudentRegistryService.classNamesMatch(report.className, className);
  }

  List<RankedStudentReport> _withRanks(List<StudentGradeReport> reports) {
    return [
      for (var i = 0; i < reports.length; i++)
        RankedStudentReport(report: reports[i], rank: i + 1),
    ];
  }

  (String, String)? _parseClassName(String className) {
    final trimmed = className.trim();
    if (trimmed.isEmpty) return null;

    final grades = _structure.gradesForSchool()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final grade in grades) {
      if (trimmed.startsWith(grade)) {
        final section = trimmed.substring(grade.length).trim();
        return (grade, section.isEmpty ? trimmed : section);
      }
    }

    final match = RegExp(r'^Grade\s*(\d+)\s*([A-Za-z]+)?$').firstMatch(trimmed);
    if (match != null) {
      final level = 'Grade ${match.group(1)}';
      return (level, match.group(2) ?? '');
    }
    return (trimmed, '');
  }

  int _compareGrades(String a, String b) {
    final na = _gradeSortKey(a);
    final nb = _gradeSortKey(b);
    if (na != nb) return na.compareTo(nb);
    return a.compareTo(b);
  }

  int _gradeSortKey(String grade) {
    final match = RegExp(r'(\d+)').firstMatch(grade);
    if (match != null) return int.tryParse(match.group(1)!) ?? 999;
    return 999;
  }

  /// Average by assessment category (homework, quiz, midterm, …).
  List<CategoryAverage> categoryAverages({
    String? className,
    String? subject,
  }) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final report in _data.getAllGradeReports()) {
      if (!_reportInClass(report, className)) continue;
      for (final grade in report.subjects) {
        if (subject != null &&
            subject.trim().isNotEmpty &&
            grade.subject != subject) {
          continue;
        }
        for (final mark in grade.assessments) {
          if (!mark.isEntered) continue;
          sums[mark.categoryId] = (sums[mark.categoryId] ?? 0) + mark.percentage;
          counts[mark.categoryId] = (counts[mark.categoryId] ?? 0) + 1;
          labels[mark.categoryId] = mark.label;
        }
      }
    }
    final rows = [
      for (final id in sums.keys)
        CategoryAverage(
          categoryId: id,
          label: labels[id] ?? id,
          average: sums[id]! / counts[id]!,
          count: counts[id]!,
        ),
    ]..sort((a, b) => a.label.compareTo(b.label));
    return rows;
  }

  /// Markbook averages next to the live attendance register (same stores).
  List<GradeAttendanceRow> gradeAttendanceRows({String? className}) {
    final rows = <GradeAttendanceRow>[];
    for (final report in _data.getAllGradeReports()) {
      if (!_reportInClass(report, className)) continue;
      if (report.subjects.isEmpty) continue;
      final snap = _data.attendanceSnapshotForStudent(
        studentName: report.studentName,
        className: report.className,
      );
      rows.add(
        GradeAttendanceRow(
          studentName: report.studentName,
          className: report.className,
          gradeAverage: report.average,
          attendanceRate: snap.rate,
          sessions: snap.sessions,
        ),
      );
    }
    rows.sort((a, b) => a.studentName.compareTo(b.studentName));
    return rows;
  }

  List<TermTrendPoint> termTrendForStudent({
    String? studentId,
    String? studentName,
  }) {
    final reports = studentId != null && studentId.trim().isNotEmpty
        ? _data.gradeReportsForStudent(studentId)
        : _data
            .getAllGradeReports()
            .where((r) => r.studentName == studentName)
            .toList();
    final byKey = <String, TermTrendPoint>{};
    for (final report in reports) {
      if (report.subjects.isEmpty) continue;
      final key = '${report.academicYear ?? ''}|${report.term}';
      byKey[key] = TermTrendPoint(
        term: report.term,
        academicYear: report.academicYear,
        average: report.average,
        subjectCount: report.subjects.length,
      );
    }
    return byKey.values.toList()
      ..sort((a, b) {
        final year = (a.academicYear ?? '').compareTo(b.academicYear ?? '');
        return year != 0 ? year : a.term.compareTo(b.term);
      });
  }
}

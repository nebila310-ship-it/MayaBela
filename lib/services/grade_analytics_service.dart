import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/school_data_service.dart';

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

class GradeAnalyticsService {
  GradeAnalyticsService._();
  static final instance = GradeAnalyticsService._();

  static const underperformThreshold = 50.0;
  static const topCount = 10;

  final _structure = ClassStructureService.instance;
  final _data = SchoolDataService.instance;

  GradeAnalyticsSnapshot buildSnapshot({Iterable<String>? classNames}) {
    var reports = _data.getAllGradeReports();
    if (classNames != null) {
      final allowed = classNames.map((name) => name.trim()).toSet();
      reports = reports.where((r) => allowed.contains(r.className)).toList();
    }
    final byClass = <String, List<StudentGradeReport>>{};
    for (final report in reports) {
      byClass.putIfAbsent(report.className, () => []).add(report);
    }

    final gradeLevels = _orderedGrades(reports, byClass.keys);
    final topScorers = <GradeTopScorers>[];
    final underperformers = <GradeUnderperformers>[];

    for (final gradeLevel in gradeLevels) {
      final sectionLabels = _sectionsForGrade(gradeLevel, byClass.keys);
      final sectionTops = <SectionTopScorers>[];
      final gradePool = <StudentGradeReport>[];

      for (final section in sectionLabels) {
        final className = _structure.classNameFor(gradeLevel, section);
        final classReports = List<StudentGradeReport>.from(
          byClass[className] ?? const [],
        )..sort((a, b) => b.average.compareTo(a.average));

        final top = classReports.take(topCount).toList();
        gradePool.addAll(top);

        sectionTops.add(
          SectionTopScorers(
            gradeLevel: gradeLevel,
            section: section,
            className: className,
            students: _withRanks(top),
          ),
        );
      }

      gradePool.sort((a, b) => b.average.compareTo(a.average));
      final seen = <String>{};
      final gradeTop = <StudentGradeReport>[];
      for (final report in gradePool) {
        if (seen.add(report.studentName)) {
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
      for (final section in sectionLabels) {
        final className = _structure.classNameFor(gradeLevel, section);
        final low = (byClass[className] ?? const [])
            .where((r) => r.average < underperformThreshold)
            .toList()
          ..sort((a, b) => a.average.compareTo(b.average));

        if (low.isNotEmpty) {
          underSections.add(
            SectionUnderperformers(
              gradeLevel: gradeLevel,
              section: section,
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

  List<RankedStudentReport> rankingsForClass(String className) {
    final reports = List<StudentGradeReport>.from(
      _data.getGradeReportsForClass(className),
    )..sort((a, b) => b.average.compareTo(a.average));
    return _withRanks(reports);
  }

  List<StudentGradeReport> underperformersForClass(String className) {
    return _data
        .getGradeReportsForClass(className)
        .where((report) => report.average < underperformThreshold)
        .toList()
      ..sort((a, b) => a.average.compareTo(b.average));
  }

  List<RankedStudentReport> _withRanks(List<StudentGradeReport> reports) {
    return [
      for (var i = 0; i < reports.length; i++)
        RankedStudentReport(report: reports[i], rank: i + 1),
    ];
  }

  List<String> _orderedGrades(
    List<StudentGradeReport> reports,
    Iterable<String> classNames,
  ) {
    final grades = <String>{};
    grades.addAll(_structure.gradesForSchool());
    for (final className in classNames) {
      final parsed = _parseClassName(className);
      if (parsed != null) grades.add(parsed.$1);
    }
    for (final report in reports) {
      final parsed = _parseClassName(report.className);
      if (parsed != null) grades.add(parsed.$1);
    }

    final list = grades.toList();
    list.sort(_compareGrades);
    return list;
  }

  List<String> _sectionsForGrade(String gradeLevel, Iterable<String> classNames) {
    final sections = <String>{};
    sections.addAll(_structure.sectionsForGrade(gradeLevel));
    for (final className in classNames) {
      final parsed = _parseClassName(className);
      if (parsed != null && parsed.$1 == gradeLevel && parsed.$2.isNotEmpty) {
        sections.add(parsed.$2);
      }
    }
    final list = sections.toList()..sort();
    return list;
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
}

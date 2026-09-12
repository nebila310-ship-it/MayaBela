import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';

/// Read-only teacher rollup from existing evaluations + QA observations.
/// Does not persist a second performance store.
class TeacherPerformanceRow {
  const TeacherPerformanceRow({
    required this.teacherName,
    this.teacherId,
    this.evaluationAverage,
    this.evaluationCount = 0,
    this.observationAverage,
    this.observationCount = 0,
  });

  final String teacherName;
  final String? teacherId;
  final double? evaluationAverage;
  final int evaluationCount;
  final double? observationAverage;
  final int observationCount;
}

class TeacherPerformanceInsights {
  TeacherPerformanceInsights._();
  static final instance = TeacherPerformanceInsights._();

  List<TeacherPerformanceRow> rows([String? schoolId]) {
    final evals = CurriculumService.instance.evaluationsForSchool(schoolId);
    final observations =
        QaMonitorService.instance.observationsForSchool(schoolId);

    final names = <String, String>{};
    final ids = <String, String>{};
    final evalSums = <String, double>{};
    final evalCounts = <String, int>{};
    final obsSums = <String, double>{};
    final obsCounts = <String, int>{};

    for (final row in evals) {
      final key = _key(teacherId: row.teacherId, teacherName: row.teacherName);
      names[key] = row.teacherName;
      if (row.teacherId.trim().isNotEmpty) ids[key] = row.teacherId;
      evalSums[key] = (evalSums[key] ?? 0) + row.average;
      evalCounts[key] = (evalCounts[key] ?? 0) + 1;
    }
    for (final row in observations) {
      final key = _key(teacherId: row.teacherId, teacherName: row.teacherName);
      names[key] = row.teacherName;
      final tid = (row.teacherId ?? '').trim();
      if (tid.isNotEmpty) ids[key] = tid;
      obsSums[key] = (obsSums[key] ?? 0) + row.averageScore;
      obsCounts[key] = (obsCounts[key] ?? 0) + 1;
    }

    final out = [
      for (final key in names.keys)
        TeacherPerformanceRow(
          teacherName: names[key]!,
          teacherId: ids[key],
          evaluationAverage: evalCounts[key] == null
              ? null
              : evalSums[key]! / evalCounts[key]!,
          evaluationCount: evalCounts[key] ?? 0,
          observationAverage: obsCounts[key] == null
              ? null
              : obsSums[key]! / obsCounts[key]!,
          observationCount: obsCounts[key] ?? 0,
        ),
    ]..sort((a, b) => a.teacherName.compareTo(b.teacherName));
    return out;
  }

  String _key({String? teacherId, required String teacherName}) {
    final id = (teacherId ?? '').trim();
    if (id.isNotEmpty) return 'id:${id.toUpperCase()}';
    return 'name:${teacherName.trim().toLowerCase()}';
  }
}

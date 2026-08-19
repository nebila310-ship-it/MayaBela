import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Persists teacher grade reports (scores, comments, publish state).
class GradePersistenceService {
  GradePersistenceService._();
  static final instance = GradePersistenceService._();

  static const _reportsKey = 'persisted_grade_reports';

  Future<void> loadIntoSchoolDataService() async {
    final rows = await LocalJsonStore.readList(_reportsKey);
    if (rows.isEmpty) return;

    final parsed = <StudentGradeReport>[];
    for (final map in rows) {
      try {
        parsed.add(StudentGradeReport.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      SchoolDataService.instance.applyPersistedGradeReports(parsed);
    }
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final reports = SchoolDataService.instance.gradeReportsSnapshot();
    await LocalJsonStore.writeList(
      _reportsKey,
      reports.map((report) => report.toMap()).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllGradeReports();
    }
  }
}

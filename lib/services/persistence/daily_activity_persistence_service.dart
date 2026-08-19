import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Persists homeroom daily activity reports and parent acknowledgments.
class DailyActivityPersistenceService {
  DailyActivityPersistenceService._();
  static final instance = DailyActivityPersistenceService._();

  static const _reportsKey = 'persisted_daily_activities';

  Future<void> loadIntoSchoolDataService() async {
    final rows = await LocalJsonStore.readList(_reportsKey);
    if (rows.isEmpty) return;

    final parsed = <DailyActivityReport>[];
    for (final map in rows) {
      try {
        parsed.add(DailyActivityReport.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      SchoolDataService.instance.applyPersistedDailyActivities(parsed);
    }
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final reports = SchoolDataService.instance.dailyActivitiesSnapshot();
    await LocalJsonStore.writeList(
      _reportsKey,
      reports.map((report) => report.toMap()).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllDailyActivities();
    }
  }
}

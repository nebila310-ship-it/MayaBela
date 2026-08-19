import 'package:mayabela/models/qa_finding.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/qa_findings_service.dart';

/// Persists QA findings locally and syncs to Supabase.
class QaFindingsPersistenceService {
  QaFindingsPersistenceService._();
  static final instance = QaFindingsPersistenceService._();

  static const _key = 'qa_findings_v1';

  Future<void> loadIntoService() async {
    final findings = <QaFinding>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        findings.add(QaFinding.fromMap(map));
      } catch (_) {}
    }
    QaFindingsService.instance.applyPersistedData(findings);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    await LocalJsonStore.writeList(
      _key,
      QaFindingsService.instance.snapshotMaps(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllQaFindings();
    }
  }
}

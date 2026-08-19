import 'package:mayabela/models/procurement_models.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/procurement_service.dart';

/// Persists purchase / issue requests locally and syncs them to Supabase.
class ProcurementPersistenceService {
  ProcurementPersistenceService._();
  static final instance = ProcurementPersistenceService._();

  static const _purchasesKey = 'purchase_requests_v1';
  static const _issuesKey = 'issue_requests_v1';

  Future<void> loadIntoService() async {
    final purchases = <PurchaseRequest>[];
    for (final map in await LocalJsonStore.readList(_purchasesKey)) {
      try {
        purchases.add(PurchaseRequest.fromMap(map));
      } catch (_) {}
    }
    final issues = <IssueRequest>[];
    for (final map in await LocalJsonStore.readList(_issuesKey)) {
      try {
        issues.add(IssueRequest.fromMap(map));
      } catch (_) {}
    }
    ProcurementService.instance.applyPersistedData(
      purchases: purchases,
      issues: issues,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = ProcurementService.instance;
    await LocalJsonStore.writeList(
      _purchasesKey,
      svc.purchasesSnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _issuesKey,
      svc.issuesSnapshot().map((e) => e.toMap()).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllProcurement();
    }
  }
}

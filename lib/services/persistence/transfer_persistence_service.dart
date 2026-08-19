import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/transfer_workflow_service.dart';

/// Persists transfer requests locally and syncs them to Supabase.
class TransferPersistenceService {
  TransferPersistenceService._();
  static final instance = TransferPersistenceService._();

  static const _key = 'transfer_requests_v1';

  Future<void> loadIntoService() async {
    final requests = <TransferRequest>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        requests.add(TransferRequest.fromMap(map));
      } catch (_) {}
    }
    TransferWorkflowService.instance.applyPersistedData(requests: requests);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = TransferWorkflowService.instance;
    await LocalJsonStore.writeList(
      _key,
      svc.requestsSnapshot().map((e) => e.toMap()).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllTransferRequests();
    }
  }
}

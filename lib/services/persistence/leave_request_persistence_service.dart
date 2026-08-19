import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/services/leave_request_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

/// Persists student leave requests locally and syncs to Supabase (via the
/// service-role registry edge so parent submissions pass the write guard).
class LeaveRequestPersistenceService {
  LeaveRequestPersistenceService._();
  static final instance = LeaveRequestPersistenceService._();

  static const _key = 'leave_requests_v1';

  Future<void> loadIntoService() async {
    final requests = <LeaveRequest>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        requests.add(LeaveRequest.fromMap(map));
      } catch (_) {}
    }
    LeaveRequestService.instance.applyPersistedData(requests);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    await LocalJsonStore.writeList(
      _key,
      LeaveRequestService.instance.snapshotMaps(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllLeaveRequests();
    }
  }
}

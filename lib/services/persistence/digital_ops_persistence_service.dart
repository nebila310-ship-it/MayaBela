import 'package:mayabela/models/digital_ops_models.dart';
import 'package:mayabela/services/digital_ops_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class DigitalOpsPersistenceService {
  DigitalOpsPersistenceService._();
  static final instance = DigitalOpsPersistenceService._();

  static const _devicesKey = 'ict_devices_v1';
  static const _reviewsKey = 'ict_weekly_reviews_v1';

  Future<void> loadIntoService() async {
    final devices = <IctDeviceRecord>[];
    for (final map in await LocalJsonStore.readList(_devicesKey)) {
      try {
        devices.add(IctDeviceRecord.fromMap(map));
      } catch (_) {}
    }
    final reviews = <IctWeeklyReview>[];
    for (final map in await LocalJsonStore.readList(_reviewsKey)) {
      try {
        reviews.add(IctWeeklyReview.fromMap(map));
      } catch (_) {}
    }
    DigitalOpsService.instance.applyPersistedData(
      devices: devices,
      reviews: reviews,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = DigitalOpsService.instance;
    await LocalJsonStore.writeList(_devicesKey, svc.deviceMaps());
    await LocalJsonStore.writeList(_reviewsKey, svc.reviewMaps());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllDigitalOps();
    }
  }
}

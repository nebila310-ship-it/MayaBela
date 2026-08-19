import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

/// Persists parent link requests (pending + approved + rejected).
class EnrollmentPersistenceService {
  EnrollmentPersistenceService._();
  static final instance = EnrollmentPersistenceService._();

  static const _linksKey = 'persisted_parent_links';
  static const _nextIdKey = 'persisted_parent_link_next_id';

  Future<void> loadIntoEnrollmentService() async {
    final links = await LocalJsonStore.readList(_linksKey);
    final nextId = await LocalJsonStore.readInt(_nextIdKey);
    if (links.isEmpty) return;

    final parsed = <ParentLinkRequest>[];
    for (final map in links) {
      try {
        parsed.add(ParentLinkRequest.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      EnrollmentService.instance.replaceLinks(parsed, nextId: nextId);
    }
  }

  Future<void> saveFromEnrollmentService({
    bool pushCloud = true,
    String? syncLinkId,
  }) async {
    final links = EnrollmentService.instance.allLinksSnapshot();
    await LocalJsonStore.writeList(
      _linksKey,
      links.map((l) => l.toMap()).toList(),
    );
    await LocalJsonStore.writeInt(
      _nextIdKey,
      EnrollmentService.instance.nextLinkIdCounter,
    );
    if (pushCloud) {
      final syncId = syncLinkId?.trim();
      final cloudTargets = syncId == null || syncId.isEmpty
          ? links
          : links.where((l) => l.id == syncId);
      for (final link in cloudTargets) {
        await CloudAppStore.instance.pushParentLink(link);
      }
    }
  }
}

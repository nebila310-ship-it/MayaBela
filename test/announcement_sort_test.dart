import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/school_data_service.dart';

void main() {
  test('getAnnouncements puts newest posts first', () {
    final service = SchoolDataService.instance;
    // Relative dates: demo seed announcements use DateTime.now(), so the
    // "newest" fixture must always be ahead of them regardless of today.
    final older = Announcement(
      id: 'ann-old',
      title: 'Older',
      body: 'Old body',
      author: 'Admin',
      date: DateTime.now().subtract(const Duration(days: 400)),
      audience: AnnouncementAudiences.all,
      priority: AnnouncementPriority.urgent,
    );
    final newer = Announcement(
      id: 'ann-new',
      title: 'Newer',
      body: 'New body',
      author: 'Admin',
      date: DateTime.now().add(const Duration(days: 2)),
      audience: AnnouncementAudiences.all,
      priority: AnnouncementPriority.normal,
    );

    service.applyPersistedAnnouncements([older, newer]);
    final sorted = service.getAnnouncements();
    expect(sorted.first.id, 'ann-new');
    expect(sorted.any((a) => a.id == 'ann-old'), isTrue);
  });
}

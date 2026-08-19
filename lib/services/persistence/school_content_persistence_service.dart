import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Persists fees, calendar, gallery, QR scans, announcements, and attendance.
class SchoolContentPersistenceService {
  SchoolContentPersistenceService._();
  static final instance = SchoolContentPersistenceService._();

  static const _feesKey = 'persisted_fees';
  static const _calendarKey = 'persisted_calendar_events';
  static const _galleryKey = 'persisted_gallery_posts';
  static const _qrScansKey = 'persisted_qr_scans';
  static const _announcementsKey = 'persisted_announcements';
  static const _attendanceKey = 'persisted_attendance_sessions';
  static const _announcementNextIdKey = 'persisted_announcement_next_id';
  static const _calendarNextIdKey = 'persisted_calendar_next_id';

  Future<void> loadIntoSchoolDataService() async {
    await _loadFees();
    await _loadCalendar();
    await _loadGallery();
    await _loadQrScans();
    await _loadAnnouncements();
    await _loadAttendance();
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final data = SchoolDataService.instance;
    await LocalJsonStore.writeList(
      _feesKey,
      data.feesSnapshot().map(AppDataMaps.feeToMap).toList(),
    );
    await LocalJsonStore.writeList(
      _calendarKey,
      data.calendarSnapshot().map(AppDataMaps.calendarEventToMap).toList(),
    );
    await LocalJsonStore.writeList(
      _galleryKey,
      data.gallerySnapshot().map(AppDataMaps.galleryPostToMap).toList(),
    );
    await LocalJsonStore.writeList(
      _qrScansKey,
      data.qrScanSnapshot().map(AppDataMaps.qrScanToMap).toList(),
    );
    await LocalJsonStore.writeList(
      _announcementsKey,
      data.announcementsSnapshot().map(AppDataMaps.announcementToMap).toList(),
    );
    await LocalJsonStore.writeList(
      _attendanceKey,
      data.attendanceSnapshot().map(AppDataMaps.attendanceSessionToMap).toList(),
    );
    await LocalJsonStore.writeInt(
      _announcementNextIdKey,
      data.announcementNextIdSnapshot(),
    );
    await LocalJsonStore.writeInt(
      _calendarNextIdKey,
      data.calendarNextIdSnapshot(),
    );

    if (pushCloud) {
      await CloudAppStore.instance.pushAllSchoolContent();
    }
  }

  Future<void> _loadFees() async {
    final rows = await LocalJsonStore.readList(_feesKey);
    if (rows.isEmpty) return;
    final parsed = rows.map((m) => AppDataMaps.feeFromMap(m)).toList();
    SchoolDataService.instance.applyPersistedFees(parsed);
  }

  Future<void> _loadCalendar() async {
    final rows = await LocalJsonStore.readList(_calendarKey);
    final nextId = await LocalJsonStore.readInt(_calendarNextIdKey) ?? 0;
    if (rows.isEmpty && nextId <= 0) return;
    final parsed = rows.map((m) => AppDataMaps.calendarEventFromMap(m)).toList();
    SchoolDataService.instance.applyPersistedCalendar(
      parsed,
      nextId: nextId > 0 ? nextId : null,
    );
  }

  Future<void> _loadGallery() async {
    final rows = await LocalJsonStore.readList(_galleryKey);
    if (rows.isEmpty) return;
    final parsed = rows.map((m) => AppDataMaps.galleryPostFromMap(m)).toList();
    SchoolDataService.instance.applyPersistedGallery(parsed);
  }

  Future<void> _loadQrScans() async {
    final rows = await LocalJsonStore.readList(_qrScansKey);
    if (rows.isEmpty) return;
    final parsed = rows.map((m) => AppDataMaps.qrScanFromMap(m)).toList();
    SchoolDataService.instance.applyPersistedQrScans(parsed);
  }

  Future<void> _loadAnnouncements() async {
    final rows = await LocalJsonStore.readList(_announcementsKey);
    final nextId = await LocalJsonStore.readInt(_announcementNextIdKey) ?? 0;
    if (rows.isEmpty && nextId <= 0) return;
    final parsed =
        rows.map((m) => AppDataMaps.announcementFromMap(m)).toList();
    SchoolDataService.instance.applyPersistedAnnouncements(
      parsed,
      nextId: nextId > 0 ? nextId : null,
    );
  }

  Future<void> _loadAttendance() async {
    final rows = await LocalJsonStore.readList(_attendanceKey);
    if (rows.isEmpty) return;
    final parsed =
        rows.map((m) => AppDataMaps.attendanceSessionFromMap(m)).toList();
    SchoolDataService.instance.applyPersistedAttendance(parsed);
  }
}

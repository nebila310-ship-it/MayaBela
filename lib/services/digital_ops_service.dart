import 'package:flutter/foundation.dart';

import 'package:mayabela/models/digital_ops_models.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/persistence/digital_ops_persistence_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Administration Staff digital-ops desk (phases 1–5). Not a new IT role.
class DigitalOpsService extends ChangeNotifier {
  DigitalOpsService._();
  static final instance = DigitalOpsService._();

  final List<IctDeviceRecord> _devices = [];
  final List<IctWeeklyReview> _reviews = [];

  List<IctDeviceRecord> devicesForSchool(String? schoolId) {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '')
        .trim()
        .toUpperCase();
    if (sid.isEmpty) return const [];
    return List.unmodifiable(
      _devices.where((d) => d.schoolId == sid).toList()
        ..sort((a, b) => a.label.compareTo(b.label)),
    );
  }

  List<IctWeeklyReview> reviewsForSchool(String? schoolId) {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '')
        .trim()
        .toUpperCase();
    if (sid.isEmpty) return const [];
    final rows = _reviews.where((r) => r.schoolId == sid).toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return List.unmodifiable(rows);
  }

  IctWeeklyReview? reviewThisWeek(String? schoolId) {
    final start = weekStart(DateTime.now());
    for (final row in reviewsForSchool(schoolId)) {
      if (_sameDay(row.weekStart, start)) return row;
    }
    return null;
  }

  int pendingParentLinks(String? schoolId) =>
      EnrollmentService.instance.pendingForSchool(schoolId).length;

  List<ParentLinkRequest> pendingParentLinkRows(String? schoolId) =>
      EnrollmentService.instance.pendingForSchool(schoolId);

  AdminStudentRecord? lookupStudent(String raw) {
    final id = raw.trim().toUpperCase();
    if (id.isEmpty) return null;
    return StudentRegistryService.instance.lookupById(id);
  }

  int driverPhonesWithoutGps(String? schoolId) {
    final drivers =
        DriverRegistryService.instance.driversForSchool(schoolId);
    var missing = 0;
    for (final driver in drivers) {
      final pos = BusLiveLocationService.instance.positionFor(driver.driverId);
      final stale = pos == null ||
          DateTime.now().difference(pos.timestamp) >
              const Duration(hours: 24);
      if (stale) missing++;
    }
    return missing;
  }

  DateTime? lastBackupAt() =>
      GoliveService.instance.capacitySnapshot().lastBackupAt;

  @visibleForTesting
  static void resetForTests() {
    instance._devices.clear();
    instance._reviews.clear();
  }

  void applyPersistedData({
    List<IctDeviceRecord>? devices,
    List<IctWeeklyReview>? reviews,
    bool merge = false,
  }) {
    if (devices != null) {
      if (merge) {
        final incomingIds = devices.map((e) => e.id).toSet();
        final schools = devices.map((e) => e.schoolId).toSet();
        _devices.removeWhere(
          (e) => schools.contains(e.schoolId) || incomingIds.contains(e.id),
        );
        _devices.addAll(devices);
      } else {
        _devices
          ..clear()
          ..addAll(devices);
      }
    }
    if (reviews != null) {
      if (merge) {
        final incomingIds = reviews.map((e) => e.id).toSet();
        final schools = reviews.map((e) => e.schoolId).toSet();
        _reviews.removeWhere(
          (e) => schools.contains(e.schoolId) || incomingIds.contains(e.id),
        );
        _reviews.addAll(reviews);
      } else {
        _reviews
          ..clear()
          ..addAll(reviews);
      }
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> deviceMaps() =>
      _devices.map((e) => e.toMap()).toList();

  List<Map<String, dynamic>> reviewMaps() =>
      _reviews.map((e) => e.toMap()).toList();

  Future<IctDeviceRecord> upsertDevice({
    String? id,
    required IctDeviceKind kind,
    required String label,
    String assignedTo = '',
    String location = '',
    String notes = '',
    bool gpsEnabled = false,
  }) async {
    final sid = (AuthService.activeSchoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) {
      throw StateError('Sign in to a school first.');
    }
    final now = DateTime.now();
    final who = AuthService.currentUser?.fullName?.trim().isNotEmpty == true
        ? AuthService.currentUser!.fullName!.trim()
        : (AuthService.currentUser?.username ?? 'staff');
    final existingId = id?.trim();
    final row = IctDeviceRecord(
      id: (existingId != null && existingId.isNotEmpty)
          ? existingId
          : ShortRegistryId.allocate(
              prefix: 'DEV',
              existingIds: _devices.map((e) => e.id),
              isTaken: (candidate) => _devices.any((e) => e.id == candidate),
            ),
      schoolId: sid,
      kind: kind,
      label: label.trim(),
      assignedTo: assignedTo.trim(),
      location: location.trim(),
      notes: notes.trim(),
      gpsEnabled: gpsEnabled,
      updatedBy: who,
      updatedAt: now,
    );
    final idx = _devices.indexWhere((e) => e.id == row.id);
    if (idx >= 0) {
      _devices[idx] = row;
    } else {
      _devices.add(row);
    }
    notifyListeners();
    await DigitalOpsPersistenceService.instance.saveFromService();
    return row;
  }

  Future<void> removeDevice(String id) async {
    _devices.removeWhere((e) => e.id == id);
    notifyListeners();
    await DigitalOpsPersistenceService.instance.saveFromService();
  }

  Future<IctWeeklyReview> saveWeeklyReview({
    required bool loginIssuesReviewed,
    required bool parentLinkPileReviewed,
    required bool backupChecked,
    required bool hardRefreshReminded,
    required bool devicesChecked,
    String notes = '',
    String chairName = '',
  }) async {
    final sid = (AuthService.activeSchoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) {
      throw StateError('Sign in to a school first.');
    }
    final start = weekStart(DateTime.now());
    final now = DateTime.now();
    final who = AuthService.currentUser?.fullName?.trim().isNotEmpty == true
        ? AuthService.currentUser!.fullName!.trim()
        : (AuthService.currentUser?.username ?? 'staff');
    final existing = reviewThisWeek(sid);
    final row = IctWeeklyReview(
      id: existing?.id ??
          ShortRegistryId.allocate(
            prefix: 'WK',
            existingIds: _reviews.map((e) => e.id),
            isTaken: (candidate) => _reviews.any((e) => e.id == candidate),
          ),
      schoolId: sid,
      weekStart: start,
      chairName: chairName.trim().isEmpty ? who : chairName.trim(),
      notes: notes.trim(),
      loginIssuesReviewed: loginIssuesReviewed,
      parentLinkPileReviewed: parentLinkPileReviewed,
      backupChecked: backupChecked,
      hardRefreshReminded: hardRefreshReminded,
      devicesChecked: devicesChecked,
      updatedBy: who,
      updatedAt: now,
    );
    final idx = _reviews.indexWhere((e) => e.id == row.id);
    if (idx >= 0) {
      _reviews[idx] = row;
    } else {
      _reviews.add(row);
    }
    notifyListeners();
    await DigitalOpsPersistenceService.instance.saveFromService();
    return row;
  }

  static DateTime weekStart(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

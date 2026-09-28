import 'package:flutter/foundation.dart';

/// Notifies dashboards and content screens when cloud homework, grades,
/// learning materials, timetables, messages, or workflow data changes.
class SchoolContentSyncService extends ChangeNotifier {
  SchoolContentSyncService._();
  static final instance = SchoolContentSyncService._();

  DateTime? _lastSyncedAt;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  void markDataChanged() {
    _lastSyncedAt = DateTime.now();
    notifyListeners();
  }
}

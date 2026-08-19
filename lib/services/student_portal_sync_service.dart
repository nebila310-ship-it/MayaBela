import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_account_service.dart';

/// Loading and refresh state for the student portal dashboard.
class StudentPortalSyncService extends ChangeNotifier {
  StudentPortalSyncService._();
  static final instance = StudentPortalSyncService._();

  bool _syncing = false;
  String? _error;
  DateTime? _lastSyncedAt;

  bool get isSyncing => _syncing;
  String? get error => _error;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  bool get hasLinkedProfile {
    if (AuthService.currentUser?.roleKey != AuthService.roleStudent) {
      return false;
    }
    return StudentAccountService.instance.recordForCurrentUser() != null;
  }

  void beginSync() {
    _syncing = true;
    _error = null;
    notifyListeners();
  }

  void completeSync() {
    _syncing = false;
    _error = null;
    _lastSyncedAt = DateTime.now();
    notifyListeners();
  }

  void failSync(String message) {
    _syncing = false;
    _error = message;
    notifyListeners();
  }

  void markDataChanged() {
    _lastSyncedAt = DateTime.now();
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

/// Live listeners for school inventory (owner + procurement / store / VP).
abstract final class InventoryRealtimeSync {
  static final List<StreamSubscription<dynamic>> _subscriptions = [];
  static Timer? _debounce;
  static bool _active = false;
  static final _crud = DocumentStore();

  static const _inventoryCollections = [
    AppCollections.inventoryItems,
    AppCollections.stockTransactions,
    AppCollections.studentIssuedItems,
    AppCollections.classroomInventory,
    AppCollections.assets,
    AppCollections.suppliers,
    AppCollections.maintenanceReports,
    AppCollections.purchaseRequests,
  ];

  /// Collections watched for live inventory (includes purchase requests).
  @visibleForTesting
  static List<String> get watchedCollections =>
      List<String>.unmodifiable(_inventoryCollections);

  @visibleForTesting
  static bool mayListenFor(RegisteredUser? user) {
    if (user == null) return false;
    if (user.roleKey == AuthService.roleAdmin) return true;
    if (user.roleKey != AuthService.roleTeacher) return false;
    final roles = user.staffRoles.map(StaffRoles.canonicalize).toSet();
    if (roles.contains(StaffRoles.fullAccess)) return true;
    return roles.contains(StaffRoles.procurement) ||
        roles.contains(StaffRoles.storekeeper) ||
        roles.contains(StaffRoles.vicePresident) ||
        roles.contains(StaffRoles.generalManager) ||
        roles.contains(StaffRoles.deputyGeneralManager) ||
        roles.contains(StaffRoles.principal) ||
        roles.contains(StaffRoles.schoolBoard);
  }

  static bool get _mayListenInventory =>
      mayListenFor(AuthService.currentUser);

  static void start() {
    if (!SupabaseBootstrap.isInitialized) return;
    if (!_mayListenInventory) return;
    if (_active) return;
    _active = true;

    for (final collection in _inventoryCollections) {
      _subscriptions.add(
        _crud.watchAll(collection).listen(_onCloudChange, onError: _logError),
      );
    }
  }

  static void stop() {
    _debounce?.cancel();
    _debounce = null;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    _active = false;
  }

  static void _onCloudChange(dynamic _) {
    _debounce?.cancel();
    final generation = AuthService.sessionGeneration;
    _debounce = Timer(const Duration(milliseconds: 900), () {
      if (!AuthService.isLiveGeneration(generation)) return;
      unawaited(CloudAppStore.instance.pullInventoryIntoService());
    });
  }

  static void _logError(Object error) {
    if (kDebugMode) {
      debugPrint('InventoryRealtimeSync: $error');
    }
  }
}

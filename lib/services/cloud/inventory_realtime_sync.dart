import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

/// Inventory no longer opens 8 live `app_documents` streams.
/// Updates arrive on the 5s/30s poll. Role gates stay for tests / future use.
abstract final class InventoryRealtimeSync {
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

  /// Collections that *would* be watched if live inventory streams return.
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

  static void start() {
    // Poll-only. Do not subscribe.
  }

  static void stop() {}
}

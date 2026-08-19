import 'package:flutter/material.dart';

import 'package:mayabela/widgets/dashboard_card.dart';

/// Captures dashboard tile [onTap] handlers for desktop sidebar navigation.
class DashboardNavigationStore {
  DashboardNavigationStore._();
  static final instance = DashboardNavigationStore._();

  final Map<String, VoidCallback> _actions = {};

  String _key(String roleKey, String entryId) => '$roleKey::$entryId';

  void register(String roleKey, String entryId, VoidCallback action) {
    _actions[_key(roleKey, entryId)] = action;
  }

  void clearRole(String roleKey) {
    _actions.removeWhere((key, _) => key.startsWith('$roleKey::'));
  }

  VoidCallback? actionFor(String roleKey, String entryId) =>
      _actions[_key(roleKey, entryId)];

  Widget wrapTile({
    required String roleKey,
    required String entryId,
    required Widget child,
  }) {
    if (child is DashboardCard && child.onTap != null) {
      register(roleKey, entryId, child.onTap!);
    }
    return child;
  }
}

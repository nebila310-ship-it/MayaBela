import 'package:flutter/foundation.dart';

/// Notifies dashboards and staff lists when teacher/transport registries change.
class StaffRegistryNotifier extends ChangeNotifier {
  StaffRegistryNotifier._();
  static final instance = StaffRegistryNotifier._();

  void notifyChanged() => notifyListeners();
}

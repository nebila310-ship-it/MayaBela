import 'package:flutter/material.dart';

/// Lifts all screens above the system home / back / gesture navigation bar.
class SystemNavSafeScope extends StatelessWidget {
  const SystemNavSafeScope({super.key, required this.child});

  final Widget child;

  static const double minimumBottomInset = 24;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      minimum: const EdgeInsets.only(bottom: minimumBottomInset),
      child: child,
    );
  }
}

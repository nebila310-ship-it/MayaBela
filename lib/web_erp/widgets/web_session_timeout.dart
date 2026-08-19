import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mayabela/utils/auth_navigation.dart';

/// Auto session timeout for web administrators (30 min idle).
class WebSessionTimeoutWrapper extends StatefulWidget {
  const WebSessionTimeoutWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<WebSessionTimeoutWrapper> createState() =>
      _WebSessionTimeoutWrapperState();
}

class _WebSessionTimeoutWrapperState extends State<WebSessionTimeoutWrapper> {
  static const _timeout = Duration(minutes: 30);
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    _armTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (DateTime.now().difference(_lastActivity) > _timeout) {
        AuthNavigation.performLogout();
      }
    });
  }

  void _bump() => _lastActivity = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _bump(),
      onPointerSignal: (_) => _bump(),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (_) => _bump(),
        child: widget.child,
      ),
    );
  }
}

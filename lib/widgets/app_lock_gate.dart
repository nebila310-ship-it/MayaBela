import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mayabela/services/app_lock_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/session_cloud_sync.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/utils/auth_navigation.dart';
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _lock = AppLockService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lock.addListener(_onSessionExpiredSignal);
  }

  @override
  void dispose() {
    _lock.removeListener(_onSessionExpiredSignal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSessionExpiredSignal() {
    if (!_lock.shouldEndSession) return;
    _performLogout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lock.onAppLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    final shouldLogout = await _lock.evaluateBackgroundLogout();
    if (shouldLogout) {
      _performLogout();
      return;
    }
    if (AuthService.currentUser != null) {
      unawaited(SessionCloudSync.pullCloudInBackground());
      unawaited(NotificationService.instance.onSessionStarted());
    }
  }
  void _performLogout() {
    if (AuthService.currentUser == null) return;
    AuthNavigation.performLogout();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _lock.recordActivity();
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (_) => _lock.recordActivity(),
        onPointerMove: (_) => _lock.recordActivity(),
        onPointerSignal: (_) => _lock.recordActivity(),
        child: widget.child,
      ),
    );
  }
}

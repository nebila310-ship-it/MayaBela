import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';

/// Logs the user out after the app is unused (foreground) or in the background
/// for the configured time (default 3 minutes).
class AppLockService extends ChangeNotifier {
  AppLockService._();
  static final instance = AppLockService._();

  static const backgroundLockOptions = [3, 5, 10, 15, 0];

  static const _backgroundLockKey = 'app_lock_background_minutes';

  bool _loaded = false;
  int _backgroundLockMinutes = 3;

  DateTime? _backgroundedAt;
  DateTime? _lastActivityAt;
  bool _isForeground = true;
  bool _skipNextResume = false;
  DateTime? _loginGraceUntil;

  Timer? _inactiveBackgroundTimer;
  Timer? _expiryTimer;

  bool get isLoaded => _loaded;
  int get backgroundLockMinutes => _backgroundLockMinutes;

  bool get _inLoginGrace =>
      _loginGraceUntil != null && DateTime.now().isBefore(_loginGraceUntil!);

  Duration get _logoutAfter => Duration(minutes: _backgroundLockMinutes);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _backgroundLockMinutes = prefs.getInt(_backgroundLockKey) ??
        prefs.getInt('app_lock_timeout_minutes') ??
        3;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setBackgroundLockMinutes(int minutes) async {
    _backgroundLockMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_backgroundLockKey, minutes);
    _rearmExpiryTimer();
    notifyListeners();
  }

  void handleLoginSuccess() {
    _clearBackgroundState();
    _skipNextResume = true;
    _loginGraceUntil = DateTime.now().add(const Duration(seconds: 5));
    _isForeground = true;
    _lastActivityAt = DateTime.now();
    Timer(const Duration(seconds: 5), () {
      _loginGraceUntil = null;
      if (AuthService.currentUser != null) {
        _rearmExpiryTimer();
      }
    });
    notifyListeners();
  }

  void ensureSessionMonitoring() {
    if (AuthService.currentUser == null) return;
    _isForeground = true;
    _clearBackgroundState();
    _lastActivityAt ??= DateTime.now();
    if (!_inLoginGrace) {
      _rearmExpiryTimer();
    }
  }

  void handleLogout() {
    _cancelExpiryTimer();
    _clearBackgroundState();
    _skipNextResume = false;
    _loginGraceUntil = null;
    _lastActivityAt = null;
    notifyListeners();
  }

  void recordActivity() {
    if (AuthService.currentUser == null) return;
    _lastActivityAt = DateTime.now();
    if (_inLoginGrace) return;
    if (_isForeground) {
      _clearBackgroundState();
      _rearmExpiryTimer();
    }
  }

  void onAppLifecycle(AppLifecycleState state) {
    if (AuthService.currentUser == null || _inLoginGrace) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _inactiveBackgroundTimer?.cancel();
        _isForeground = false;
        _backgroundedAt ??= DateTime.now();
        _rearmExpiryTimer();
      case AppLifecycleState.inactive:
        _inactiveBackgroundTimer?.cancel();
        _inactiveBackgroundTimer = Timer(const Duration(milliseconds: 800), () {
          if (AuthService.currentUser == null || _inLoginGrace) return;
          _isForeground = false;
          _backgroundedAt ??= DateTime.now();
          _rearmExpiryTimer();
        });
      case AppLifecycleState.resumed:
        _inactiveBackgroundTimer?.cancel();
        _isForeground = true;
        _rearmExpiryTimer();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<bool> evaluateBackgroundLogout() async {
    if (AuthService.currentUser == null || _inLoginGrace) return false;

    if (_skipNextResume) {
      _skipNextResume = false;
      _clearBackgroundState();
      recordActivity();
      return false;
    }

    final expired = shouldEndSession;
    if (expired) {
      _clearBackgroundState();
    } else {
      _backgroundedAt = null;
      recordActivity();
    }
    return expired;
  }

  bool get shouldEndSession {
    if (AuthService.currentUser == null || _inLoginGrace) return false;
    if (_backgroundLockMinutes == 0) return false;

    final limit = _logoutAfter;

    if (!_isForeground && _backgroundedAt != null) {
      return DateTime.now().difference(_backgroundedAt!) >= limit;
    }

    if (_isForeground) {
      final anchor = _lastActivityAt;
      if (anchor == null) return false;
      return DateTime.now().difference(anchor) >= limit;
    }

    return false;
  }

  void _rearmExpiryTimer() {
    _cancelExpiryTimer();
    if (AuthService.currentUser == null ||
        _inLoginGrace ||
        _backgroundLockMinutes == 0) {
      return;
    }

    Duration remaining;
    if (!_isForeground && _backgroundedAt != null) {
      remaining = _logoutAfter - DateTime.now().difference(_backgroundedAt!);
    } else if (_isForeground && _lastActivityAt != null) {
      remaining = _logoutAfter - DateTime.now().difference(_lastActivityAt!);
    } else {
      return;
    }

    if (remaining <= Duration.zero) {
      _evaluateSessionExpiry();
      return;
    }

    _expiryTimer = Timer(remaining, _evaluateSessionExpiry);
  }

  void _evaluateSessionExpiry() {
    if (!shouldEndSession) {
      _rearmExpiryTimer();
      return;
    }
    notifyListeners();
  }

  void _cancelExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  void _clearBackgroundState() {
    _backgroundedAt = null;
  }
}

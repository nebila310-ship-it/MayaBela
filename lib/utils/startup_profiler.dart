import 'package:flutter/foundation.dart';

/// Logs startup and navigation task timings (debug/profile builds).
abstract final class StartupProfiler {
  static final Map<String, int> _timingsMs = {};
  static final Map<String, DateTime> _starts = {};

  static void start(String task) {
    _starts[task] = DateTime.now();
    if (kDebugMode) {
      debugPrint('[Startup] ▶ $task');
    }
  }

  static void end(String task) {
    final started = _starts.remove(task);
    if (started == null) return;
    final ms = DateTime.now().difference(started).inMilliseconds;
    _timingsMs[task] = ms;
    if (kDebugMode) {
      debugPrint('[Startup] ✓ $task: ${ms}ms');
    }
  }

  static Future<T> track<T>(String task, Future<T> Function() run) async {
    start(task);
    try {
      return await run();
    } finally {
      end(task);
    }
  }

  static T trackSync<T>(String task, T Function() run) {
    start(task);
    try {
      return run();
    } finally {
      end(task);
    }
  }

  static Map<String, int> get report => Map.unmodifiable(_timingsMs);

  static void printSummary({String title = 'Startup Performance Summary'}) {
    if (!kDebugMode || _timingsMs.isEmpty) return;
    final sorted = _timingsMs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    debugPrint('[Startup] === $title ===');
    for (final entry in sorted) {
      debugPrint('[Startup]   ${entry.key}: ${entry.value}ms');
    }
  }
}

/// Dedupes critical startup work so login and [AppBootstrap] share one run.
class CriticalBootstrapGate {
  CriticalBootstrapGate._();

  static Future<void> Function()? _bootstrap;
  static Future<void>? _future;

  static void bind(Future<void> Function() bootstrap) {
    _bootstrap = bootstrap;
  }

  static Future<void> ensureReady() {
    final bootstrap = _bootstrap;
    if (bootstrap == null) return Future.value();
    return _future ??= bootstrap();
  }
}

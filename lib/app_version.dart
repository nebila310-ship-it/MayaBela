/// App version shown on login so testers can confirm they installed the latest APK.
///
/// Override with `--dart-define=MAYABELA_VERSION=...` when building a pilot APK.
const kMayaBelaVersion = String.fromEnvironment(
  'MAYABELA_VERSION',
  defaultValue: '1.0.6+7',
);

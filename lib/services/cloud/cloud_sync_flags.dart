/// Master switch for school data cloud sync (upload / download / live tick).
///
/// Auth login (school-login edge) stays available independently of this flag.
abstract final class CloudSyncFlags {
  static const bool enabled = true;
}

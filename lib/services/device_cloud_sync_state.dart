import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/persistence/auth_persistence_service.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

/// Detects when a device still needs its first successful Firestore pull.
abstract final class DeviceCloudSyncState {
  static const _demoUsernames = AuthPersistenceService.builtInUsernames;
  static final _seedAdminKey = PhoneUtils.loginKey('0911000003');

  static bool get registriesLookEmpty =>
      StudentRegistryService.instance.getAllStudents().isEmpty &&
      TeacherRegistryService.instance.getAllTeachers().isEmpty &&
      DriverRegistryService.instance.getAllDrivers().isEmpty;

  /// True when real school accounts exist locally (not built-in demo seeds).
  static bool get hasRealSchoolAccounts {
    for (final entry in AuthService.allUsers.entries) {
      if (_demoUsernames.contains(entry.key)) continue;
      if (entry.key == _seedAdminKey) continue;
      final user = entry.value;
      final school = user.schoolId?.trim();
      if (school != null && school.isNotEmpty) return true;
    }
    return false;
  }

  static bool get needsInitialCloudSync {
    if (!SupabaseBootstrap.isInitialized) return false;
    return registriesLookEmpty;
  }

  static bool get shouldPullCredentialsBeforeLogin {
    if (!SupabaseBootstrap.isInitialized) return false;
    return registriesLookEmpty || !hasRealSchoolAccounts;
  }

  static bool get hasLocalDataToPush =>
      !registriesLookEmpty || CloudOutboxService.instance.hasPending;
}

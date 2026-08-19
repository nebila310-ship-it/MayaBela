import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

/// Persists registered accounts so parent signups survive app restarts.
class AuthPersistenceService {
  AuthPersistenceService._();
  static final instance = AuthPersistenceService._();

  static const _usersKey = 'persisted_auth_users';

  /// Demo usernames seeded in code — not removed when clearing extras.
  static const builtInUsernames = {
    'teacher',
    'parent',
    'admin',
    'driver',
    'transport',
  };

  Future<void> loadMerged() async {
    final stored = await LocalJsonStore.readList(_usersKey);
    for (final map in stored) {
      final user = _userFromMap(map);
      if (user == null) continue;
      AuthService.mergePersistedUser(user);
    }
  }

  Future<void> saveAll() async {
    final items = AuthService.allUsers.entries
        .where((e) => !builtInUsernames.contains(e.key))
        .map((e) => _userToMap(e.value))
        .toList();
    await LocalJsonStore.writeList(_usersKey, items);
  }

  Future<void> syncUserToCloud(RegisteredUser user) async {
    await CloudAppStore.instance.pushAuthUser(user);
  }

  Map<String, dynamic> _userToMap(RegisteredUser user) => {
        'username': user.username,
        // Never persist secrets locally in a recoverable form for cloud users.
        'password': AuthService.passwordRedactedMarker,
        'roleKey': user.roleKey,
        if (user.email != null) 'email': user.email,
        if (user.phone != null) 'phone': user.phone,
        if (user.schoolId != null) 'schoolId': user.schoolId,
        if (user.fullName != null) 'fullName': user.fullName,
        'linkedStudentIds': user.linkedStudentIds,
        if (user.linkedTeacherId != null) 'linkedTeacherId': user.linkedTeacherId,
        if (user.linkedAdminId != null) 'linkedAdminId': user.linkedAdminId,
        if (user.linkedDriverId != null) 'linkedDriverId': user.linkedDriverId,
        if (user.linkedStudentId != null) 'linkedStudentId': user.linkedStudentId,
        'mustChangePassword': user.mustChangePassword,
        if (user.staffRoles.isNotEmpty) 'staffRoles': user.staffRoles,
        if (user.staffPermissions.isNotEmpty)
          'staffPermissions': user.staffPermissions,
      };

  RegisteredUser? _userFromMap(Map<String, dynamic> map) {
    try {
      return RegisteredUser(
        username: map['username'] as String,
        password: map['password'] as String,
        roleKey: map['roleKey'] as String,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        schoolId: map['schoolId'] as String?,
        fullName: map['fullName'] as String?,
        linkedStudentIds: (map['linkedStudentIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        linkedTeacherId: map['linkedTeacherId'] as String?,
        linkedAdminId: map['linkedAdminId'] as String?,
        linkedDriverId: map['linkedDriverId'] as String?,
        linkedStudentId: map['linkedStudentId'] as String?,
        mustChangePassword: map['mustChangePassword'] as bool? ?? false,
        staffRoles: (map['staffRoles'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        staffPermissions: (map['staffPermissions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
    } catch (_) {
      return null;
    }
  }
}

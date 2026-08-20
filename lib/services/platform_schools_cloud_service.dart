import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/school_registry_persistence_service.dart';
import 'package:mayabela/services/platform_owner_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

class PlatformSchoolCloudResult {
  const PlatformSchoolCloudResult({
    required this.ok,
    this.schoolId,
    this.errorCode,
    this.errorMessage,
  });

  final bool ok;
  final String? schoolId;
  final String? errorCode;
  final String? errorMessage;
}

/// Back-compat alias used by create-school callers.
typedef PlatformCreateSchoolResult = PlatformSchoolCloudResult;

/// Platform-owner cloud helpers (all schools, not one active school).
class PlatformSchoolsCloudService {
  PlatformSchoolsCloudService._();
  static final instance = PlatformSchoolsCloudService._();

  Future<String?> _ownerPinOrNull() async {
    await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
    if (!SupabaseBootstrap.isInitialized) return null;
    await PlatformOwnerService.instance.syncPinWithCloud();
    final pin = PlatformOwnerService.instance.sessionOwnerPin?.trim();
    if (pin == null || pin.length < PlatformOwnerService.minPinLength) {
      return null;
    }
    return pin;
  }

  PlatformSchoolCloudResult _parseFunctionError(
    FunctionException e, {
    required String fallback,
  }) {
    if (kDebugMode) {
      debugPrint(
        'PlatformSchoolsCloudService: ${e.status} ${e.details}',
      );
    }
    final details = e.details;
    String? code;
    String? message;
    if (details is Map) {
      code = details['code']?.toString();
      message = details['error']?.toString() ?? details['message']?.toString();
    } else if (details is String) {
      message = details;
      final codeMatch = RegExp(r'"code"\s*:\s*"([^"]+)"').firstMatch(details);
      final errMatch = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(details);
      code = codeMatch?.group(1);
      message = errMatch?.group(1) ?? message;
    }
    return PlatformSchoolCloudResult(
      ok: false,
      errorCode: code ?? 'invalid',
      errorMessage: message ?? '$fallback (${e.status}).',
    );
  }

  /// Create school_registry + bootstrap admin in Supabase (service-role edge).
  /// Fails closed — local-only create must not claim success.
  Future<PlatformSchoolCloudResult> createSchoolInCloud({
    required SchoolRecord school,
    required String adminUsername,
    required String adminFullName,
    required String adminPhone,
    required String password,
    String? adminEmail,
    bool mustChangePassword = false,
  }) async {
    try {
      final ownerPin = await _ownerPinOrNull();
      if (!SupabaseBootstrap.isInitialized) {
        return const PlatformSchoolCloudResult(
          ok: false,
          errorCode: 'cloud_required',
          errorMessage: 'Cloud is not configured on this build.',
        );
      }
      if (ownerPin == null) {
        return const PlatformSchoolCloudResult(
          ok: false,
          errorCode: 'unauthorized',
          errorMessage:
              'Unlock the platform console with your Owner PIN, then retry.',
        );
      }

      final res = await SupabaseBootstrap.client.functions.invoke(
        'platform-create-school',
        body: {
          'ownerPin': ownerPin,
          'school': school.toJson(),
          'schoolId': school.id.trim().toUpperCase(),
          'adminUsername': adminUsername.trim(),
          'adminFullName': adminFullName.trim(),
          'adminPhone': adminPhone.trim(),
          'password': password,
          'adminEmail': adminEmail?.trim(),
          'mustChangePassword': mustChangePassword,
        },
      );
      final data = res.data;
      if (data is! Map) {
        return const PlatformSchoolCloudResult(
          ok: false,
          errorCode: 'invalid',
          errorMessage: 'Unexpected cloud response.',
        );
      }
      if (data['error'] != null || data['ok'] != true) {
        return PlatformSchoolCloudResult(
          ok: false,
          errorCode: (data['code'] as String?) ?? 'invalid',
          errorMessage: data['error']?.toString() ?? 'Cloud create failed.',
        );
      }
      final id = (data['schoolId'] as String?)?.trim().toUpperCase();
      return PlatformSchoolCloudResult(
        ok: true,
        schoolId: id ?? school.id.trim().toUpperCase(),
      );
    } on FunctionException catch (e) {
      return _parseFunctionError(e, fallback: 'Cloud create failed');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformSchoolsCloudService.createSchoolInCloud failed: $e');
      }
      return PlatformSchoolCloudResult(
        ok: false,
        errorCode: 'invalid',
        errorMessage: e.toString(),
      );
    }
  }

  /// Update school_registry (and optional admin password) via service-role edge.
  Future<PlatformSchoolCloudResult> updateSchoolInCloud({
    required SchoolRecord school,
    String? adminPassword,
    String? adminUsername,
  }) async {
    try {
      final ownerPin = await _ownerPinOrNull();
      if (!SupabaseBootstrap.isInitialized) {
        return const PlatformSchoolCloudResult(
          ok: false,
          errorCode: 'cloud_required',
          errorMessage: 'Cloud is not configured on this build.',
        );
      }
      if (ownerPin == null) {
        return const PlatformSchoolCloudResult(
          ok: false,
          errorCode: 'unauthorized',
          errorMessage:
              'Unlock the platform console with your Owner PIN, then retry.',
        );
      }

      final res = await SupabaseBootstrap.client.functions.invoke(
        'platform-update-school',
        body: {
          'ownerPin': ownerPin,
          'school': school.toJson(),
          'schoolId': school.id.trim().toUpperCase(),
          if (adminPassword != null && adminPassword.isNotEmpty)
            'adminPassword': adminPassword,
          if (adminUsername != null && adminUsername.trim().isNotEmpty)
            'adminUsername': adminUsername.trim(),
        },
      );
      final data = res.data;
      if (data is! Map) {
        return const PlatformSchoolCloudResult(
          ok: false,
          errorCode: 'invalid',
          errorMessage: 'Unexpected cloud response.',
        );
      }
      if (data['error'] != null || data['ok'] != true) {
        return PlatformSchoolCloudResult(
          ok: false,
          errorCode: (data['code'] as String?) ?? 'invalid',
          errorMessage: data['error']?.toString() ?? 'Cloud update failed.',
        );
      }
      return PlatformSchoolCloudResult(
        ok: true,
        schoolId: school.id.trim().toUpperCase(),
      );
    } on FunctionException catch (e) {
      return _parseFunctionError(e, fallback: 'Cloud update failed');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformSchoolsCloudService.updateSchoolInCloud failed: $e');
      }
      return PlatformSchoolCloudResult(
        ok: false,
        errorCode: 'invalid',
        errorMessage: e.toString(),
      );
    }
  }

  /// Pull every school_registry doc into the local registry (merge).
  Future<int> syncAllSchoolsFromCloud() async {
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      if (!SupabaseBootstrap.isInitialized) return 0;

      final ownerPin = PlatformOwnerService.instance.sessionOwnerPin?.trim();
      if (ownerPin == null ||
          ownerPin.length < PlatformOwnerService.minPinLength) {
        return 0;
      }

      final res = await SupabaseBootstrap.client.functions.invoke(
        'platform-list-schools',
        body: {'action': 'list', 'ownerPin': ownerPin},
      );
      final data = res.data;
      if (data is! Map) return 0;
      final raw = data['schools'];
      if (raw is! List) return 0;

      var count = 0;
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] as String?)?.trim().toUpperCase();
          if (id == null || id.isEmpty) continue;
          map['id'] = id;
          SchoolRegistryService.instance.upsertSchool(
            AppDataMaps.schoolFromMap(map),
          );
          count++;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('PlatformSchoolsCloudService parse school: $e');
          }
        }
      }

      // Drop demo TB-001 when real cloud schools exist and TB-001 is not among them.
      if (count > 0) {
        SchoolRegistryService.instance.removeDemoIfNotInCloud(
          cloudIds: raw
              .whereType<Map>()
              .map((m) => (m['id'] as String?)?.trim().toUpperCase() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
      }

      await SchoolRegistryPersistenceService.instance.saveFromService(
        pushCloud: false,
      );

      // Local-only orphans cannot be pushed without a school JWT; leave them
      // for the owner to recreate via platform-create-school.
      try {
        final cloudIds = raw
            .whereType<Map>()
            .map((m) => (m['id'] as String?)?.trim().toUpperCase() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        for (final school
            in SchoolRegistryService.instance.allSchoolsSnapshot()) {
          final id = school.id.trim().toUpperCase();
          if (id.isEmpty || id == 'TB-001') continue;
          if (!cloudIds.contains(id)) {
            if (kDebugMode) {
              debugPrint(
                'PlatformSchoolsCloudService: local-only school $id '
                '(recreate from owner console to sync)',
              );
            }
            // Keep the old attempt for admin recovery, but do not pretend push works.
            await CloudAppStore.instance.pushSchool(school);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PlatformSchoolsCloudService push missing: $e');
        }
      }

      return count;
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'PlatformSchoolsCloudService.sync: ${e.status} ${e.details}',
        );
      }
      return 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformSchoolsCloudService.sync failed: $e');
      }
      return 0;
    }
  }
}

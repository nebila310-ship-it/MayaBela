/// Stable ID mappings between legacy class names / driver IDs and schema IDs.
abstract final class IdUtils {
  static const classNameById = {
    'C001': 'Grade 4A',
    'C002': 'Grade 2C',
    'C003': 'Grade 5B',
  };

  static const classIdByName = {
    'Grade 4A': 'C001',
    'Grade 2C': 'C002',
    'Grade 5B': 'C003',
  };

  static const routeIdByDriverId = {
    'DRV-1001': 'R001',
    'DRV-1002': 'R002',
    'DRV-1003': 'R003',
  };

  static const legacyRouteIdBySchemaRouteId = {
    'R001': 'route-bole',
    'R002': 'route-piassa',
    'R003': 'route-megenagna',
  };

  static String classIdForName(String className) {
    final trimmed = className.trim();
    return classIdByName[trimmed] ?? 'C-${trimmed.hashCode.abs()}';
  }

  static String? classNameForId(String classId) =>
      classNameById[classId.trim().toUpperCase()] ??
      classNameById[classId.trim()];

  static String routeIdForDriver(String driverId) =>
      routeIdByDriverId[driverId.trim().toUpperCase()] ??
      'R-${driverId.trim().toUpperCase()}';

  static String? legacyRouteIdForSchemaRoute(String routeId) =>
      legacyRouteIdBySchemaRouteId[routeId.trim().toUpperCase()];

  static String? schemaRouteIdForLegacyRoute(String legacyRouteId) {
    for (final entry in legacyRouteIdBySchemaRouteId.entries) {
      if (entry.value == legacyRouteId) return entry.key;
    }
    return null;
  }

  static String driverIdForRoute(String routeId) {
    for (final entry in routeIdByDriverId.entries) {
      if (entry.value == routeId.trim().toUpperCase()) return entry.key;
    }
    return routeId;
  }

  static List<String> splitFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return ['', ''];
    if (parts.length == 1) return [parts.first, ''];
    return [parts.first, parts.sublist(1).join(' ')];
  }
}

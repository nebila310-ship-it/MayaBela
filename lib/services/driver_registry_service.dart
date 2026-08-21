import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/ethiopian_employment_tax.dart';
import 'package:mayabela/services/persistence/driver_persistence_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

class AdminDriverRecord {
  AdminDriverRecord({
    required this.driverId,
    required this.busId,
    required this.fullName,
    required this.busNumber,
    required this.routeName,
    required this.plateNumber,
    required this.schoolId,
    this.email,
    this.phone,
    this.photoPath,
    this.isActive = true,
    this.loginUsername,
    this.initialPassword,
    this.basicSalaryEtb = 0,
    this.taxableAllowancesEtb = 0,
  });

  final String driverId;
  /// Stable bus link ID shared with parents (e.g. BUS-1001).
  final String busId;
  final String fullName;
  final String busNumber;
  final String routeName;
  final String plateNumber;
  final String schoolId;
  final String? email;
  final String? phone;
  final String? photoPath;
  final bool isActive;
  final String? loginUsername;
  final String? initialPassword;
  final double basicSalaryEtb;
  final double taxableAllowancesEtb;

  AdminDriverRecord copyWith({
    String? fullName,
    String? busId,
    String? busNumber,
    String? routeName,
    String? plateNumber,
    String? email,
    String? phone,
    String? photoPath,
    bool? isActive,
    String? loginUsername,
    String? initialPassword,
    double? basicSalaryEtb,
    double? taxableAllowancesEtb,
  }) {
    return AdminDriverRecord(
      driverId: driverId,
      busId: busId ?? this.busId,
      fullName: fullName ?? this.fullName,
      busNumber: busNumber ?? this.busNumber,
      routeName: routeName ?? this.routeName,
      plateNumber: plateNumber ?? this.plateNumber,
      schoolId: schoolId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoPath: photoPath ?? this.photoPath,
      isActive: isActive ?? this.isActive,
      loginUsername: loginUsername ?? this.loginUsername,
      initialPassword: initialPassword ?? this.initialPassword,
      basicSalaryEtb: basicSalaryEtb ?? this.basicSalaryEtb,
      taxableAllowancesEtb:
          taxableAllowancesEtb ?? this.taxableAllowancesEtb,
    );
  }

  Map<String, dynamic> toMap() => {
        'driverId': driverId,
        'busId': busId,
        'fullName': fullName,
        'busNumber': busNumber,
        'routeName': routeName,
        'plateNumber': plateNumber,
        'schoolId': schoolId,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (photoPath != null) 'photoPath': photoPath,
        'isActive': isActive,
        if (loginUsername != null) 'loginUsername': loginUsername,
        if (initialPassword != null) 'initialPassword': initialPassword,
        'basicSalaryEtb': basicSalaryEtb,
        'taxableAllowancesEtb': taxableAllowancesEtb,
      };

  factory AdminDriverRecord.fromMap(Map<String, dynamic> map) {
    final driverId = (map['driverId'] as String? ?? '').trim().toUpperCase();
    return AdminDriverRecord(
      driverId: driverId,
      busId: (map['busId'] as String?)?.trim().toUpperCase().isNotEmpty == true
          ? (map['busId'] as String).trim().toUpperCase()
          : DriverRegistryService.legacyBusIdForDriverId(driverId),
      fullName: map['fullName'] as String? ?? '',
      busNumber: map['busNumber'] as String? ?? '',
      routeName: map['routeName'] as String? ?? '',
      plateNumber: map['plateNumber'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      photoPath: map['photoPath'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      loginUsername: map['loginUsername'] as String?,
      initialPassword: map['initialPassword'] as String?,
      basicSalaryEtb: EthiopianEmploymentTax.parseEtb(map['basicSalaryEtb']),
      taxableAllowancesEtb:
          EthiopianEmploymentTax.parseEtb(map['taxableAllowancesEtb']),
    );
  }
}

/// Drivers registered by admin — replace with API fetch later.
class DriverRegistryService {
  DriverRegistryService._();
  static final instance = DriverRegistryService._();

  int _nextId = 1004;

  final List<AdminDriverRecord> _drivers = [
    AdminDriverRecord(
      driverId: 'DRV-1001',
      busId: 'BUS-1001',
      fullName: 'Alemayehu T.',
      busNumber: 'Bus 12',
      routeName: 'Bole → Megenagna → School',
      plateNumber: 'AA-3-45678',
      schoolId: 'TB-001',
      email: 'alemayehu@mayaschool.et',
      phone: '0911667788',
      loginUsername: 'driver',
      initialPassword: kDebugMode
          ? AuthService.demoPassword
          : AuthService.tempPassword,
    ),
    AdminDriverRecord(
      driverId: 'DRV-1002',
      busId: 'BUS-1002',
      fullName: 'Tadesse M.',
      busNumber: 'Bus 07',
      routeName: 'Piassa → School',
      plateNumber: 'AA-2-11223',
      schoolId: 'TB-001',
      email: 'tadesse@mayaschool.et',
      phone: '0911778899',
      loginUsername: '0911778899',
      initialPassword: kDebugMode
          ? AuthService.demoPassword
          : AuthService.tempPassword,
    ),
    AdminDriverRecord(
      driverId: 'DRV-1003',
      busId: 'BUS-1003',
      fullName: 'Solomon K.',
      busNumber: 'Bus 05',
      routeName: 'Megenagna → School',
      plateNumber: 'AA-4-99887',
      schoolId: 'TB-001',
      phone: '0911889900',
      loginUsername: '0911889900',
      initialPassword: kDebugMode
          ? AuthService.demoPassword
          : AuthService.tempPassword,
    ),
  ];

  List<AdminDriverRecord> getAllDrivers() =>
      List.unmodifiable(_drivers.where((d) => d.isActive));

  List<AdminDriverRecord> driversForSchool(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) return getAllDrivers();
    final id = schoolId.trim().toUpperCase();
    return _drivers
        .where((d) => d.isActive && d.schoolId.toUpperCase() == id)
        .toList();
  }

  AdminDriverRecord? lookupById(String driverId) {
    final id = driverId.trim().toUpperCase();
    try {
      return _drivers.firstWhere((d) => d.driverId == id && d.isActive);
    } catch (_) {
      return null;
    }
  }

  AdminDriverRecord? lookupByBusId(String busId) {
    final id = busId.trim().toUpperCase();
    try {
      return _drivers.firstWhere((d) => d.busId == id && d.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Accepts BUS-xxxx (preferred) or legacy DRV-xxxx transport references.
  AdminDriverRecord? resolveTransportReference(String reference) {
    final id = reference.trim().toUpperCase();
    if (id.isEmpty) return null;
    if (id.startsWith('BUS-')) {
      final bus = BusRegistryService.instance.lookupById(id);
      final assigned = bus?.assignedDriverId;
      if (assigned != null && assigned.isNotEmpty) {
        return lookupById(assigned) ?? lookupByBusId(id);
      }
      return lookupByBusId(id);
    }
    if (id.startsWith('DRV-')) {
      return lookupById(id);
    }
    return lookupByBusId(id) ?? lookupById(id);
  }

  /// Parent/student transport ID — prefers BUS id, falls back to driver id.
  String transportLinkIdForDriver(String driverId) {
    final driver = lookupById(driverId);
    if (driver == null) return driverId.trim().toUpperCase();
    return driver.busId;
  }

  bool transportReferenceMatchesDriver(String? reference, String driverId) {
    if (reference == null || reference.trim().isEmpty) return false;
    final driver = resolveTransportReference(reference);
    return driver?.driverId.toUpperCase() == driverId.trim().toUpperCase();
  }

  String? driverIdForTransportReference(String? reference) {
    if (reference == null || reference.trim().isEmpty) return null;
    return resolveTransportReference(reference)?.driverId;
  }

  static String legacyBusIdForDriverId(String driverId) {
    final normalized = driverId.trim().toUpperCase();
    final match = RegExp(r'DRV-(\d+)').firstMatch(normalized);
    if (match != null) {
      return 'BUS-${match.group(1)}';
    }
    return 'BUS-${normalized.hashCode.abs()}';
  }

  static String normalizeBusNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (RegExp(r'^bus\b', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed.replaceFirst(
        RegExp(r'^bus\s*', caseSensitive: false),
        'Bus ',
      );
    }
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'Bus $trimmed';
    }
    return trimmed;
  }

  AdminDriverRecord? lookupByPhone(String phone, {String? schoolId}) {
    for (final driver in _drivers.where((d) => d.isActive)) {
      if (!PhoneUtils.matches(driver.phone, phone)) continue;
      if (schoolId != null &&
          driver.schoolId.toUpperCase() != schoolId.trim().toUpperCase()) {
        continue;
      }
      return driver;
    }
    return null;
  }

  AdminDriverRecord? lookupByLoginUsername(String username) {
    final lower = username.trim().toLowerCase();
    try {
      return _drivers.firstWhere(
        (d) =>
            d.isActive &&
            (d.loginUsername?.toLowerCase() == lower ||
                PhoneUtils.loginKey(d.phone ?? '') == lower),
      );
    } catch (_) {
      return null;
    }
  }

  /// Resolves the transport record for a logged-in driver account.
  AdminDriverRecord? resolveForAuthUser({
    String? linkedDriverId,
    String? username,
    String? phone,
    String? schoolId,
  }) {
    if (linkedDriverId != null && linkedDriverId.trim().isNotEmpty) {
      final byId = lookupById(linkedDriverId);
      if (byId != null) return byId;
    }
    if (username != null && username.trim().isNotEmpty) {
      final byLogin = lookupByLoginUsername(username);
      if (byLogin != null) {
        if (schoolId == null ||
            byLogin.schoolId.toUpperCase() == schoolId.trim().toUpperCase()) {
          return byLogin;
        }
      }
    }
    if (phone != null && phone.trim().isNotEmpty) {
      return lookupByPhone(phone, schoolId: schoolId);
    }
    return null;
  }

  void _replace(AdminDriverRecord updated, {bool persist = true}) {
    final idx = _drivers.indexWhere((d) => d.driverId == updated.driverId);
    if (idx >= 0) _drivers[idx] = updated;
    if (persist) _schedulePersist();
  }

  void _schedulePersist() {
    unawaited(DriverPersistenceService.instance.saveRegistryFromService());
  }

  void updatePhoto(String driverId, String photoPath, {bool persist = true}) {
    final existing = lookupById(driverId);
    if (existing == null) return;
    _replace(existing.copyWith(photoPath: photoPath), persist: persist);
  }

  void saveCredentials({
    required String driverId,
    required String initialPassword,
    String? loginUsername,
    bool persist = true,
  }) {
    final existing = lookupById(driverId);
    if (existing == null) return;
    _replace(
      existing.copyWith(
        initialPassword: initialPassword,
        loginUsername: loginUsername ?? existing.loginUsername,
      ),
      persist: persist,
    );
  }

  void updateDriver(AdminDriverRecord updated) {
    _replace(updated);
    AuthService.syncDriverAuthProfile(updated);
  }

  /// Swaps bus route details between two active drivers.
  bool swapDriverBuses({
    required String fromDriverId,
    required String toDriverId,
  }) {
    final from = lookupById(fromDriverId);
    final to = lookupById(toDriverId);
    if (from == null || to == null || from.driverId == to.driverId) {
      return false;
    }
    _replace(
      from.copyWith(
        busId: to.busId,
        busNumber: to.busNumber,
        routeName: to.routeName,
        plateNumber: to.plateNumber,
      ),
    );
    _replace(
      to.copyWith(
        busId: from.busId,
        busNumber: from.busNumber,
        routeName: from.routeName,
        plateNumber: from.plateNumber,
      ),
    );
    return true;
  }

  bool deactivateDriver(String driverId) {
    final existing = lookupById(driverId);
    if (existing == null) return false;
    _replace(existing.copyWith(isActive: false));
    return true;
  }

  AdminDriverRecord addDriver({
    required String schoolId,
    required String fullName,
    required String busNumber,
    required String routeName,
    required String plateNumber,
    String? phone,
    String? email,
    String? photoPath,
    required String loginUsername,
    String? initialPassword,
  }) {
    final normalizedBus = normalizeBusNumber(busNumber);
    if (normalizedBus.isEmpty) {
      throw ArgumentError('busNumber is required');
    }

    final idNum = _allocateDriverIdNumber();
    final record = AdminDriverRecord(
      driverId: 'DRV-$idNum',
      busId: 'BUS-$idNum',
      fullName: fullName.trim(),
      busNumber: normalizedBus,
      routeName: routeName.trim(),
      plateNumber: plateNumber.trim().toUpperCase(),
      schoolId: schoolId.trim().toUpperCase(),
      phone: PhoneUtils.normalizeStoredPhone(phone),
      email: email?.trim().isEmpty ?? true ? null : email!.trim(),
      photoPath: photoPath,
      loginUsername: loginUsername.trim(),
      initialPassword: initialPassword,
    );
    _drivers.add(record);
    unawaited(
      BusRegistryService.instance.ensureBusForDriver(record),
    );
    return record;
  }

  void removeDriver(String driverId) {
    final id = driverId.trim().toUpperCase();
    _drivers.removeWhere((d) => d.driverId == id);
  }

  static final RegExp _shortDriverIdPattern = RegExp(r'^DRV-(\d{1,6})$');

  /// Short DRV-1004 style ids: next number = highest existing DRV-#### in the
  /// cloud-merged registry + 1, with a free-slot check so devices converge.
  int _allocateDriverIdNumber() {
    var highest = 1000;
    for (final d in _drivers) {
      final match =
          _shortDriverIdPattern.firstMatch(d.driverId.trim().toUpperCase());
      final n = match == null ? null : int.tryParse(match.group(1) ?? '');
      if (n != null && n > highest) highest = n;
    }
    var candidate = highest + 1;
    if (_nextId > candidate) candidate = _nextId;
    while (_drivers.any((d) => d.driverId == 'DRV-$candidate')) {
      candidate++;
    }
    _nextId = candidate + 1;
    return candidate;
  }

  List<AdminDriverRecord> registrySnapshot() => List.unmodifiable(_drivers);

  int get nextDriverIdCounter => _nextId;

  void applyPersistedDrivers(
    List<AdminDriverRecord> drivers, {
    int? nextId,
    bool replace = false,
  }) {
    if (replace) {
      _drivers
        ..clear()
        ..addAll(drivers);
    } else {
      for (final driver in drivers) {
        final index =
            _drivers.indexWhere((item) => item.driverId == driver.driverId);
        if (index >= 0) {
          _drivers[index] = driver;
        } else {
          _drivers.add(driver);
        }
      }
    }
    if (nextId != null && nextId > _nextId) {
      _nextId = nextId;
    }
  }

  static String formatRoute(
    String from,
    String to, {
    String? through,
  }) {
    final start = from.trim();
    final mid = through?.trim() ?? '';
    final end = to.trim();
    if (start.isEmpty && mid.isEmpty && end.isEmpty) return '';
    if (mid.isNotEmpty) {
      final parts = <String>[
        if (start.isNotEmpty) start,
        mid,
        if (end.isNotEmpty) end,
      ];
      return parts.join(' → ');
    }
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start → $end';
  }

  static ({String from, String through, String to}) parseRoute(String routeName) {
    final value = routeName.trim();
    if (value.isEmpty) return (from: '', through: '', to: '');

    final segments = value
        .split(RegExp(r'\s*(?:→|->|—>)\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (segments.length >= 3) {
      return (
        from: segments.first,
        through: segments.sublist(1, segments.length - 1).join(' → '),
        to: segments.last,
      );
    }
    if (segments.length == 2) {
      return (from: segments[0], through: '', to: segments[1]);
    }
    return (from: value, through: '', to: '');
  }
}

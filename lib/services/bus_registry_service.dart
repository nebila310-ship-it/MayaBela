import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/models/bus_record.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/persistence/bus_persistence_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// First-class bus registry (Phase E). Drivers and students link via busId.
class BusRegistryService extends ChangeNotifier {
  BusRegistryService._();
  static final instance = BusRegistryService._();

  final List<BusRecord> _buses = [];
  int _nextId = 1001;
  bool _seeded = false;

  String? get _schoolId => AuthService.activeSchoolId;

  bool get canManage =>
      AuthService.currentUser?.roleKey == AuthService.roleAdmin ||
      AuthService.hasPermission(SchoolPermissions.manageBuses);

  List<BusRecord> registrySnapshot() => List.unmodifiable(_buses);

  List<BusRecord> busesForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId)?.trim().toUpperCase();
    return _buses
        .where((b) =>
            b.isActive &&
            (sid == null || sid.isEmpty || b.schoolId.toUpperCase() == sid))
        .toList();
  }

  BusRecord? lookupById(String busId) {
    final id = busId.trim().toUpperCase();
    try {
      return _buses.firstWhere((b) => b.busId == id && b.isActive);
    } catch (_) {
      return null;
    }
  }

  BusRecord? lookupAnyById(String busId) {
    final id = busId.trim().toUpperCase();
    try {
      return _buses.firstWhere((b) => b.busId == id);
    } catch (_) {
      return null;
    }
  }

  int get nextBusIdCounter => _nextId;

  void applyPersistedBuses(
    List<BusRecord> buses, {
    int? nextId,
    bool replace = false,
  }) {
    if (replace) {
      _buses
        ..clear()
        ..addAll(buses);
    } else {
      for (final bus in buses) {
        final idx = _buses.indexWhere((b) => b.busId == bus.busId);
        if (idx >= 0) {
          _buses[idx] = bus;
        } else {
          _buses.add(bus);
        }
        final n = ShortRegistryId.parseNumber(bus.busId, prefix: 'BUS') ?? 0;
        if (n >= _nextId) _nextId = n + 1;
      }
    }
    final clamped = ShortRegistryId.clampCounter(nextId, fallback: _nextId);
    if (clamped > _nextId) _nextId = clamped;
    _seeded = _buses.isNotEmpty;
    notifyListeners();
  }

  /// One-time backfill from existing driver records (each driver had a bus).
  void seedFromDriversIfEmpty() {
    if (_seeded || _buses.isNotEmpty) return;
    final drivers = DriverRegistryService.instance.registrySnapshot();
    for (final d in drivers.where((d) => d.isActive)) {
      _buses.add(
        BusRecord(
          busId: d.busId,
          busNumber: d.busNumber,
          schoolId: d.schoolId,
          plateNumber: d.plateNumber,
          routeName: d.routeName,
          assignedDriverId: d.driverId,
        ),
      );
      final n = ShortRegistryId.parseNumber(d.busId, prefix: 'BUS') ?? 0;
      if (n >= _nextId) _nextId = n + 1;
    }
    _seeded = true;
    if (_buses.isNotEmpty) {
      unawaited(BusPersistenceService.instance.saveFromService());
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    await BusPersistenceService.instance.saveFromService();
    notifyListeners();
  }

  Future<BusRecord?> addBus({
    required String busNumber,
    required String plateNumber,
    String routeName = '',
    int capacity = 40,
    String? assignedDriverId,
    String? notes,
    String? schoolId,
  }) async {
    if (!canManage) return null;
    final number = DriverRegistryService.normalizeBusNumber(busNumber);
    if (number.isEmpty) return null;
    final sid = (schoolId ?? _schoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) return null;

    final busId = ShortRegistryId.allocate(
      prefix: 'BUS',
      existingIds: _buses.map((b) => b.busId),
      isTaken: (id) => lookupAnyById(id) != null,
      persistedNext: _nextId,
    );
    _nextId = (ShortRegistryId.parseNumber(busId) ?? 0) + 1;
    final bus = BusRecord(
      busId: busId,
      busNumber: number,
      schoolId: sid,
      plateNumber: plateNumber.trim().toUpperCase(),
      routeName: routeName.trim(),
      capacity: capacity > 0 ? capacity : 40,
      assignedDriverId: assignedDriverId?.trim().toUpperCase(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
    );
    _buses.insert(0, bus);

    if (bus.assignedDriverId != null) {
      await _syncDriverToBus(bus);
    }

    await SchoolAuditLogService.instance.log(
      action: 'bus_created',
      entityType: 'bus',
      entityId: bus.busId,
      detail: '${bus.busNumber} · ${bus.plateNumber}',
      after: bus.toMap(),
    );
    await _persist();
    return bus;
  }

  Future<bool> updateBus(BusRecord updated) async {
    if (!canManage) return false;
    final idx = _buses.indexWhere((b) => b.busId == updated.busId);
    if (idx < 0) return false;
    final before = _buses[idx];
    _buses[idx] = updated;
    await _syncDriverToBus(updated);
    await SchoolAuditLogService.instance.log(
      action: 'bus_updated',
      entityType: 'bus',
      entityId: updated.busId,
      detail: updated.busNumber,
      before: before.toMap(),
      after: updated.toMap(),
    );
    await _persist();
    return true;
  }

  Future<bool> assignDriver({
    required String busId,
    String? driverId,
  }) async {
    if (!canManage) return false;
    final bus = lookupAnyById(busId);
    if (bus == null) return false;

    final before = bus.toMap();
    // Clear this driver from any other bus first.
    final driverKey = driverId?.trim().toUpperCase();
    if (driverKey != null && driverKey.isNotEmpty) {
      for (var i = 0; i < _buses.length; i++) {
        if (_buses[i].assignedDriverId == driverKey &&
            _buses[i].busId != bus.busId) {
          _buses[i] = _buses[i].copyWith(clearAssignedDriver: true);
        }
      }
    }

    final updated = bus.copyWith(
      assignedDriverId: driverKey,
      clearAssignedDriver: driverKey == null || driverKey.isEmpty,
    );
    final idx = _buses.indexWhere((b) => b.busId == bus.busId);
    _buses[idx] = updated;
    await _syncDriverToBus(updated);

    await SchoolAuditLogService.instance.log(
      action: 'bus_driver_assigned',
      entityType: 'bus',
      entityId: bus.busId,
      detail: driverKey == null || driverKey.isEmpty
          ? 'unassigned'
          : 'driver $driverKey',
      before: before,
      after: updated.toMap(),
    );
    await _persist();
    return true;
  }

  Future<bool> deactivateBus(String busId) async {
    if (!canManage) return false;
    final bus = lookupById(busId);
    if (bus == null) return false;
    final updated = bus.copyWith(isActive: false, clearAssignedDriver: true);
    final idx = _buses.indexWhere((b) => b.busId == bus.busId);
    _buses[idx] = updated;
    await SchoolAuditLogService.instance.log(
      action: 'bus_deactivated',
      entityType: 'bus',
      entityId: bus.busId,
      detail: bus.busNumber,
      before: bus.toMap(),
      after: updated.toMap(),
    );
    await _persist();
    return true;
  }

  /// Keep the assigned driver's denormalized bus fields in sync for legacy UI.
  Future<void> _syncDriverToBus(BusRecord bus) async {
    final driverId = bus.assignedDriverId;
    if (driverId == null || driverId.isEmpty) return;
    final driver = DriverRegistryService.instance.lookupById(driverId);
    if (driver == null) return;
    if (driver.busId == bus.busId &&
        driver.busNumber == bus.busNumber &&
        driver.plateNumber == bus.plateNumber &&
        driver.routeName == bus.routeName) {
      return;
    }
    DriverRegistryService.instance.updateDriver(
      driver.copyWith(
        busId: bus.busId,
        busNumber: bus.busNumber,
        plateNumber: bus.plateNumber,
        routeName: bus.routeName,
      ),
    );
  }

  /// Called when a new driver is created with bus fields — ensures a bus row.
  Future<BusRecord> ensureBusForDriver(AdminDriverRecord driver) async {
    final existing = lookupAnyById(driver.busId);
    if (existing != null) {
      final updated = existing.copyWith(
        busNumber: driver.busNumber,
        plateNumber: driver.plateNumber,
        routeName: driver.routeName,
        assignedDriverId: driver.driverId,
        isActive: true,
      );
      final idx = _buses.indexWhere((b) => b.busId == existing.busId);
      _buses[idx] = updated;
      await _persist();
      return updated;
    }
    final bus = BusRecord(
      busId: driver.busId,
      busNumber: driver.busNumber,
      schoolId: driver.schoolId,
      plateNumber: driver.plateNumber,
      routeName: driver.routeName,
      assignedDriverId: driver.driverId,
    );
    _buses.insert(0, bus);
    final n = ShortRegistryId.parseNumber(bus.busId, prefix: 'BUS') ?? 0;
    if (n >= _nextId) _nextId = n + 1;
    await _persist();
    return bus;
  }
}

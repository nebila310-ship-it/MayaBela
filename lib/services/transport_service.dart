import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
/// Bus roster, onboard state, QR transport scans, and parent alerts.
class TransportService extends ChangeNotifier {
  TransportService._();
  static final instance = TransportService._();

  final Map<String, TransportPassengerStatus> _statusByStudentId = {};
  final List<TransportScanRecord> _scanHistory = [];

  static String qrCodeForStudentId(String studentId) =>
      'STUDENT:${studentId.trim().toUpperCase()}';

  String? get linkedDriverId => AuthService.resolvedLinkedDriverId;

  void applyCloudPassengerStatus(
    String studentId,
    TransportPassengerStatus status,
  ) {
    final id = studentId.trim().toUpperCase();
    if (id.isEmpty) return;
    _statusByStudentId[id] = status;
    notifyListeners();
  }

  void applyCloudScanHistory(List<TransportScanRecord> scans) {
    final existingKeys = _scanHistory
        .map(
          (s) =>
              '${s.driverId}_${s.studentId}_${s.time.millisecondsSinceEpoch}',
        )
        .toSet();
    for (final scan in scans) {
      final key =
          '${scan.driverId}_${scan.studentId}_${scan.time.millisecondsSinceEpoch}';
      if (existingKeys.contains(key)) continue;
      _scanHistory.add(scan);
      existingKeys.add(key);
    }
    _scanHistory.sort((a, b) => a.time.compareTo(b.time));
  }

  List<TransportScanRecord> scanHistoryForDriver(String driverId) {
    final id = driverId.trim().toUpperCase();
    return _scanHistory
        .where((r) => r.driverId.toUpperCase() == id)
        .toList()
        .reversed
        .toList();
  }

  List<TransportBusSummary> busesForSchool(String? schoolId) {
    // Prefer first-class bus entities; fall back to drivers if buses not seeded.
    final buses = BusRegistryService.instance.busesForSchool(schoolId);
    if (buses.isNotEmpty) {
      return buses.map((bus) {
        final driverId = bus.assignedDriverId ?? '';
        final passengers = driverId.isEmpty
            ? const <TransportPassenger>[]
            : passengersForDriver(driverId);
        final driver = driverId.isEmpty
            ? null
            : DriverRegistryService.instance.lookupById(driverId);
        return TransportBusSummary(
          driverId: driverId,
          busId: bus.busId,
          busNumber: bus.busNumber,
          routeName: bus.routeName,
          driverName: driver?.fullName ?? 'Unassigned',
          plateNumber: bus.plateNumber,
          passengerCount: passengers.length,
          onboardCount: passengers.where((p) => p.isOnboard).length,
          capacity: bus.capacity,
        );
      }).toList();
    }

    final drivers = schoolId == null || schoolId.trim().isEmpty
        ? DriverRegistryService.instance.getAllDrivers()
        : DriverRegistryService.instance.driversForSchool(schoolId);

    return drivers.map((driver) {
      final passengers = passengersForDriver(driver.driverId);
      final onboard =
          passengers.where((p) => p.isOnboard).length;
      return TransportBusSummary(
        driverId: driver.driverId,
        busId: driver.busId,
        busNumber: driver.busNumber,
        routeName: driver.routeName,
        driverName: driver.fullName,
        plateNumber: driver.plateNumber,
        passengerCount: passengers.length,
        onboardCount: onboard,
      );
    }).toList();
  }

  List<TransportPassenger> passengersForDriver(String driverId) {
    final id = driverId.trim().toUpperCase();
    final driver = DriverRegistryService.instance.lookupById(id);
    if (driver == null) return [];

    final db = SchoolDatabaseService.instance;
    final studentRecords = db.isInitialized
        ? db.studentsOnDriverRoute(id)
        : null;

    List<AdminStudentRecord> students;
    if (studentRecords != null && studentRecords.isNotEmpty) {
      students = studentRecords
          .map((s) => StudentRegistryService.instance.lookupById(s.studentId))
          .whereType<AdminStudentRecord>()
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
    } else {
      students = StudentRegistryService.instance
          .getAllStudents()
          .where(
            (s) =>
                s.isActive &&
                s.transportEnabled &&
                DriverRegistryService.instance
                    .transportReferenceMatchesDriver(s.transportId, id),
          )
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
    }

    return students.map((student) {
      final status = _statusByStudentId[student.studentId.toUpperCase()] ??
          _statusByStudentId[student.studentId] ??
          TransportPassengerStatus.waiting;
      return TransportPassenger(
        studentId: student.studentId,
        fullName: student.fullName,
        className: student.className,
        grade: student.grade,
        qrCode: qrCodeForStudentId(student.studentId),
        status: status,
      );
    }).toList();
  }

  AdminDriverRecord? driverForId(String driverId) =>
      DriverRegistryService.instance.lookupById(driverId);

  /// Driver ID assigned to a student on school transport (e.g. DRV-1001).
  String? driverIdForStudent(String studentId) {
    final db = SchoolDatabaseService.instance;
    if (db.isInitialized) {
      final fromDb = db.driverIdForStudent(studentId);
      if (fromDb != null && fromDb.trim().isNotEmpty) {
        return fromDb.trim().toUpperCase();
      }
    }

    final record = StudentRegistryService.instance.lookupById(studentId);
    if (record != null &&
        record.transportEnabled &&
        record.transportId != null &&
        record.transportId!.trim().isNotEmpty) {
      return DriverRegistryService.instance
          .driverIdForTransportReference(record.transportId);
    }
    return null;
  }

  /// Driver ID assigned to a student on school transport (e.g. DRV-1001).
  String? driverIdForChildName(String childName) {
    final record = StudentRegistryService.instance.lookupByName(childName);
    if (record != null) return driverIdForStudent(record.studentId);
    return null;
  }

  String? primaryParentDriverId() {
    final children = SchoolDataService.instance.getChildren();
    if (children.isEmpty) return null;
    final first = children.first;
    if (first.studentId != null) {
      return driverIdForStudent(first.studentId!);
    }
    return driverIdForChildName(first.name);
  }

  TransportPassenger? passengerForStudent(String studentId) {
    final driverId = driverIdForStudent(studentId);
    if (driverId == null) return null;
    for (final passenger in passengersForDriver(driverId)) {
      if (passenger.studentId.toUpperCase() == studentId.toUpperCase()) {
        return passenger;
      }
    }
    return null;
  }

  TransportPassenger? passengerForChildName(String childName) {
    final record = StudentRegistryService.instance.lookupByName(childName);
    if (record != null) return passengerForStudent(record.studentId);
    return null;
  }

  /// Keeps QR profiles in sync when students are enrolled or edited.
  void syncStudentQrProfile(AdminStudentRecord student) {
    SchoolDataService.instance.upsertStudentQrProfile(
      StudentQrProfile(
        id: student.studentId.toLowerCase(),
        name: student.fullName,
        className: student.className,
        qrCode: qrCodeForStudentId(student.studentId),
      ),
    );
  }

  String? resolveStudentIdFromQr(String rawCode, {String? driverId}) {
    final code = rawCode.trim();
    if (code.isEmpty) return null;

    if (code.toUpperCase().startsWith('STUDENT:')) {
      final id = code.substring('STUDENT:'.length).trim().toUpperCase();
      final record = StudentRegistryService.instance.lookupById(id);
      if (record != null) return record.studentId;
    }

    final legacy = SchoolDataService.instance.findStudentByQrCode(code);
    if (legacy != null) {
      final byName = StudentRegistryService.instance
          .getAllStudents()
          .where((s) => s.fullName == legacy.name)
          .toList();
      if (byName.isNotEmpty) return byName.first.studentId;
    }

    if (driverId != null) {
      final passengers = passengersForDriver(driverId);
      for (final p in passengers) {
        if (p.qrCode.toLowerCase() == code.toLowerCase()) {
          return p.studentId;
        }
      }
    }
    return null;
  }

  /// Returns null on success, or an error message.
  String? recordTransportScan({
    required String driverId,
    required String qrCode,
    required TransportScanMode mode,
    required String scannedBy,
  }) {
    final driver = DriverRegistryService.instance.lookupById(driverId);
    if (driver == null) return 'Driver not found';

    final studentId = resolveStudentIdFromQr(qrCode, driverId: driverId);
    if (studentId == null) return 'Invalid QR code';

    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return 'Student not found';

    final db = SchoolDatabaseService.instance;
    final onRoster = passengersForDriver(driverId)
        .any((p) => p.studentId.toUpperCase() == studentId.toUpperCase());

    if (!onRoster) {
      if (!student.transportEnabled) {
        return 'Student is not assigned to this bus';
      }
      if (db.isInitialized &&
          !db.canDriverAccessStudent(
            driverId: driverId,
            studentId: studentId,
          )) {
        return 'Student is not assigned to this bus';
      }
      if (!db.isInitialized &&
          !DriverRegistryService.instance.transportReferenceMatchesDriver(
            student.transportId,
            driverId,
          )) {
        return 'Student is not assigned to this bus';
      }
    }

    final current = _statusByStudentId[studentId] ??
        TransportPassengerStatus.waiting;

    if (mode == TransportScanMode.onboard) {
      if (current == TransportPassengerStatus.onboard) {
        return '${student.fullName} is already onboard';
      }
      _statusByStudentId[studentId] = TransportPassengerStatus.onboard;
      _appendScan(
        studentId: studentId,
        studentName: student.fullName,
        driverId: driverId,
        mode: mode,
        scannedBy: scannedBy,
      );
      _persistScanToCloud(
        studentId: studentId,
        driverId: driverId,
        status: TransportPassengerStatus.onboard,
        scannedBy: scannedBy,
      );
      _notifyParentOnboard(
        student: student,
        driver: driver,
        scannedBy: scannedBy,
      );
    } else {
      if (current != TransportPassengerStatus.onboard) {
        return '${student.fullName} is not onboard';
      }
      _statusByStudentId[studentId] = TransportPassengerStatus.waiting;
      _appendScan(
        studentId: studentId,
        studentName: student.fullName,
        driverId: driverId,
        mode: mode,
        scannedBy: scannedBy,
      );
      _persistScanToCloud(
        studentId: studentId,
        driverId: driverId,
        status: TransportPassengerStatus.waiting,
        scannedBy: scannedBy,
      );
      _notifyParentDischarge(
        student: student,
        driver: driver,
        scannedBy: scannedBy,
      );
    }

    notifyListeners();
    return null;
  }

  void resetPassengersForDriver(String driverId) {
    for (final p in passengersForDriver(driverId)) {
      _statusByStudentId[p.studentId] = TransportPassengerStatus.waiting;
    }
    notifyListeners();
  }

  void _appendScan({
    required String studentId,
    required String studentName,
    required String driverId,
    required TransportScanMode mode,
    required String scannedBy,
  }) {
    final record = TransportScanRecord(
      studentId: studentId,
      studentName: studentName,
      driverId: driverId,
      mode: mode,
      time: DateTime.now(),
      scannedBy: scannedBy,
    );
    _scanHistory.add(record);
    unawaited(CloudAppStore.instance.pushTransportScan(record));
  }

  void _persistScanToCloud({
    required String studentId,
    required String driverId,
    required TransportPassengerStatus status,
    required String scannedBy,
  }) {
    unawaited(
      CloudAppStore.instance.pushTransportPassengerStatus(
        studentId: studentId,
        driverId: driverId,
        status: status,
        updatedAt: DateTime.now(),
        updatedBy: scannedBy,
      ),
    );
  }

  void _notifyParentOnboard({
    required AdminStudentRecord student,
    required AdminDriverRecord driver,
    required String scannedBy,
  }) {
    NotificationService.instance.push(
      title: 'Child boarded bus',
      body:
          '${student.fullName} boarded ${driver.busNumber} (${driver.routeName}). '
          'Driver: ${driver.fullName} · Plate ${driver.plateNumber}. '
          'Scanned by $scannedBy.',
      type: NotificationType.bus,
      fromRole: AuthService.roleDriver,
      fromName: scannedBy,
      recipientRole: AuthService.roleParent,
      targetStudentId: student.studentId,
    );
  }

  void _notifyParentDischarge({
    required AdminStudentRecord student,
    required AdminDriverRecord driver,
    required String scannedBy,
  }) {
    NotificationService.instance.push(
      title: 'Child left the bus',
      body:
          '${student.fullName} was discharged from ${driver.busNumber} '
          '(${driver.routeName}). Driver: ${driver.fullName}. '
          'Scanned by $scannedBy.',
      type: NotificationType.bus,
      fromRole: AuthService.roleDriver,
      fromName: scannedBy,
      recipientRole: AuthService.roleParent,
      targetStudentId: student.studentId,
    );
  }
}

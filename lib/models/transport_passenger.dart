/// Live passenger status on a school bus route.
enum TransportPassengerStatus {
  /// Not on the bus (waiting or already dropped off).
  waiting,
  /// Scanned onboard — active on the bus.
  onboard,
}

enum TransportScanMode { onboard, discharge }

class TransportBusSummary {
  const TransportBusSummary({
    required this.driverId,
    required this.busNumber,
    required this.routeName,
    required this.driverName,
    required this.plateNumber,
    required this.passengerCount,
    required this.onboardCount,
    this.busId,
    this.capacity,
  });

  final String driverId;
  final String busNumber;
  final String routeName;
  final String driverName;
  final String plateNumber;
  final int passengerCount;
  final int onboardCount;
  final String? busId;
  final int? capacity;
}

class TransportPassenger {
  TransportPassenger({
    required this.studentId,
    required this.fullName,
    required this.className,
    required this.grade,
    required this.qrCode,
    this.status = TransportPassengerStatus.waiting,
    this.lastUpdated,
  });

  final String studentId;
  final String fullName;
  final String className;
  final String grade;
  final String qrCode;
  TransportPassengerStatus status;
  DateTime? lastUpdated;

  bool get isOnboard => status == TransportPassengerStatus.onboard;
}

class TransportScanRecord {
  TransportScanRecord({
    required this.studentId,
    required this.studentName,
    required this.driverId,
    required this.mode,
    required this.time,
    required this.scannedBy,
  });

  final String studentId;
  final String studentName;
  final String driverId;
  final TransportScanMode mode;
  final DateTime time;
  final String scannedBy;
}

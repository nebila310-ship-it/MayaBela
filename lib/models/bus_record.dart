/// First-class school bus entity (Phase E).
///
/// Drivers hold a [busId] FK; students keep [transportId] = BUS-*.
/// Plate, capacity, and route live on the bus — not only on the driver.
class BusRecord {
  BusRecord({
    required this.busId,
    required this.busNumber,
    required this.schoolId,
    this.plateNumber = '',
    this.routeName = '',
    this.capacity = 40,
    this.assignedDriverId,
    this.isActive = true,
    this.notes,
  });

  final String busId;
  final String busNumber;
  final String schoolId;
  final String plateNumber;
  final String routeName;
  final int capacity;
  final String? assignedDriverId;
  final bool isActive;
  final String? notes;

  BusRecord copyWith({
    String? busNumber,
    String? plateNumber,
    String? routeName,
    int? capacity,
    String? assignedDriverId,
    bool clearAssignedDriver = false,
    bool? isActive,
    String? notes,
  }) {
    return BusRecord(
      busId: busId,
      busNumber: busNumber ?? this.busNumber,
      schoolId: schoolId,
      plateNumber: plateNumber ?? this.plateNumber,
      routeName: routeName ?? this.routeName,
      capacity: capacity ?? this.capacity,
      assignedDriverId: clearAssignedDriver
          ? null
          : (assignedDriverId ?? this.assignedDriverId),
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'busId': busId,
        'busNumber': busNumber,
        'schoolId': schoolId,
        'plateNumber': plateNumber,
        'routeName': routeName,
        'capacity': capacity,
        if (assignedDriverId != null) 'assignedDriverId': assignedDriverId,
        'isActive': isActive,
        if (notes != null) 'notes': notes,
      };

  static BusRecord fromMap(Map<String, dynamic> map) {
    return BusRecord(
      busId: (map['busId'] as String? ?? map['id'] as String? ?? '')
          .trim()
          .toUpperCase(),
      busNumber: map['busNumber'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      plateNumber: (map['plateNumber'] as String? ?? '').trim().toUpperCase(),
      routeName: map['routeName'] as String? ?? '',
      capacity: (map['capacity'] as num?)?.toInt() ?? 40,
      assignedDriverId: (map['assignedDriverId'] as String?)?.trim().toUpperCase(),
      isActive: map['isActive'] as bool? ?? true,
      notes: map['notes'] as String?,
    );
  }
}

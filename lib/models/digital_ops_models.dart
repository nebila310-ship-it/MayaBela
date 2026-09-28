enum IctDeviceKind { laptop, phone, driverPhone, labPc, tablet, other }

IctDeviceKind ictDeviceKindFromName(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'laptop':
      return IctDeviceKind.laptop;
    case 'phone':
      return IctDeviceKind.phone;
    case 'driverPhone':
      return IctDeviceKind.driverPhone;
    case 'labPc':
      return IctDeviceKind.labPc;
    case 'tablet':
      return IctDeviceKind.tablet;
    default:
      return IctDeviceKind.other;
  }
}

extension IctDeviceKindX on IctDeviceKind {
  String get storageName => switch (this) {
        IctDeviceKind.laptop => 'laptop',
        IctDeviceKind.phone => 'phone',
        IctDeviceKind.driverPhone => 'driverPhone',
        IctDeviceKind.labPc => 'labPc',
        IctDeviceKind.tablet => 'tablet',
        IctDeviceKind.other => 'other',
      };

  String get label => switch (this) {
        IctDeviceKind.laptop => 'Laptop',
        IctDeviceKind.phone => 'Staff phone',
        IctDeviceKind.driverPhone => 'Driver phone (GPS)',
        IctDeviceKind.labPc => 'Computer lab PC',
        IctDeviceKind.tablet => 'Tablet',
        IctDeviceKind.other => 'Other',
      };
}

class IctDeviceRecord {
  IctDeviceRecord({
    required this.id,
    required this.schoolId,
    required this.kind,
    required this.label,
    required this.assignedTo,
    required this.notes,
    required this.updatedBy,
    required this.updatedAt,
    this.location = '',
    this.gpsEnabled = false,
  });

  final String id;
  final String schoolId;
  final IctDeviceKind kind;
  final String label;
  final String assignedTo;
  final String location;
  final String notes;
  final bool gpsEnabled;
  final String updatedBy;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'kind': kind.storageName,
        'label': label,
        'assignedTo': assignedTo,
        'location': location,
        'notes': notes,
        'gpsEnabled': gpsEnabled,
        'updatedBy': updatedBy,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory IctDeviceRecord.fromMap(Map<String, dynamic> map) {
    return IctDeviceRecord(
      id: '${map['id'] ?? map['_docId'] ?? ''}',
      schoolId: '${map['schoolId'] ?? ''}'.trim().toUpperCase(),
      kind: ictDeviceKindFromName(map['kind'] as String?),
      label: '${map['label'] ?? ''}',
      assignedTo: '${map['assignedTo'] ?? ''}',
      location: '${map['location'] ?? ''}',
      notes: '${map['notes'] ?? ''}',
      gpsEnabled: map['gpsEnabled'] == true,
      updatedBy: '${map['updatedBy'] ?? ''}',
      updatedAt: DateTime.tryParse('${map['updatedAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class IctWeeklyReview {
  IctWeeklyReview({
    required this.id,
    required this.schoolId,
    required this.weekStart,
    required this.chairName,
    required this.notes,
    required this.loginIssuesReviewed,
    required this.parentLinkPileReviewed,
    required this.backupChecked,
    required this.hardRefreshReminded,
    required this.devicesChecked,
    required this.updatedBy,
    required this.updatedAt,
  });

  final String id;
  final String schoolId;
  final DateTime weekStart;
  final String chairName;
  final String notes;
  final bool loginIssuesReviewed;
  final bool parentLinkPileReviewed;
  final bool backupChecked;
  final bool hardRefreshReminded;
  final bool devicesChecked;
  final String updatedBy;
  final DateTime updatedAt;

  bool get complete =>
      loginIssuesReviewed &&
      parentLinkPileReviewed &&
      backupChecked &&
      hardRefreshReminded &&
      devicesChecked;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'weekStart': weekStart.toIso8601String(),
        'chairName': chairName,
        'notes': notes,
        'loginIssuesReviewed': loginIssuesReviewed,
        'parentLinkPileReviewed': parentLinkPileReviewed,
        'backupChecked': backupChecked,
        'hardRefreshReminded': hardRefreshReminded,
        'devicesChecked': devicesChecked,
        'updatedBy': updatedBy,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory IctWeeklyReview.fromMap(Map<String, dynamic> map) {
    return IctWeeklyReview(
      id: '${map['id'] ?? map['_docId'] ?? ''}',
      schoolId: '${map['schoolId'] ?? ''}'.trim().toUpperCase(),
      weekStart: DateTime.tryParse('${map['weekStart'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      chairName: '${map['chairName'] ?? ''}',
      notes: '${map['notes'] ?? ''}',
      loginIssuesReviewed: map['loginIssuesReviewed'] == true,
      parentLinkPileReviewed: map['parentLinkPileReviewed'] == true,
      backupChecked: map['backupChecked'] == true,
      hardRefreshReminded: map['hardRefreshReminded'] == true,
      devicesChecked: map['devicesChecked'] == true,
      updatedBy: '${map['updatedBy'] ?? ''}',
      updatedAt: DateTime.tryParse('${map['updatedAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

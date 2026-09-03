enum ConsentPurpose { dataProcessing, photos, messaging, transport }

enum ConsentState { granted, revoked }

enum DataRightsKind { access, erasure }

enum DataRightsStatus { open, reviewing, redacted, denied }

class MfaEnrollment {
  const MfaEnrollment({
    required this.id,
    required this.schoolId,
    required this.username,
    required this.secret,
    required this.enabled,
    required this.recoveryCodeHashes,
    required this.enrolledAt,
    this.enrolledBy = '',
  });

  final String id;
  final String schoolId;
  final String username;
  final String secret;
  final bool enabled;
  final List<String> recoveryCodeHashes;
  final DateTime enrolledAt;
  final String enrolledBy;

  MfaEnrollment copyWith({
    String? secret,
    bool? enabled,
    List<String>? recoveryCodeHashes,
    bool clearSecret = false,
  }) {
    return MfaEnrollment(
      id: id,
      schoolId: schoolId,
      username: username,
      secret: clearSecret ? '' : (secret ?? this.secret),
      enabled: enabled ?? this.enabled,
      recoveryCodeHashes:
          recoveryCodeHashes ?? List<String>.from(this.recoveryCodeHashes),
      enrolledAt: enrolledAt,
      enrolledBy: enrolledBy,
    );
  }

  Map<String, dynamic> toMap({bool includeSecret = true}) => {
        'id': id,
        'schoolId': schoolId,
        'username': username,
        if (includeSecret) 'secret': secret,
        'enabled': enabled,
        if (includeSecret) 'recoveryCodeHashes': recoveryCodeHashes,
        'enrolledAt': enrolledAt.toIso8601String(),
        'enrolledBy': enrolledBy,
      };

  factory MfaEnrollment.fromMap(Map<String, dynamic> map) {
    final hashes = <String>[];
    final raw = map['recoveryCodeHashes'];
    if (raw is List) {
      for (final item in raw) {
        final value = item.toString().trim();
        if (value.isNotEmpty) hashes.add(value);
      }
    }
    return MfaEnrollment(
      id: (map['id'] ?? '').toString(),
      schoolId: (map['schoolId'] ?? '').toString().toUpperCase(),
      username: (map['username'] ?? '').toString(),
      secret: (map['secret'] ?? '').toString(),
      enabled: map['enabled'] == true,
      recoveryCodeHashes: hashes,
      enrolledAt: DateTime.tryParse('${map['enrolledAt']}') ?? DateTime.now(),
      enrolledBy: (map['enrolledBy'] ?? '').toString(),
    );
  }
}

class PrivacyConsent {
  const PrivacyConsent({
    required this.id,
    required this.schoolId,
    required this.subjectName,
    required this.purpose,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.subjectRole = '',
    this.studentId = '',
    this.authorUsername = '',
  });

  final String id;
  final String schoolId;
  final String subjectName;
  final String subjectRole;
  final String studentId;
  final ConsentPurpose purpose;
  final ConsentState state;
  final String authorUsername;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get granted => state == ConsentState.granted;

  PrivacyConsent copyWith({
    ConsentState? state,
    DateTime? updatedAt,
  }) {
    return PrivacyConsent(
      id: id,
      schoolId: schoolId,
      subjectName: subjectName,
      purpose: purpose,
      state: state ?? this.state,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subjectRole: subjectRole,
      studentId: studentId,
      authorUsername: authorUsername,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'subjectName': subjectName,
        'subjectRole': subjectRole,
        'studentId': studentId,
        'purpose': purpose.name,
        'state': state.name,
        'authorUsername': authorUsername,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PrivacyConsent.fromMap(Map<String, dynamic> map) {
    return PrivacyConsent(
      id: (map['id'] ?? '').toString(),
      schoolId: (map['schoolId'] ?? '').toString().toUpperCase(),
      subjectName: (map['subjectName'] ?? '').toString(),
      subjectRole: (map['subjectRole'] ?? '').toString(),
      studentId: (map['studentId'] ?? '').toString().toUpperCase(),
      purpose: ConsentPurpose.values.firstWhere(
        (item) => item.name == map['purpose'],
        orElse: () => ConsentPurpose.dataProcessing,
      ),
      state: ConsentState.values.firstWhere(
        (item) => item.name == map['state'],
        orElse: () => ConsentState.granted,
      ),
      authorUsername: (map['authorUsername'] ?? '').toString(),
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${map['updatedAt']}') ?? DateTime.now(),
    );
  }
}

class DataRightsRequest {
  const DataRightsRequest({
    required this.id,
    required this.schoolId,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.studentId = '',
    this.studentName = '',
    this.authorUsername = '',
    this.authorRole,
    this.details = '',
    this.staffNote = '',
  });

  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final DataRightsKind kind;
  final DataRightsStatus status;
  final String authorUsername;
  final String? authorRole;
  final String details;
  final String staffNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  DataRightsRequest copyWith({
    DataRightsStatus? status,
    String? staffNote,
    DateTime? updatedAt,
  }) {
    return DataRightsRequest(
      id: id,
      schoolId: schoolId,
      kind: kind,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      studentId: studentId,
      studentName: studentName,
      authorUsername: authorUsername,
      authorRole: authorRole,
      details: details,
      staffNote: staffNote ?? this.staffNote,
    );
  }

  Map<String, dynamic> toMap({bool includeStaffNote = true}) => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        'kind': kind.name,
        'status': status.name,
        'authorUsername': authorUsername,
        'authorRole': authorRole,
        'details': details,
        if (includeStaffNote) 'staffNote': staffNote,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DataRightsRequest.fromMap(Map<String, dynamic> map) {
    return DataRightsRequest(
      id: (map['id'] ?? '').toString(),
      schoolId: (map['schoolId'] ?? '').toString().toUpperCase(),
      studentId: (map['studentId'] ?? '').toString().toUpperCase(),
      studentName: (map['studentName'] ?? '').toString(),
      kind: DataRightsKind.values.firstWhere(
        (item) => item.name == map['kind'],
        orElse: () => DataRightsKind.access,
      ),
      status: DataRightsStatus.values.firstWhere(
        (item) => item.name == map['status'],
        orElse: () => DataRightsStatus.open,
      ),
      authorUsername: (map['authorUsername'] ?? '').toString(),
      authorRole: map['authorRole']?.toString(),
      details: (map['details'] ?? '').toString(),
      staffNote: (map['staffNote'] ?? '').toString(),
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${map['updatedAt']}') ?? DateTime.now(),
    );
  }
}

class SchoolBackupRecord {
  const SchoolBackupRecord({
    required this.id,
    required this.schoolId,
    required this.createdAt,
    required this.createdBy,
    this.studentCount = 0,
    this.staffCount = 0,
    this.mfaCount = 0,
    this.notes = '',
  });

  final String id;
  final String schoolId;
  final DateTime createdAt;
  final String createdBy;
  final int studentCount;
  final int staffCount;
  final int mfaCount;
  final String notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'studentCount': studentCount,
        'staffCount': staffCount,
        'mfaCount': mfaCount,
        'notes': notes,
      };

  factory SchoolBackupRecord.fromMap(Map<String, dynamic> map) {
    return SchoolBackupRecord(
      id: (map['id'] ?? '').toString(),
      schoolId: (map['schoolId'] ?? '').toString().toUpperCase(),
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? DateTime.now(),
      createdBy: (map['createdBy'] ?? '').toString(),
      studentCount: int.tryParse('${map['studentCount']}') ?? 0,
      staffCount: int.tryParse('${map['staffCount']}') ?? 0,
      mfaCount: int.tryParse('${map['mfaCount']}') ?? 0,
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

class StudentImportRow {
  const StudentImportRow({
    required this.fullName,
    required this.grade,
    required this.className,
    required this.dateOfBirth,
    this.gender,
    this.fatherName,
    this.fatherPhone,
    this.motherName,
    this.motherPhone,
    this.existingId,
  });

  final String fullName;
  final String grade;
  final String className;
  final DateTime dateOfBirth;
  final String? gender;
  final String? fatherName;
  final String? fatherPhone;
  final String? motherName;
  final String? motherPhone;
  final String? existingId;
}

class StudentImportResult {
  const StudentImportResult({
    required this.createdIds,
    required this.skipped,
  });

  final List<String> createdIds;
  final List<String> skipped;
}

class GoLiveCapacitySnapshot {
  const GoLiveCapacitySnapshot({
    required this.cloudReady,
    required this.storageReady,
    required this.lastBackupAt,
    required this.mfaEnrolled,
    required this.openDataRights,
  });

  final bool cloudReady;
  final bool storageReady;
  final DateTime? lastBackupAt;
  final int mfaEnrolled;
  final int openDataRights;
}

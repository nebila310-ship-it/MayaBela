enum StaffLeaveType { annual, sick, unpaid, maternity, compassionate }

enum StaffLeaveStatus { pending, approved, rejected }

enum StaffEmploymentStage { probation, confirmed, endingSoon, expired }

enum HrPersonKind { admin, teacher, employee }

class HrPersonRef {
  const HrPersonRef({
    required this.personId,
    required this.schoolId,
    required this.name,
    required this.kind,
    this.title = '',
  });

  final String personId;
  final String schoolId;
  final String name;
  final HrPersonKind kind;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is HrPersonRef &&
      other.personId == personId &&
      other.schoolId == schoolId;

  @override
  int get hashCode => Object.hash(personId, schoolId);
}

class StaffEmploymentFile {
  const StaffEmploymentFile({
    required this.personId,
    required this.schoolId,
    required this.personName,
    required this.kind,
    this.hiredOn,
    this.contractEnd,
    this.probationEnds,
    this.notes = '',
  });

  final String personId;
  final String schoolId;
  final String personName;
  final HrPersonKind kind;
  final DateTime? hiredOn;
  final DateTime? contractEnd;
  final DateTime? probationEnds;
  final String notes;

  StaffEmploymentStage stageOn(DateTime asOf) {
    final day = DateTime(asOf.year, asOf.month, asOf.day);
    if (contractEnd != null) {
      final end = DateTime(
        contractEnd!.year,
        contractEnd!.month,
        contractEnd!.day,
      );
      if (end.isBefore(day)) return StaffEmploymentStage.expired;
      if (end.difference(day).inDays <= 60) {
        return StaffEmploymentStage.endingSoon;
      }
    }
    if (probationEnds != null) {
      final end = DateTime(
        probationEnds!.year,
        probationEnds!.month,
        probationEnds!.day,
      );
      if (!end.isBefore(day)) return StaffEmploymentStage.probation;
    }
    return StaffEmploymentStage.confirmed;
  }

  StaffEmploymentFile copyWith({
    String? personName,
    DateTime? hiredOn,
    DateTime? contractEnd,
    DateTime? probationEnds,
    String? notes,
    bool clearHiredOn = false,
    bool clearContractEnd = false,
    bool clearProbation = false,
  }) {
    return StaffEmploymentFile(
      personId: personId,
      schoolId: schoolId,
      personName: personName ?? this.personName,
      kind: kind,
      hiredOn: clearHiredOn ? null : (hiredOn ?? this.hiredOn),
      contractEnd: clearContractEnd ? null : (contractEnd ?? this.contractEnd),
      probationEnds: clearProbation ? null : (probationEnds ?? this.probationEnds),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'personId': personId,
        'schoolId': schoolId,
        'personName': personName,
        'kind': kind.name,
        if (hiredOn != null) 'hiredOn': hiredOn!.toIso8601String(),
        if (contractEnd != null) 'contractEnd': contractEnd!.toIso8601String(),
        if (probationEnds != null)
          'probationEnds': probationEnds!.toIso8601String(),
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory StaffEmploymentFile.fromMap(Map<String, dynamic> map) {
    DateTime? parse(String key) {
      final raw = map[key] as String?;
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return StaffEmploymentFile(
      personId: (map['personId'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      personName: map['personName'] as String? ?? '',
      kind: HrPersonKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => HrPersonKind.employee,
      ),
      hiredOn: parse('hiredOn'),
      contractEnd: parse('contractEnd'),
      probationEnds: parse('probationEnds'),
      notes: map['notes'] as String? ?? '',
    );
  }
}

class StaffLeaveRecord {
  const StaffLeaveRecord({
    required this.id,
    required this.schoolId,
    required this.personId,
    required this.personName,
    required this.kind,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = StaffLeaveStatus.pending,
    this.reviewedBy = '',
    required this.createdAt,
  });

  final String id;
  final String schoolId;
  final String personId;
  final String personName;
  final HrPersonKind kind;
  final StaffLeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final StaffLeaveStatus status;
  final String reviewedBy;
  final DateTime createdAt;

  int get days {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.difference(start).inDays + 1;
  }

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  StaffLeaveRecord copyWith({
    StaffLeaveStatus? status,
    String? reviewedBy,
  }) {
    return StaffLeaveRecord(
      id: id,
      schoolId: schoolId,
      personId: personId,
      personName: personName,
      kind: kind,
      type: type,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'personId': personId,
        'personName': personName,
        'kind': kind.name,
        'type': type.name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'reason': reason,
        'status': status.name,
        if (reviewedBy.isNotEmpty) 'reviewedBy': reviewedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StaffLeaveRecord.fromMap(Map<String, dynamic> map) {
    return StaffLeaveRecord(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      personId: map['personId'] as String? ?? '',
      personName: map['personName'] as String? ?? '',
      kind: HrPersonKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => HrPersonKind.employee,
      ),
      type: StaffLeaveType.values.firstWhere(
        (k) => k.name == map['type'],
        orElse: () => StaffLeaveType.annual,
      ),
      startDate: DateTime.tryParse(map['startDate'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endDate: DateTime.tryParse(map['endDate'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reason: map['reason'] as String? ?? '',
      status: StaffLeaveStatus.values.firstWhere(
        (k) => k.name == map['status'],
        orElse: () => StaffLeaveStatus.pending,
      ),
      reviewedBy: map['reviewedBy'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class HrWorkforceSnapshot {
  const HrWorkforceSnapshot({
    required this.adminStaff,
    required this.teachers,
    required this.otherStaff,
    required this.onLeaveToday,
    required this.pendingLeave,
    required this.contractsWatch,
  });

  final int adminStaff;
  final int teachers;
  final int otherStaff;
  final int onLeaveToday;
  final int pendingLeave;
  final int contractsWatch;

  int get headcount => adminStaff + teachers + otherStaff;
}

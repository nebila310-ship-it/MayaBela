enum GradeTeacherDecision { approved, rejected, changesRequested }

/// Grade submission and approval lifecycle.
enum SubjectGradeStatus {
  draft,
  pendingApproval,
  changesRequested,
  approved,
  rejected;

  static SubjectGradeStatus parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return SubjectGradeStatus.draft;
    final normalized = raw.trim();
    return SubjectGradeStatus.values.firstWhere(
      (value) => value.name == normalized,
      orElse: () => SubjectGradeStatus.draft,
    );
  }

  bool get canTeacherEdit =>
      this == draft || this == rejected || this == changesRequested;

  bool get isLockedForTeacher =>
      this == pendingApproval || this == approved;
}

/// Configurable approver roles in order (subject teacher enters; chain approves).
enum GradeApprovalRole {
  homeroomTeacher,
  academicCoordinator,
  vicePrincipal,
  admin;

  static GradeApprovalRole parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return GradeApprovalRole.admin;
    return GradeApprovalRole.values.firstWhere(
      (value) => value.name == raw.trim(),
      orElse: () => GradeApprovalRole.admin,
    );
  }

  String get label {
    return switch (this) {
      GradeApprovalRole.homeroomTeacher => 'Homeroom teacher',
      // EDUABA: Section Director approves grade reports before publish.
      GradeApprovalRole.academicCoordinator => 'Section Director',
      GradeApprovalRole.vicePrincipal => 'Vice Principal',
      GradeApprovalRole.admin => 'School Owner / Board',
    };
  }
}

/// Per-school grade approval configuration.
class GradeWorkflowSettings {
  const GradeWorkflowSettings({
    this.requireApproval = true,
    // EDUABA §3.1 — Section Director is the default approver.
    this.approvalChain = const [GradeApprovalRole.academicCoordinator],
    this.notifyApproversOnSubmit = true,
    this.notifyTeacherOnDecision = true,
    this.notifyParentsOnPublish = true,
  });

  final bool requireApproval;
  final List<GradeApprovalRole> approvalChain;
  final bool notifyApproversOnSubmit;
  final bool notifyTeacherOnDecision;
  final bool notifyParentsOnPublish;

  GradeWorkflowSettings copyWith({
    bool? requireApproval,
    List<GradeApprovalRole>? approvalChain,
    bool? notifyApproversOnSubmit,
    bool? notifyTeacherOnDecision,
    bool? notifyParentsOnPublish,
  }) {
    return GradeWorkflowSettings(
      requireApproval: requireApproval ?? this.requireApproval,
      approvalChain: approvalChain ?? this.approvalChain,
      notifyApproversOnSubmit:
          notifyApproversOnSubmit ?? this.notifyApproversOnSubmit,
      notifyTeacherOnDecision:
          notifyTeacherOnDecision ?? this.notifyTeacherOnDecision,
      notifyParentsOnPublish:
          notifyParentsOnPublish ?? this.notifyParentsOnPublish,
    );
  }

  Map<String, dynamic> toMap() => {
        'requireApproval': requireApproval,
        'approvalChain': approvalChain.map((role) => role.name).toList(),
        'notifyApproversOnSubmit': notifyApproversOnSubmit,
        'notifyTeacherOnDecision': notifyTeacherOnDecision,
        'notifyParentsOnPublish': notifyParentsOnPublish,
      };

  factory GradeWorkflowSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const GradeWorkflowSettings();
    final chainRaw = map['approvalChain'] as List?;
    final chain = chainRaw == null || chainRaw.isEmpty
        ? const [GradeApprovalRole.academicCoordinator]
        : chainRaw
            .map((e) => GradeApprovalRole.parse(e.toString()))
            .toList();
    return GradeWorkflowSettings(
      requireApproval: map['requireApproval'] as bool? ?? true,
      approvalChain: chain,
      notifyApproversOnSubmit: map['notifyApproversOnSubmit'] as bool? ?? true,
      notifyTeacherOnDecision: map['notifyTeacherOnDecision'] as bool? ?? true,
      notifyParentsOnPublish: map['notifyParentsOnPublish'] as bool? ?? true,
    );
  }
}

enum GradeAuditAction {
  created,
  updated,
  submitted,
  approved,
  rejected,
  changesRequested,
  published,
  unlocked,
}

class GradeAuditEntry {
  GradeAuditEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.schoolId,
    required this.className,
    required this.subject,
    required this.studentName,
    this.studentId,
    this.actorId,
    this.actorName,
    this.actorRole,
    this.detail,
    this.statusBefore,
    this.statusAfter,
  });

  final String id;
  final DateTime at;
  final GradeAuditAction action;
  final String schoolId;
  final String className;
  final String subject;
  final String studentName;
  final String? studentId;
  final String? actorId;
  final String? actorName;
  final String? actorRole;
  final String? detail;
  final String? statusBefore;
  final String? statusAfter;

  Map<String, dynamic> toMap() => {
        'id': id,
        'at': at.toIso8601String(),
        'action': action.name,
        'schoolId': schoolId,
        'className': className,
        'subject': subject,
        'studentName': studentName,
        if (studentId != null) 'studentId': studentId,
        if (actorId != null) 'actorId': actorId,
        if (actorName != null) 'actorName': actorName,
        if (actorRole != null) 'actorRole': actorRole,
        if (detail != null) 'detail': detail,
        if (statusBefore != null) 'statusBefore': statusBefore,
        if (statusAfter != null) 'statusAfter': statusAfter,
      };

  factory GradeAuditEntry.fromMap(Map<String, dynamic> map) => GradeAuditEntry(
        id: map['id'] as String? ?? '',
        at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
        action: GradeAuditAction.values.firstWhere(
          (value) => value.name == map['action'],
          orElse: () => GradeAuditAction.updated,
        ),
        schoolId: map['schoolId'] as String? ?? '',
        className: map['className'] as String? ?? '',
        subject: map['subject'] as String? ?? '',
        studentName: map['studentName'] as String? ?? '',
        studentId: map['studentId'] as String?,
        actorId: map['actorId'] as String?,
        actorName: map['actorName'] as String?,
        actorRole: map['actorRole'] as String?,
        detail: map['detail'] as String?,
        statusBefore: map['statusBefore'] as String?,
        statusAfter: map['statusAfter'] as String?,
      );
}

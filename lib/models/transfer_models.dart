import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

/// Student enrollment lifecycle (spec: ACTIVE / TRANSFERRED / LEFT).
/// Graduated is included for end-of-year promotion of the final grade.
enum StudentLifecycleStatus { active, transferred, left, graduated }

extension StudentLifecycleStatusX on StudentLifecycleStatus {
  static StudentLifecycleStatus parse(String? raw, {bool? isActiveFallback}) {
    final key = (raw ?? '').trim().toLowerCase();
    for (final value in StudentLifecycleStatus.values) {
      if (value.name == key) return value;
    }
    // Legacy rows only carry isActive.
    if (isActiveFallback == false) return StudentLifecycleStatus.left;
    return StudentLifecycleStatus.active;
  }

  bool get countsAsEnrolled => this == StudentLifecycleStatus.active;

  String get label => switch (this) {
        StudentLifecycleStatus.active => 'Active',
        StudentLifecycleStatus.transferred => 'Transferred',
        StudentLifecycleStatus.left => 'Left',
        StudentLifecycleStatus.graduated => 'Graduated',
      };
}

/// What a transfer request is asking to change.
enum TransferRequestKind {
  /// Same school: class / grade / campus move.
  internal,

  /// Student leaves the school (status → transferred or left).
  external,
}

enum TransferRequestStatus { pending, approved, rejected }

extension TransferRequestStatusX on TransferRequestStatus {
  static TransferRequestStatus parse(String? raw) {
    return TransferRequestStatus.values.firstWhere(
      (e) => e.name == (raw ?? '').trim().toLowerCase(),
      orElse: () => TransferRequestStatus.pending,
    );
  }

  int get rank => switch (this) {
        TransferRequestStatus.pending => 0,
        TransferRequestStatus.approved => 1,
        TransferRequestStatus.rejected => 1,
      };
}

/// Destination subtype for an internal transfer.
enum InternalTransferTarget { section, grade, campus }

/// Outcome of an approved external transfer.
enum ExternalTransferOutcome { transferred, left }

/// A student transfer awaiting approval (registrar creates, academic/VP/owner
/// approves). Approval applies the placement or lifecycle change immediately.
class TransferRequest {
  TransferRequest({
    required this.id,
    required this.kind,
    required this.studentId,
    required this.studentName,
    required this.fromGrade,
    required this.fromClassName,
    required this.fromCampus,
    required this.reason,
    required this.requestedBy,
    required this.requestedByName,
    required this.createdAt,
    this.toGrade,
    this.toClassName,
    this.toCampus,
    this.internalTarget,
    this.externalOutcome,
    this.status = TransferRequestStatus.pending,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.schoolId,
  });

  final String id;
  final TransferRequestKind kind;
  final String studentId;
  final String studentName;
  final String fromGrade;
  final String fromClassName;
  final String fromCampus;
  final String? toGrade;
  final String? toClassName;
  final String? toCampus;
  final InternalTransferTarget? internalTarget;
  final ExternalTransferOutcome? externalOutcome;
  final String reason;
  final String requestedBy;
  final String requestedByName;
  final DateTime createdAt;

  TransferRequestStatus status;
  String? approvedBy;
  String? approvedByName;
  DateTime? approvedAt;
  String? rejectionReason;
  final String? schoolId;

  String get summary {
    if (kind == TransferRequestKind.external) {
      final outcome = externalOutcome ?? ExternalTransferOutcome.transferred;
      return '$studentName: leave school (${outcome.name})';
    }
    return '$studentName: $fromClassName → ${toClassName ?? toCampus ?? '?'}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.name,
        'studentId': studentId,
        'studentName': studentName,
        'fromGrade': fromGrade,
        'fromClassName': fromClassName,
        'fromCampus': fromCampus,
        if (toGrade != null) 'toGrade': toGrade,
        if (toClassName != null) 'toClassName': toClassName,
        if (toCampus != null) 'toCampus': toCampus,
        if (internalTarget != null) 'internalTarget': internalTarget!.name,
        if (externalOutcome != null) 'externalOutcome': externalOutcome!.name,
        'reason': reason,
        'requestedBy': requestedBy,
        'requestedByName': requestedByName,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedByName != null) 'approvedByName': approvedByName,
        if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (schoolId != null) 'schoolId': schoolId,
      };

  static TransferRequest fromMap(Map<String, dynamic> map) {
    return TransferRequest(
      id: map['id'] as String,
      kind: TransferRequestKind.values.firstWhere(
        (e) => e.name == map['kind'],
        orElse: () => TransferRequestKind.internal,
      ),
      studentId: (map['studentId'] as String? ?? '').toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      fromGrade: map['fromGrade'] as String? ?? '',
      fromClassName: map['fromClassName'] as String? ?? '',
      fromCampus: map['fromCampus'] as String? ?? '',
      toGrade: map['toGrade'] as String?,
      toClassName: map['toClassName'] as String?,
      toCampus: map['toCampus'] as String?,
      internalTarget: map['internalTarget'] == null
          ? null
          : InternalTransferTarget.values.firstWhere(
              (e) => e.name == map['internalTarget'],
              orElse: () => InternalTransferTarget.section,
            ),
      externalOutcome: map['externalOutcome'] == null
          ? null
          : ExternalTransferOutcome.values.firstWhere(
              (e) => e.name == map['externalOutcome'],
              orElse: () => ExternalTransferOutcome.transferred,
            ),
      reason: map['reason'] as String? ?? '',
      requestedBy: (map['requestedBy'] as String? ?? '').toLowerCase(),
      requestedByName: map['requestedByName'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: TransferRequestStatusX.parse(map['status'] as String?),
      approvedBy: map['approvedBy'] as String?,
      approvedByName: map['approvedByName'] as String?,
      approvedAt: map['approvedAt'] != null
          ? DateTime.tryParse(map['approvedAt'] as String)
          : null,
      rejectionReason: map['rejectionReason'] as String?,
      schoolId: map['schoolId'] as String?,
    );
  }
}

/// UI gating for the transfer / promotion workflows.
abstract final class TransferPermissions {
  static bool get _isAdmin =>
      AuthService.currentUser?.roleKey == AuthService.roleAdmin;

  static bool get canCreateTransfers =>
      _isAdmin || AuthService.hasPermission(SchoolPermissions.createTransfers);

  /// Internal transfers: Academic Admin, VP, Full Access, Owner.
  static bool get canApproveInternalTransfers =>
      _isAdmin || AuthService.hasPermission(SchoolPermissions.approveTransfers);

  /// External leave/transfer-out: school owner only (per product spec).
  static bool get canApproveExternalTransfers => _isAdmin;

  static bool get canPromoteStudents =>
      _isAdmin || AuthService.hasPermission(SchoolPermissions.promoteStudents);

  static bool get canSeeTransfers =>
      canCreateTransfers ||
      canApproveInternalTransfers ||
      canPromoteStudents ||
      AuthService.hasPermission(SchoolPermissions.viewAllDepartments) ||
      AuthService.hasPermission(SchoolPermissions.viewStudents);
}

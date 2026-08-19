import 'package:flutter/foundation.dart';

import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/transfer_persistence_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transfer_service.dart';

/// Student transfer & promotion workflow engine.
///
/// Internal: registrar creates → academic / VP / owner approves → placement
/// applied via [TransferService].
/// External: registrar creates → owner approves → lifecycle set to
/// transferred / left.
/// Promotion: registrar (promote_students) moves a whole class up a grade
/// (or marks the final grade as graduated) in one shot.
class TransferWorkflowService extends ChangeNotifier {
  TransferWorkflowService._();
  static final instance = TransferWorkflowService._();

  final List<TransferRequest> _requests = [];

  String? get _schoolId => AuthService.activeSchoolId;
  String get _username =>
      (AuthService.currentUser?.username ?? '').toLowerCase();
  String get _displayName {
    final user = AuthService.currentUser;
    final name = (user?.fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    return user?.username ?? '';
  }

  List<TransferRequest> requestsSnapshot() => List.unmodifiable(_requests);

  List<TransferRequest> requestsForSchool() {
    final sid = _schoolId;
    return _requests
        .where((r) => sid == null || r.schoolId == null || r.schoolId == sid)
        .toList();
  }

  int get pendingCount => requestsForSchool()
      .where((r) => r.status == TransferRequestStatus.pending)
      .length;

  void applyPersistedData({required List<TransferRequest> requests}) {
    _requests
      ..clear()
      ..addAll(requests);
    notifyListeners();
  }

  String _newId(String prefix) {
    final t = DateTime.now().millisecondsSinceEpoch;
    final salt = (identityHashCode(this) ^ t) & 0xFFFF;
    return '$prefix-$t-${salt.toRadixString(16)}';
  }

  bool get _selfApprovalAllowed {
    if (AuthService.currentUser?.roleKey == AuthService.roleAdmin) return true;
    final sid = _schoolId;
    if (sid == null) return false;
    return SchoolRegistryService.instance.lookup(sid)?.allowSelfApproval ??
        false;
  }

  Future<void> _persist() async {
    await TransferPersistenceService.instance.saveFromService();
    notifyListeners();
  }

  Future<void> _audit(
    String action, {
    String? detail,
    String? entityId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    await PlatformAuditLogService.instance.log(
      action: action,
      schoolId: _schoolId,
      detail: detail,
    );
    await SchoolAuditLogService.instance.log(
      action: action,
      schoolId: _schoolId,
      entityType: 'transfer',
      entityId: entityId,
      detail: detail,
      before: before,
      after: after,
    );
  }

  // ————— Internal transfers —————

  Future<String?> createInternalTransfer({
    required String studentId,
    required String toGrade,
    required String toSection,
    InternalTransferTarget target = InternalTransferTarget.section,
    String reason = '',
  }) async {
    if (!TransferPermissions.canCreateTransfers) return 'not_allowed';
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return 'student_not_found';
    final section = toSection.trim();
    if (section.isEmpty) return 'section_required';
    final toClass =
        StudentRegistryService.buildClassName(toGrade.trim(), section);
    if (toClass == student.className && toGrade.trim() == student.grade) {
      return 'no_change';
    }

    final request = TransferRequest(
      id: _newId('tr'),
      kind: TransferRequestKind.internal,
      studentId: student.studentId,
      studentName: student.fullName,
      fromGrade: student.grade,
      fromClassName: student.className,
      fromCampus: student.campus,
      toGrade: toGrade.trim(),
      toClassName: toClass,
      toCampus: student.campus,
      internalTarget: target,
      reason: reason.trim(),
      requestedBy: _username,
      requestedByName: _displayName,
      createdAt: DateTime.now(),
      schoolId: _schoolId ?? student.schoolId,
    );
    _requests.insert(0, request);
    await _audit(
      'transfer_request_created',
      detail: request.summary,
      entityId: request.id,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  Future<String?> createCampusTransfer({
    required String studentId,
    required String toCampus,
    String reason = '',
  }) async {
    if (!TransferPermissions.canCreateTransfers) return 'not_allowed';
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return 'student_not_found';
    final campus = toCampus.trim();
    if (campus.isEmpty) return 'campus_required';
    if (campus == student.campus) return 'no_change';

    final request = TransferRequest(
      id: _newId('tr'),
      kind: TransferRequestKind.internal,
      studentId: student.studentId,
      studentName: student.fullName,
      fromGrade: student.grade,
      fromClassName: student.className,
      fromCampus: student.campus,
      toGrade: student.grade,
      toClassName: student.className,
      toCampus: campus,
      internalTarget: InternalTransferTarget.campus,
      reason: reason.trim(),
      requestedBy: _username,
      requestedByName: _displayName,
      createdAt: DateTime.now(),
      schoolId: _schoolId ?? student.schoolId,
    );
    _requests.insert(0, request);
    await _audit(
      'transfer_request_created',
      detail: request.summary,
      entityId: request.id,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  // ————— External transfers —————

  Future<String?> createExternalTransfer({
    required String studentId,
    required ExternalTransferOutcome outcome,
    String reason = '',
  }) async {
    if (!TransferPermissions.canCreateTransfers) return 'not_allowed';
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return 'student_not_found';
    if (reason.trim().isEmpty) return 'reason_required';

    final request = TransferRequest(
      id: _newId('tr'),
      kind: TransferRequestKind.external,
      studentId: student.studentId,
      studentName: student.fullName,
      fromGrade: student.grade,
      fromClassName: student.className,
      fromCampus: student.campus,
      externalOutcome: outcome,
      reason: reason.trim(),
      requestedBy: _username,
      requestedByName: _displayName,
      createdAt: DateTime.now(),
      schoolId: _schoolId ?? student.schoolId,
    );
    _requests.insert(0, request);
    await _audit(
      'external_transfer_request_created',
      detail: request.summary,
      entityId: request.id,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  // ————— Decisions —————

  Future<String?> approveTransfer(String id) async {
    final request = _find(id);
    if (request == null) return 'not_found';
    if (request.status != TransferRequestStatus.pending) return 'not_pending';

    if (request.kind == TransferRequestKind.external) {
      if (!TransferPermissions.canApproveExternalTransfers) {
        return 'not_allowed';
      }
    } else {
      if (!TransferPermissions.canApproveInternalTransfers) {
        return 'not_allowed';
      }
    }
    if (request.requestedBy == _username && !_selfApprovalAllowed) {
      return 'self_approval_blocked';
    }

    final applyError = await _apply(request);
    if (applyError != null) return applyError;

    final before = request.toMap();
    request.status = TransferRequestStatus.approved;
    request.approvedBy = _username;
    request.approvedByName = _displayName;
    request.approvedAt = DateTime.now();
    await _audit(
      'transfer_request_approved',
      detail: request.summary,
      entityId: request.id,
      before: before,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  Future<String?> rejectTransfer(String id, String reason) async {
    final request = _find(id);
    if (request == null) return 'not_found';
    if (request.status != TransferRequestStatus.pending) return 'not_pending';

    if (request.kind == TransferRequestKind.external) {
      if (!TransferPermissions.canApproveExternalTransfers) {
        return 'not_allowed';
      }
    } else {
      if (!TransferPermissions.canApproveInternalTransfers) {
        return 'not_allowed';
      }
    }
    if (request.requestedBy == _username && !_selfApprovalAllowed) {
      return 'self_approval_blocked';
    }
    if (reason.trim().isEmpty) return 'reason_required';

    final before = request.toMap();
    request.status = TransferRequestStatus.rejected;
    request.approvedBy = _username;
    request.approvedByName = _displayName;
    request.approvedAt = DateTime.now();
    request.rejectionReason = reason.trim();
    await _audit(
      'transfer_request_rejected',
      detail: request.id,
      entityId: request.id,
      before: before,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  Future<String?> _apply(TransferRequest request) async {
    if (request.kind == TransferRequestKind.external) {
      final status = request.externalOutcome == ExternalTransferOutcome.left
          ? StudentLifecycleStatus.left
          : StudentLifecycleStatus.transferred;
      final ok = StudentRegistryService.instance
          .setLifecycleStatus(request.studentId, status);
      return ok ? null : 'apply_failed';
    }

    if (request.internalTarget == InternalTransferTarget.campus) {
      final campus = (request.toCampus ?? '').trim();
      if (campus.isEmpty) return 'campus_required';
      final ok = TransferService.instance.transferStudentCampus(
        studentId: request.studentId,
        toCampus: campus,
      );
      return ok ? null : 'apply_failed';
    }

    final grade = (request.toGrade ?? '').trim();
    final className = (request.toClassName ?? '').trim();
    if (grade.isEmpty || className.isEmpty) return 'destination_required';
    // Section is whatever follows the grade prefix ("Grade 5A" → "A").
    final section = className.toLowerCase().startsWith(grade.toLowerCase())
        ? className.substring(grade.length).trim()
        : (className.contains(' ')
            ? className.split(' ').last
            : className);
    if (section.isEmpty) return 'destination_required';
    final ok = await TransferService.instance.transferStudentToSection(
      studentId: request.studentId,
      toGrade: grade,
      toSection: section,
    );
    return ok ? null : 'apply_failed';
  }

  // ————— Promotion —————

  /// Promote every active student in [fromClassName] to [toGrade]/[toSection].
  /// Pass [graduate] to mark them graduated instead (final-year roll-off).
  Future<({int count, String? error})> promoteClass({
    required String fromClassName,
    String? toGrade,
    String? toSection,
    bool graduate = false,
    String? newAcademicYear,
  }) async {
    if (!TransferPermissions.canPromoteStudents) {
      return (count: 0, error: 'not_allowed');
    }
    final students = StudentRegistryService.instance.studentsForClass(
      fromClassName,
      schoolId: _schoolId,
    );
    if (students.isEmpty) return (count: 0, error: 'no_students');

    if (graduate) {
      var count = 0;
      for (final student in students) {
        if (StudentRegistryService.instance.setLifecycleStatus(
          student.studentId,
          StudentLifecycleStatus.graduated,
        )) {
          count++;
        }
      }
      await _audit(
        'class_graduated',
        detail: '$fromClassName → graduated ($count)',
        entityId: fromClassName,
      );
      return (count: count, error: null);
    }

    final grade = (toGrade ?? '').trim();
    final section = (toSection ?? '').trim();
    if (grade.isEmpty || section.isEmpty) {
      return (count: 0, error: 'destination_required');
    }

    var count = 0;
    for (final student in students) {
      final ok = await TransferService.instance.transferStudentToSection(
        studentId: student.studentId,
        toGrade: grade,
        toSection: section,
      );
      if (ok) {
        count++;
        if (newAcademicYear != null && newAcademicYear.trim().isNotEmpty) {
          final updated =
              StudentRegistryService.instance.lookupById(student.studentId);
          if (updated != null) {
            StudentRegistryService.instance.updateStudent(
              updated.copyWith(academicYear: newAcademicYear.trim()),
            );
          }
        }
      }
    }
    await _audit(
      'class_promoted',
      detail:
          '$fromClassName → ${StudentRegistryService.buildClassName(grade, section)} ($count)',
      entityId: fromClassName,
    );
    notifyListeners();
    return (count: count, error: null);
  }

  /// Suggest the next grade label given the school's ordered grade list.
  static String? nextGradeLabel(String currentGrade, List<String> grades) {
    final idx = grades.indexWhere(
      (g) => g.trim().toLowerCase() == currentGrade.trim().toLowerCase(),
    );
    if (idx < 0 || idx >= grades.length - 1) return null;
    return grades[idx + 1];
  }

  TransferRequest? _find(String id) {
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}

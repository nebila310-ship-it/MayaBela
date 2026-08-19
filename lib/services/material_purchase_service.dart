import 'package:flutter/foundation.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/material_purchase_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/material_access_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/material_purchase_persistence_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Student request → parent approval → pay → admin unlock.
class MaterialPurchaseService extends ChangeNotifier {
  MaterialPurchaseService._();
  static final instance = MaterialPurchaseService._();

  final List<MaterialPurchaseRequest> _requests = [];

  List<MaterialPurchaseRequest> snapshot() => List.unmodifiable(_requests);

  void applyPersisted(List<MaterialPurchaseRequest> requests) {
    _requests
      ..clear()
      ..addAll(requests);
    notifyListeners();
  }

  Future<void> load() =>
      MaterialPurchasePersistenceService.instance.loadIntoService();

  Future<void> _persist() async {
    await MaterialPurchasePersistenceService.instance.saveFromService();
    notifyListeners();
  }

  String _newId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    final salt = (identityHashCode(this) ^ t) & 0xFFFF;
    return 'mpr-$t-${salt.toRadixString(16)}';
  }

  MaterialPurchaseRequest? findOpenFor({
    required String materialId,
    required String studentId,
  }) {
    final mid = materialId.trim();
    final sid = studentId.trim().toUpperCase();
    for (final r in _requests) {
      if (r.materialId == mid && r.studentId == sid && r.isOpen) return r;
    }
    return null;
  }

  List<MaterialPurchaseRequest> forParent({String? parentUsername}) {
    final me = (parentUsername ?? AuthService.currentUser?.username ?? '')
        .trim()
        .toLowerCase();
    final linked = AuthService.activeLinkedStudentIds()
        .map((e) => e.toUpperCase())
        .toSet();
    return _requests.where((r) {
      if (linked.contains(r.studentId)) return true;
      if (me.isNotEmpty &&
          (r.parentUsername ?? '').trim().toLowerCase() == me) {
        return true;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<MaterialPurchaseRequest> pendingParentApprovals() => forParent()
      .where((r) => r.status == MaterialPurchaseStatus.pendingParentApproval)
      .toList();

  List<MaterialPurchaseRequest> awaitingAdminConfirm() => _requests
      .where((r) => r.status == MaterialPurchaseStatus.paymentSubmitted)
      .toList()
    ..sort((a, b) =>
        (b.paymentSubmittedAt ?? b.createdAt)
            .compareTo(a.paymentSubmittedAt ?? a.createdAt));

  List<MaterialPurchaseRequest> forSchool() {
    final sid = (AuthService.activeSchoolId ?? '').trim().toUpperCase();
    return _requests
        .where((r) => sid.isEmpty || r.schoolId == sid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String? _parentUsernameForStudent(String studentId) {
    EnrollmentService.instance.ensureSeeded();
    final sid = studentId.trim().toUpperCase();
    final links = EnrollmentService.instance
        .allLinksSnapshot()
        .where((l) => l.studentId.toUpperCase() == sid)
        .toList();
    for (final link in links) {
      if (link.status == ParentLinkStatus.approved) {
        return link.parentUsername;
      }
    }
    return links.isEmpty ? null : links.first.parentUsername;
  }

  void _notify({
    required String title,
    required String body,
    required String fromRole,
    required String recipientRole,
    String? targetStudentId,
    String? recipientUsername,
  }) {
    NotificationService.instance.push(
      title: title,
      body: body,
      type: NotificationType.materialPurchase,
      fromRole: fromRole,
      fromName: AuthService.currentUser?.fullName ?? fromRole,
      recipientRole: recipientRole,
      showOnMessagesBadge: false,
      targetStudentId: targetStudentId,
      recipientUsername: recipientUsername,
    );
  }

  /// Student asks parent to unlock a paid book.
  Future<String?> requestByStudent({
    required LearningMaterialItem material,
    required String studentId,
  }) async {
    if (AuthService.currentUser?.roleKey != AuthService.roleStudent) {
      return 'not_allowed';
    }
    if (material.isFree) return 'already_free';
    final sid = studentId.trim().toUpperCase();
    if (sid.isEmpty) return 'student_required';
    if (MaterialAccessService.instance
        .hasAccess(material, studentIds: [sid])) {
      return 'already_unlocked';
    }
    if (findOpenFor(materialId: material.id, studentId: sid) != null) {
      return 'already_pending';
    }

    final student = StudentRegistryService.instance.lookupById(sid);
    final parentUsername = _parentUsernameForStudent(sid);
    final request = MaterialPurchaseRequest(
      id: _newId(),
      materialId: material.id,
      materialTitle: '${material.bookName} · ${material.materialName}',
      studentId: sid,
      studentName: student?.fullName ??
          AuthService.currentUser?.fullName ??
          sid,
      schoolId: (AuthService.activeSchoolId ?? student?.schoolId ?? '')
          .trim()
          .toUpperCase(),
      priceEtb: material.price ?? 0,
      status: MaterialPurchaseStatus.pendingParentApproval,
      source: MaterialPurchaseSource.studentRequest,
      createdAt: DateTime.now(),
      className: material.className,
      parentUsername: parentUsername,
      parentName: student?.primaryParentName,
    );
    _requests.insert(0, request);
    _notify(
      title: 'Book unlock request',
      body:
          '${request.studentName} asked to unlock “${material.bookName}” (${request.priceEtb.toStringAsFixed(0)} ETB).',
      fromRole: AuthService.roleStudent,
      recipientRole: AuthService.roleParent,
      targetStudentId: sid,
      recipientUsername: parentUsername,
    );
    await _persist();
    return null;
  }

  /// Parent buys/unlocks without a student request.
  Future<String?> startParentDirectPurchase({
    required LearningMaterialItem material,
    required String studentId,
  }) async {
    if (AuthService.currentUser?.roleKey != AuthService.roleParent &&
        AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return 'not_allowed';
    }
    if (material.isFree) return 'already_free';
    final sid = studentId.trim().toUpperCase();
    if (sid.isEmpty) return 'student_required';
    if (MaterialAccessService.instance
        .hasAccess(material, studentIds: [sid])) {
      return 'already_unlocked';
    }
    final existing = findOpenFor(materialId: material.id, studentId: sid);
    if (existing != null) {
      if (existing.status == MaterialPurchaseStatus.pendingParentApproval) {
        existing.status = MaterialPurchaseStatus.awaitingPayment;
        existing.parentApprovedAt = DateTime.now();
        existing.parentUsername = AuthService.currentUser?.username;
        existing.parentName = AuthService.currentUser?.fullName;
        await _persist();
      }
      return null;
    }

    final student = StudentRegistryService.instance.lookupById(sid);
    final request = MaterialPurchaseRequest(
      id: _newId(),
      materialId: material.id,
      materialTitle: '${material.bookName} · ${material.materialName}',
      studentId: sid,
      studentName: student?.fullName ?? sid,
      schoolId: (AuthService.activeSchoolId ?? student?.schoolId ?? '')
          .trim()
          .toUpperCase(),
      priceEtb: material.price ?? 0,
      status: MaterialPurchaseStatus.awaitingPayment,
      source: MaterialPurchaseSource.parentDirect,
      createdAt: DateTime.now(),
      className: material.className,
      parentUsername: AuthService.currentUser?.username,
      parentName: AuthService.currentUser?.fullName,
      parentApprovedAt: DateTime.now(),
    );
    _requests.insert(0, request);
    await _persist();
    return null;
  }

  Future<String?> approveByParent(String requestId) async {
    final req = _find(requestId);
    if (req == null) return 'not_found';
    if (req.status != MaterialPurchaseStatus.pendingParentApproval) {
      return 'not_pending';
    }
    final linked = AuthService.activeLinkedStudentIds()
        .map((e) => e.toUpperCase())
        .toSet();
    if (!linked.contains(req.studentId) &&
        AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return 'not_allowed';
    }
    req.status = MaterialPurchaseStatus.awaitingPayment;
    req.parentApprovedAt = DateTime.now();
    req.parentUsername = AuthService.currentUser?.username;
    req.parentName = AuthService.currentUser?.fullName;
    await _persist();
    return null;
  }

  Future<String?> rejectByParent(String requestId, {String? reason}) async {
    final req = _find(requestId);
    if (req == null) return 'not_found';
    if (req.status != MaterialPurchaseStatus.pendingParentApproval) {
      return 'not_pending';
    }
    req.status = MaterialPurchaseStatus.rejected;
    req.rejectionReason = reason?.trim().isEmpty ?? true
        ? 'Rejected by parent'
        : reason!.trim();
    await _persist();
    return null;
  }

  Future<String?> markPaymentSubmitted(
    String requestId, {
    MaterialPaymentMethod method = MaterialPaymentMethod.other,
    String? note,
  }) async {
    final req = _find(requestId);
    if (req == null) return 'not_found';
    if (req.status != MaterialPurchaseStatus.awaitingPayment &&
        req.status != MaterialPurchaseStatus.paymentSubmitted) {
      return 'not_awaiting_payment';
    }
    req.status = MaterialPurchaseStatus.paymentSubmitted;
    req.paymentMethod = method;
    req.receiptNote = note;
    req.paymentSubmittedAt = DateTime.now();
    _notify(
      title: 'Book payment submitted',
      body:
          '${req.studentName} · ${req.materialTitle} · ${req.priceEtb.toStringAsFixed(0)} ETB — confirm unlock.',
      fromRole: AuthService.currentUser?.roleKey ?? AuthService.roleParent,
      recipientRole: AuthService.roleAdmin,
      targetStudentId: req.studentId,
    );
    await _persist();
    return null;
  }

  Future<String?> confirmPaymentByAdmin(String requestId) async {
    final role = AuthService.currentUser?.roleKey;
    if (role != AuthService.roleAdmin && role != AuthService.roleTeacher) {
      return 'not_allowed';
    }
    final req = _find(requestId);
    if (req == null) return 'not_found';
    if (req.status != MaterialPurchaseStatus.paymentSubmitted &&
        req.status != MaterialPurchaseStatus.awaitingPayment) {
      return 'not_payable';
    }

    await MaterialAccessService.instance.grant(
      materialId: req.materialId,
      studentId: req.studentId,
      grantedBy: AuthService.currentUser?.username ?? 'admin',
    );

    req.status = MaterialPurchaseStatus.approved;
    req.adminConfirmedAt = DateTime.now();
    req.adminUsername = AuthService.currentUser?.username;
    _notify(
      title: 'Unlocked',
      body: 'Book released — “${req.materialTitle}” is available for ${req.studentName}.',
      fromRole: role ?? AuthService.roleAdmin,
      recipientRole: AuthService.roleParent,
      targetStudentId: req.studentId,
      recipientUsername: req.parentUsername,
    );
    _notify(
      title: 'Unlocked',
      body: 'Book released — “${req.materialTitle}” is now available.',
      fromRole: role ?? AuthService.roleAdmin,
      recipientRole: AuthService.roleStudent,
      targetStudentId: req.studentId,
    );
    await _persist();
    return null;
  }

  Future<String?> rejectByAdmin(String requestId, {String? reason}) async {
    final role = AuthService.currentUser?.roleKey;
    if (role != AuthService.roleAdmin && role != AuthService.roleTeacher) {
      return 'not_allowed';
    }
    final req = _find(requestId);
    if (req == null) return 'not_found';
    req.status = MaterialPurchaseStatus.rejected;
    req.rejectionReason = reason?.trim().isEmpty ?? true
        ? 'Rejected by school'
        : reason!.trim();
    await _persist();
    return null;
  }

  MaterialPurchaseRequest? _find(String id) {
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}

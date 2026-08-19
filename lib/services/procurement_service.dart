import 'package:flutter/foundation.dart';

import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/models/procurement_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/persistence/procurement_persistence_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Procurement & store workflow engine.
///
/// Purchase flow:  create (procurement) -> approve/reject (VP / owner)
///                 -> receive (storekeeper / procurement) which stocks the
///                 inventory (idempotent: receiving flips the status, and
///                 backwards transitions are rejected here and in SQL).
/// Issue flow:     create (storekeeper / departments) -> approve (procurement
///                 / VP / owner) -> issue (storekeeper) which records the
///                 stock-out.
///
/// Self-approval (approving your own request) is blocked unless the school
/// owner enabled the allowSelfApproval setting; the SQL write-guard enforces
/// the same rule server-side, so a tampered client cannot bypass it.
class ProcurementService extends ChangeNotifier {
  ProcurementService._();
  static final instance = ProcurementService._();

  final List<PurchaseRequest> _purchases = [];
  final List<IssueRequest> _issues = [];

  String? get _schoolId => AuthService.activeSchoolId;
  String get _username =>
      (AuthService.currentUser?.username ?? '').toLowerCase();
  String get _displayName {
    final user = AuthService.currentUser;
    final name = (user?.fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    return user?.username ?? '';
  }

  List<PurchaseRequest> purchasesSnapshot() => List.unmodifiable(_purchases);
  List<IssueRequest> issuesSnapshot() => List.unmodifiable(_issues);

  List<PurchaseRequest> purchasesForSchool() {
    final sid = _schoolId;
    return _purchases
        .where((r) => sid == null || r.schoolId == null || r.schoolId == sid)
        .toList();
  }

  List<IssueRequest> issuesForSchool() {
    final sid = _schoolId;
    return _issues
        .where((r) => sid == null || r.schoolId == null || r.schoolId == sid)
        .toList();
  }

  int get pendingPurchaseCount => purchasesForSchool()
      .where((r) => r.status == ApprovalStatus.pending)
      .length;

  int get pendingIssueCount =>
      issuesForSchool().where((r) => r.status == ApprovalStatus.pending).length;

  void applyPersistedData({
    required List<PurchaseRequest> purchases,
    required List<IssueRequest> issues,
  }) {
    _purchases
      ..clear()
      ..addAll(purchases);
    _issues
      ..clear()
      ..addAll(issues);
    notifyListeners();
  }

  /// Unique across devices (multiple staff create requests concurrently).
  String _newId(String prefix) {
    final t = DateTime.now().millisecondsSinceEpoch;
    final salt = (identityHashCode(this) ^ t) & 0xFFFF;
    return '$prefix-$t-${salt.toRadixString(16)}';
  }

  /// The owner bypasses the self-approval rule (they control the setting);
  /// staff need allowSelfApproval enabled to decide their own requests.
  bool get _selfApprovalAllowed {
    if (AuthService.currentUser?.roleKey == AuthService.roleAdmin) return true;
    final sid = _schoolId;
    if (sid == null) return false;
    return SchoolRegistryService.instance.lookup(sid)?.allowSelfApproval ??
        false;
  }

  Future<void> _persist() async {
    await ProcurementPersistenceService.instance.saveFromService();
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
      entityType: 'procurement',
      entityId: entityId,
      detail: detail,
      before: before,
      after: after,
    );
  }

  // ————— Purchase requests —————

  Future<String?> createPurchaseRequest({
    required List<PurchaseRequestLine> lines,
    required String reason,
    String department = '',
  }) async {
    if (!ProcurementPermissions.canCreatePurchaseRequests) {
      return 'not_allowed';
    }
    final cleanLines = lines
        .where((l) => l.name.trim().isNotEmpty && l.quantity > 0)
        .toList();
    if (cleanLines.isEmpty) return 'no_items';

    final request = PurchaseRequest(
      id: _newId('pr'),
      lines: cleanLines,
      reason: reason.trim(),
      requestedBy: _username,
      requestedByName: _displayName,
      department: department.trim(),
      createdAt: DateTime.now(),
      schoolId: _schoolId,
    );
    _purchases.insert(0, request);
    await _audit(
      'purchase_request_created',
      detail: '${request.id} ${request.linesSummary}',
      entityId: request.id,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  Future<String?> approvePurchaseRequest(String id) =>
      _decidePurchase(id, approve: true);

  Future<String?> rejectPurchaseRequest(String id, String reason) =>
      _decidePurchase(id, approve: false, rejectionReason: reason);

  Future<String?> _decidePurchase(
    String id, {
    required bool approve,
    String? rejectionReason,
  }) async {
    if (!ProcurementPermissions.canApprovePurchaseRequests) {
      return 'not_allowed';
    }
    final request = _findPurchase(id);
    if (request == null) return 'not_found';
    if (request.status != ApprovalStatus.pending) return 'not_pending';
    if (request.requestedBy == _username && !_selfApprovalAllowed) {
      return 'self_approval_blocked';
    }
    if (!approve && (rejectionReason ?? '').trim().isEmpty) {
      return 'reason_required';
    }

    final before = request.toMap();
    request.status =
        approve ? ApprovalStatus.approved : ApprovalStatus.rejected;
    request.approvedBy = _username;
    request.approvedByName = _displayName;
    request.approvedAt = DateTime.now();
    request.rejectionReason = approve ? null : rejectionReason!.trim();
    await _audit(
      approve ? 'purchase_request_approved' : 'purchase_request_rejected',
      detail: request.id,
      entityId: request.id,
      before: before,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  /// Records delivery of an approved purchase: every line is stocked into
  /// the inventory (existing items get a stock-in movement; unknown items
  /// are added to the catalog). Flipping the status makes this idempotent —
  /// a second receive attempt fails with `not_approved`.
  Future<String?> receivePurchaseRequest(
    String id, {
    String? supplier,
    String? invoiceNumber,
  }) async {
    if (!ProcurementPermissions.canReceivePurchases) return 'not_allowed';
    final request = _findPurchase(id);
    if (request == null) return 'not_found';
    if (request.status != ApprovalStatus.approved) return 'not_approved';

    final inventory = InventoryService.instance;
    for (final line in request.lines) {
      final existing = _findItemByName(inventory, line.name);
      if (existing != null) {
        final error = await inventory.recordStockIn(
          itemId: existing.id,
          quantity: line.quantity,
          supplierOrDonor: supplier ?? request.supplier,
          invoiceNumber: invoiceNumber,
          receivedBy: _displayName,
          notes: 'Purchase request ${request.id}',
        );
        if (error != null) return 'stock_in_failed';
      } else {
        await inventory.addItem(
          name: line.name,
          category: InventoryItemCategory.stationery,
          description: 'Added from purchase request ${request.id}',
          quantityAvailable: line.quantity,
          unit: line.unit,
          minimumStockLevel: 5,
          storageLocation: 'Main Store',
          purchasePrice: line.estimatedUnitPrice,
          supplier: supplier ?? request.supplier ?? '',
        );
      }
    }

    final before = request.toMap();
    request.status = ApprovalStatus.received;
    request.receivedBy = _username;
    request.receivedAt = DateTime.now();
    request.supplier = supplier ?? request.supplier;
    request.invoiceNumber = invoiceNumber ?? request.invoiceNumber;
    await _audit(
      'purchase_request_received',
      detail: request.id,
      entityId: request.id,
      before: before,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  // ————— Issue requests —————

  Future<String?> createIssueRequest({
    required String itemId,
    required int quantity,
    required String purpose,
    String department = '',
  }) async {
    if (!ProcurementPermissions.canCreateIssueRequests) return 'not_allowed';
    if (quantity <= 0) return 'invalid_quantity';
    final item = InventoryService.instance.lookupItem(itemId);
    if (item == null) return 'item_not_found';

    final request = IssueRequest(
      id: _newId('ir'),
      itemId: item.id,
      itemName: item.name,
      quantity: quantity,
      purpose: purpose.trim(),
      requestedBy: _username,
      requestedByName: _displayName,
      department: department.trim(),
      createdAt: DateTime.now(),
      schoolId: _schoolId,
    );
    _issues.insert(0, request);
    await _audit(
      'issue_request_created',
      detail: '${request.id} ${item.name} x$quantity',
      entityId: request.id,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  Future<String?> approveIssueRequest(String id) =>
      _decideIssue(id, approve: true);

  Future<String?> rejectIssueRequest(String id, String reason) =>
      _decideIssue(id, approve: false, rejectionReason: reason);

  Future<String?> _decideIssue(
    String id, {
    required bool approve,
    String? rejectionReason,
  }) async {
    if (!ProcurementPermissions.canApproveIssueRequests) return 'not_allowed';
    final request = _findIssue(id);
    if (request == null) return 'not_found';
    if (request.status != ApprovalStatus.pending) return 'not_pending';
    if (request.requestedBy == _username && !_selfApprovalAllowed) {
      return 'self_approval_blocked';
    }
    if (!approve && (rejectionReason ?? '').trim().isEmpty) {
      return 'reason_required';
    }

    final before = request.toMap();
    request.status =
        approve ? ApprovalStatus.approved : ApprovalStatus.rejected;
    request.approvedBy = _username;
    request.approvedByName = _displayName;
    request.approvedAt = DateTime.now();
    request.rejectionReason = approve ? null : rejectionReason!.trim();
    await _audit(
      approve ? 'issue_request_approved' : 'issue_request_rejected',
      detail: request.id,
      entityId: request.id,
      before: before,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  /// Storekeeper hands the goods out: records the stock-out movement and
  /// closes the request. Idempotent via the status transition.
  Future<String?> fulfillIssueRequest(String id) async {
    if (!ProcurementPermissions.canIssueStock) return 'not_allowed';
    final request = _findIssue(id);
    if (request == null) return 'not_found';
    if (request.status != ApprovalStatus.approved) return 'not_approved';

    final error = await InventoryService.instance.recordStockOut(
      itemId: request.itemId,
      quantity: request.quantity,
      issuedTo: request.department.isNotEmpty
          ? request.department
          : request.requestedByName,
      issueTarget: InventoryIssueTarget.department,
      approvedBy: request.approvedByName ?? request.approvedBy,
      reason: request.purpose,
      notes: 'Issue request ${request.id}',
    );
    if (error != null) return 'insufficient_stock';

    final before = request.toMap();
    request.status = ApprovalStatus.issued;
    request.issuedBy = _username;
    request.issuedAt = DateTime.now();
    await _audit(
      'issue_request_fulfilled',
      detail: request.id,
      entityId: request.id,
      before: before,
      after: request.toMap(),
    );
    await _persist();
    return null;
  }

  // ————— Helpers —————

  PurchaseRequest? _findPurchase(String id) {
    try {
      return _purchases.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  IssueRequest? _findIssue(String id) {
    try {
      return _issues.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  InventoryItem? _findItemByName(InventoryService inventory, String name) {
    final key = name.trim().toLowerCase();
    for (final item in inventory.filteredItems()) {
      if (item.name.trim().toLowerCase() == key) return item;
    }
    return null;
  }
}

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

/// Shared lifecycle for approval-based requests.
///
/// Transitions only move forward (enforced both here and in the SQL
/// write-guard): pending -> approved | rejected, approved -> received /
/// issued. Stale sync echoes can never move a request backwards.
enum ApprovalStatus { pending, approved, rejected, received, issued }

extension ApprovalStatusX on ApprovalStatus {
  static ApprovalStatus parse(String? raw) {
    return ApprovalStatus.values.firstWhere(
      (e) => e.name == (raw ?? '').trim().toLowerCase(),
      orElse: () => ApprovalStatus.pending,
    );
  }

  bool get isTerminalForApproval => this != ApprovalStatus.pending;

  /// Ordering used to reject backwards transitions from stale devices.
  int get rank => switch (this) {
        ApprovalStatus.pending => 0,
        ApprovalStatus.approved => 1,
        ApprovalStatus.rejected => 1,
        ApprovalStatus.received => 2,
        ApprovalStatus.issued => 2,
      };
}

/// One line of a purchase request ("50 boxes of chalk").
class PurchaseRequestLine {
  const PurchaseRequestLine({
    required this.name,
    required this.quantity,
    this.unit = 'piece',
    this.estimatedUnitPrice = 0,
  });

  final String name;
  final int quantity;
  final String unit;
  final double estimatedUnitPrice;

  double get estimatedTotal => quantity * estimatedUnitPrice;

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'estimatedUnitPrice': estimatedUnitPrice,
      };

  static PurchaseRequestLine fromMap(Map<String, dynamic> map) {
    return PurchaseRequestLine(
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? 'piece',
      estimatedUnitPrice: (map['estimatedUnitPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A request to buy goods, raised by procurement and approved by the
/// owner / VP before money is spent. Receiving it stocks the inventory.
class PurchaseRequest {
  PurchaseRequest({
    required this.id,
    required this.lines,
    required this.reason,
    required this.requestedBy,
    required this.requestedByName,
    required this.createdAt,
    this.department = '',
    this.status = ApprovalStatus.pending,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.receivedBy,
    this.receivedAt,
    this.supplier,
    this.invoiceNumber,
    this.schoolId,
  });

  final String id;
  final List<PurchaseRequestLine> lines;
  final String reason;

  /// Login username (lowercase) — identity key for self-approval checks.
  final String requestedBy;
  final String requestedByName;
  final String department;
  final DateTime createdAt;

  ApprovalStatus status;
  String? approvedBy;
  String? approvedByName;
  DateTime? approvedAt;
  String? rejectionReason;
  String? receivedBy;
  DateTime? receivedAt;
  String? supplier;
  String? invoiceNumber;
  final String? schoolId;

  double get estimatedTotal =>
      lines.fold(0.0, (sum, line) => sum + line.estimatedTotal);

  String get linesSummary => lines
      .map((l) => '${l.quantity} ${l.unit} ${l.name}')
      .join(', ');

  Map<String, dynamic> toMap() => {
        'id': id,
        'lines': lines.map((l) => l.toMap()).toList(),
        'reason': reason,
        'requestedBy': requestedBy,
        'requestedByName': requestedByName,
        'department': department,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedByName != null) 'approvedByName': approvedByName,
        if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (receivedBy != null) 'receivedBy': receivedBy,
        if (receivedAt != null) 'receivedAt': receivedAt!.toIso8601String(),
        if (supplier != null) 'supplier': supplier,
        if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
        if (schoolId != null) 'schoolId': schoolId,
      };

  static PurchaseRequest fromMap(Map<String, dynamic> map) {
    return PurchaseRequest(
      id: map['id'] as String,
      lines: (map['lines'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => PurchaseRequestLine.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      reason: map['reason'] as String? ?? '',
      requestedBy: (map['requestedBy'] as String? ?? '').toLowerCase(),
      requestedByName: map['requestedByName'] as String? ?? '',
      department: map['department'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: ApprovalStatusX.parse(map['status'] as String?),
      approvedBy: map['approvedBy'] as String?,
      approvedByName: map['approvedByName'] as String?,
      approvedAt: map['approvedAt'] != null
          ? DateTime.tryParse(map['approvedAt'] as String)
          : null,
      rejectionReason: map['rejectionReason'] as String?,
      receivedBy: map['receivedBy'] as String?,
      receivedAt: map['receivedAt'] != null
          ? DateTime.tryParse(map['receivedAt'] as String)
          : null,
      supplier: map['supplier'] as String?,
      invoiceNumber: map['invoiceNumber'] as String?,
      schoolId: map['schoolId'] as String?,
    );
  }
}

/// A request to take stock out of the store for a department / purpose.
/// Approved by procurement (or VP / owner), fulfilled by the storekeeper.
class IssueRequest {
  IssueRequest({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.purpose,
    required this.requestedBy,
    required this.requestedByName,
    required this.createdAt,
    this.department = '',
    this.status = ApprovalStatus.pending,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.issuedBy,
    this.issuedAt,
    this.schoolId,
  });

  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final String purpose;
  final String requestedBy;
  final String requestedByName;
  final String department;
  final DateTime createdAt;

  ApprovalStatus status;
  String? approvedBy;
  String? approvedByName;
  DateTime? approvedAt;
  String? rejectionReason;
  String? issuedBy;
  DateTime? issuedAt;
  final String? schoolId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'purpose': purpose,
        'requestedBy': requestedBy,
        'requestedByName': requestedByName,
        'department': department,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedByName != null) 'approvedByName': approvedByName,
        if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (issuedBy != null) 'issuedBy': issuedBy,
        if (issuedAt != null) 'issuedAt': issuedAt!.toIso8601String(),
        if (schoolId != null) 'schoolId': schoolId,
      };

  static IssueRequest fromMap(Map<String, dynamic> map) {
    return IssueRequest(
      id: map['id'] as String,
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      purpose: map['purpose'] as String? ?? '',
      requestedBy: (map['requestedBy'] as String? ?? '').toLowerCase(),
      requestedByName: map['requestedByName'] as String? ?? '',
      department: map['department'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: ApprovalStatusX.parse(map['status'] as String?),
      approvedBy: map['approvedBy'] as String?,
      approvedByName: map['approvedByName'] as String?,
      approvedAt: map['approvedAt'] != null
          ? DateTime.tryParse(map['approvedAt'] as String)
          : null,
      rejectionReason: map['rejectionReason'] as String?,
      issuedBy: map['issuedBy'] as String?,
      issuedAt: map['issuedAt'] != null
          ? DateTime.tryParse(map['issuedAt'] as String)
          : null,
      schoolId: map['schoolId'] as String?,
    );
  }
}

/// UI gating for the procurement workflows (mirrors the SQL write-guard).
abstract final class ProcurementPermissions {
  static bool get _isAdmin =>
      AuthService.currentUser?.roleKey == AuthService.roleAdmin;

  static bool get canCreatePurchaseRequests =>
      _isAdmin ||
      AuthService.hasPermission(SchoolPermissions.createPurchaseRequests);

  static bool get canApprovePurchaseRequests =>
      _isAdmin ||
      AuthService.hasPermission(SchoolPermissions.approvePurchaseRequests);

  /// Recording delivered goods into the store (procurement or storekeeper).
  static bool get canReceivePurchases =>
      _isAdmin ||
      AuthService.hasAnyPermission(const [
        SchoolPermissions.receiveStock,
        SchoolPermissions.enterPurchasedItems,
      ]);

  static bool get canCreateIssueRequests =>
      _isAdmin ||
      AuthService.hasPermission(SchoolPermissions.createIssueRequests);

  static bool get canApproveIssueRequests =>
      _isAdmin ||
      AuthService.hasPermission(SchoolPermissions.approveIssueRequests);

  static bool get canIssueStock =>
      _isAdmin || AuthService.hasPermission(SchoolPermissions.issueStock);

  static bool get canSeePurchaseRequests =>
      canCreatePurchaseRequests ||
      canApprovePurchaseRequests ||
      canReceivePurchases ||
      AuthService.hasPermission(SchoolPermissions.viewAllDepartments) ||
      AuthService.hasPermission(SchoolPermissions.viewInventory);

  static bool get canSeeIssueRequests =>
      canCreateIssueRequests ||
      canApproveIssueRequests ||
      canIssueStock ||
      AuthService.hasPermission(SchoolPermissions.viewAllDepartments) ||
      AuthService.hasPermission(SchoolPermissions.viewInventory);
}

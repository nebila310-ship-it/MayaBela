/// Paid learning-material purchase / unlock workflow.
enum MaterialPurchaseStatus {
  pendingParentApproval,
  awaitingPayment,
  paymentSubmitted,
  approved,
  rejected,
  cancelled,
}

enum MaterialPurchaseSource { studentRequest, parentDirect }

enum MaterialPaymentMethod { cbe, telebirr, other }

class MaterialPurchaseRequest {
  MaterialPurchaseRequest({
    required this.id,
    required this.materialId,
    required this.materialTitle,
    required this.studentId,
    required this.studentName,
    required this.schoolId,
    required this.priceEtb,
    required this.status,
    required this.source,
    required this.createdAt,
    this.className = '',
    this.parentUsername,
    this.parentName,
    this.paymentMethod,
    this.receiptNote,
    this.parentApprovedAt,
    this.paymentSubmittedAt,
    this.adminConfirmedAt,
    this.adminUsername,
    this.rejectionReason,
  });

  final String id;
  final String materialId;
  final String materialTitle;
  final String studentId;
  final String studentName;
  final String schoolId;
  final double priceEtb;
  MaterialPurchaseStatus status;
  final MaterialPurchaseSource source;
  final DateTime createdAt;
  final String className;
  String? parentUsername;
  String? parentName;
  MaterialPaymentMethod? paymentMethod;
  String? receiptNote;
  DateTime? parentApprovedAt;
  DateTime? paymentSubmittedAt;
  DateTime? adminConfirmedAt;
  String? adminUsername;
  String? rejectionReason;

  bool get isOpen =>
      status == MaterialPurchaseStatus.pendingParentApproval ||
      status == MaterialPurchaseStatus.awaitingPayment ||
      status == MaterialPurchaseStatus.paymentSubmitted;

  Map<String, dynamic> toMap() => {
        'id': id,
        'materialId': materialId,
        'materialTitle': materialTitle,
        'studentId': studentId,
        'studentName': studentName,
        'schoolId': schoolId,
        'priceEtb': priceEtb,
        'status': status.name,
        'source': source.name,
        'createdAt': createdAt.toIso8601String(),
        'className': className,
        if (parentUsername != null) 'parentUsername': parentUsername,
        if (parentName != null) 'parentName': parentName,
        if (paymentMethod != null) 'paymentMethod': paymentMethod!.name,
        if (receiptNote != null) 'receiptNote': receiptNote,
        if (parentApprovedAt != null)
          'parentApprovedAt': parentApprovedAt!.toIso8601String(),
        if (paymentSubmittedAt != null)
          'paymentSubmittedAt': paymentSubmittedAt!.toIso8601String(),
        if (adminConfirmedAt != null)
          'adminConfirmedAt': adminConfirmedAt!.toIso8601String(),
        if (adminUsername != null) 'adminUsername': adminUsername,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };

  static MaterialPurchaseRequest fromMap(Map<String, dynamic> map) {
    MaterialPurchaseStatus status;
    try {
      status = MaterialPurchaseStatus.values.byName(
        map['status'] as String? ?? 'pendingParentApproval',
      );
    } catch (_) {
      status = MaterialPurchaseStatus.pendingParentApproval;
    }
    MaterialPurchaseSource source;
    try {
      source = MaterialPurchaseSource.values.byName(
        map['source'] as String? ?? 'studentRequest',
      );
    } catch (_) {
      source = MaterialPurchaseSource.studentRequest;
    }
    MaterialPaymentMethod? method;
    final rawMethod = map['paymentMethod'] as String?;
    if (rawMethod != null) {
      try {
        method = MaterialPaymentMethod.values.byName(rawMethod);
      } catch (_) {}
    }

    return MaterialPurchaseRequest(
      id: map['id'] as String,
      materialId: map['materialId'] as String? ?? '',
      materialTitle: map['materialTitle'] as String? ?? '',
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      priceEtb: (map['priceEtb'] as num?)?.toDouble() ?? 0,
      status: status,
      source: source,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      className: map['className'] as String? ?? '',
      parentUsername: map['parentUsername'] as String?,
      parentName: map['parentName'] as String?,
      paymentMethod: method,
      receiptNote: map['receiptNote'] as String?,
      parentApprovedAt:
          DateTime.tryParse(map['parentApprovedAt'] as String? ?? ''),
      paymentSubmittedAt:
          DateTime.tryParse(map['paymentSubmittedAt'] as String? ?? ''),
      adminConfirmedAt:
          DateTime.tryParse(map['adminConfirmedAt'] as String? ?? ''),
      adminUsername: map['adminUsername'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }
}

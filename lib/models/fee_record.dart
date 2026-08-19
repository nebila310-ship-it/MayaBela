enum FeeStatus { pending, paid, overdue }

class FeeRecord {
  FeeRecord({
    required this.id,
    required this.studentName,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.term,
    this.studentId,
    this.className,
    this.status = FeeStatus.pending,
    this.paidVia,
    this.paidDate,
  });

  final String id;
  final String studentName;
  final String? studentId;
  final String? className;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String term;
  FeeStatus status;
  String? paidVia;
  DateTime? paidDate;

  bool get isPaid => status == FeeStatus.paid;
}

class PaymentSummary {
  PaymentSummary({
    required this.totalDue,
    required this.totalPaid,
    required this.overdueCount,
  });

  final double totalDue;
  final double totalPaid;
  final int overdueCount;
}

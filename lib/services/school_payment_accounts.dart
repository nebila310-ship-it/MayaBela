/// Temporary school payment destinations for book unlock testing.
///
/// Replace with each school's real accounts later (school registry settings).
class SchoolPaymentAccounts {
  SchoolPaymentAccounts._();

  static const telegramUsername = 'nabilmaya';
  static const telebirrPhone = '+251911646444';
  static const cbeAccountNumber = '1000343789126';
  static const cbeAccountName = 'Nabil Ahmed';

  static String receiptMessage({
    required String materialTitle,
    required String studentName,
    required double priceEtb,
    required String requestId,
  }) {
    return 'MayaBela book payment receipt\n'
        'Book: $materialTitle\n'
        'Student: $studentName\n'
        'Amount: ${priceEtb.toStringAsFixed(0)} ETB\n'
        'Request: $requestId\n'
        'Please confirm unlock.';
  }

  static Uri telegramReceiptUri(String message) {
    return Uri.https('t.me', telegramUsername, {'text': message});
  }

  static Uri whatsappReceiptUri(String message) {
    final digits = telebirrPhone.replaceAll(RegExp(r'\D'), '');
    return Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/utils/email_utils.dart';

void main() {
  test('accepts a normal email', () {
    expect(EmailUtils.normalize('  Parent@School.et '), 'parent@school.et');
    expect(EmailUtils.isValid('parent@school.et'), isTrue);
  });

  test('rejects missing or malformed email', () {
    expect(EmailUtils.normalize(''), isNull);
    expect(EmailUtils.normalize('not-an-email'), isNull);
    expect(EmailUtils.normalize('missing-domain@'), isNull);
    expect(EmailUtils.isValid('   '), isFalse);
  });
}

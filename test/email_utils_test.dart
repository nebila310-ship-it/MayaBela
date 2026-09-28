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

  test('hides generated mayabela.local mailboxes from the owner console', () {
    expect(EmailUtils.userFacing(''), isNull);
    expect(EmailUtils.userFacing('admin@fenote.mayabela.local'), isNull);
    expect(EmailUtils.userFacing('director@school.et'), 'director@school.et');
  });

  test('accepts a display-name From header', () {
    expect(
      EmailUtils.normalizeFromHeader('MayaBela <onboarding@resend.dev>'),
      'onboarding@resend.dev',
    );
    expect(EmailUtils.isValidFromHeader('noreply@school.et'), isTrue);
    expect(EmailUtils.isValidFromHeader('not-an-email'), isFalse);
  });
}

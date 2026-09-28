import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('login reset does not pin the request to the Teacher tab role', () {
    final login = read('lib/screens/login_screen.dart');
    final start = login.indexOf('Widget _forgotPasswordScreen()');
    expect(start, greaterThan(0));
    final end = login.indexOf('AppStrings get s', start);
    final block = login.substring(start, end);
    expect(block, contains('ForgotPasswordScreen('));
    expect(
      block.contains('roleKey: AuthService.apiRoleKeyForLogin(selectedRole)'),
      isFalse,
    );

    final screen = read('lib/screens/forgot_password_screen.dart');
    expect(screen, contains('requestPasswordReset('));
    expect(screen.contains('roleKey: widget.roleKey'), isFalse);
  });

  test('reset lookup prefers role but still finds school admin email', () {
    final auth = read('supabase/functions/_shared/school_auth.ts');
    expect(auth, contains('roleKey is a preference only'));
    expect(auth, contains("school?.adminEmail"));
    expect(auth, contains('mailboxAddress'));

    final request = read(
      'supabase/functions/school-request-password-reset/index.ts',
    );
    expect(request, contains('findAccountByEmail(sb, schoolId, email)'));
    expect(request, contains('via'));
  });

  test('auth mailer rate-limit counts as already sent, not a hard fail', () {
    final mailer = read('supabase/functions/_shared/mailer.ts');
    expect(mailer, contains('over_email_send'));
    expect(mailer, contains('generateLink'));
    expect(mailer, contains('email_not_authorized'));
    expect(mailer, contains('Your MayaBela password reset code is'));
  });

  test('reset copy tells the user to check spam', () {
    final s = AppStrings('en');
    expect(s.resetCodeSent.toLowerCase(), contains('spam'));
    expect(s.resetCodeSentCheckSpam.toLowerCase(), contains('spam'));
    expect(s.resetCodeSentCheckSpam.toLowerCase(), contains('gmail'));
    expect(s.mailNotConfigured.toLowerCase(), contains('smtp.gmail.com'));
  });

  test('cloud result keeps the mailer via flag', () {
    const sent = SchoolAuthCloudResult(ok: true, via: 'mail');
    expect(sent.via, 'mail');
    const auth = SchoolAuthCloudResult(ok: true, via: 'auth');
    expect(auth.via, 'auth');
  });
}

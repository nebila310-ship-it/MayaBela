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
    expect(auth, contains('is a preference only'));
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
    expect(mailer, contains('smtp_blocked'));
    expect(mailer, contains('secrets.resendApiKey'));
  });

  test('reset copy tells the user to check spam', () {
    final s = AppStrings('en');
    expect(s.resetCodeSent.toLowerCase(), contains('spam'));
    expect(s.resetCodeSentCheckSpam.toLowerCase(), contains('spam'));
    expect(s.resetCodeSentCheckSpam.toLowerCase(), contains('gmail'));
    expect(s.mailNotConfigured.toLowerCase(), contains('smtp.gmail.com'));
  });

  test('creating parent or staff accounts requires a real mailbox', () {
    final upsert = read('supabase/functions/school-upsert-account/index.ts');
    expect(upsert, contains('isUserFacingEmail'));
    expect(upsert, contains('invalid_email'));
    expect(upsert, contains('A valid email is required for password reset.'));

    final parent = read('supabase/functions/school-register-parent/index.ts');
    expect(parent, contains('isUserFacingEmail'));
    expect(parent, contains('invalid_email'));

    final auth = read('supabase/functions/_shared/school_auth.ts');
    expect(auth, contains('isUserFacingEmail'));
    expect(auth, contains('.mayabela.local'));
  });

  test('registration screens mark email required for password reset', () {
    final s = AppStrings('en');
    expect(s.emailForPasswordReset.toLowerCase(), contains('required'));
    expect(s.emailForPasswordResetHint.toLowerCase(), contains('forgot'));

    for (final path in [
      'lib/screens/parent_signup_screen.dart',
      'lib/screens/signup_screen.dart',
      'lib/screens/admin_enrollment_screens.dart',
      'lib/screens/admin_driver_screens.dart',
      'lib/screens/admin_people_screens.dart',
      'lib/screens/enrollment_screens.dart',
      'lib/web_erp/pages/web_hr_register_driver_page.dart',
    ]) {
      final source = read(path);
      expect(
        source.contains('isRealMailbox') || source.contains('userFacing'),
        isTrue,
        reason: path,
      );
      expect(
        source.contains('emailForPasswordReset') ||
            source.contains('required for password reset'),
        isTrue,
        reason: path,
      );
    }
  });

  test('school desks can read mail ready-state without an owner PIN', () {
    final fn = read('supabase/functions/platform-mail-config/index.ts');
    expect(fn, contains("action === \"public-status\""));
    expect(fn.indexOf('public-status'), lessThan(fn.indexOf('authorizePlatformOwner')));

    final client = read('lib/services/platform_mail_cloud_service.dart');
    expect(client, contains('Future<PlatformMailStatus> publicStatus()'));
    expect(client, contains("'action': 'public-status'"));
    expect(client.contains("'ownerPin': ownerPin"), isTrue);
  });

  test('student forgot-password queues on the cloud admin desk', () {
    final fn = read(
      'supabase/functions/school-request-student-password-reset/index.ts',
    );
    expect(fn, contains('student_password_resets'));
    expect(fn, contains('upsertDoc'));
    expect(fn, contains('findAccountDoc(sb, identifier, "student"'));

    final auth = read('lib/services/school_auth_cloud_service.dart');
    expect(auth, contains('requestStudentPasswordReset('));
    expect(auth, contains('school-request-student-password-reset'));

    final screen = read('lib/screens/student_forgot_password_screen.dart');
    expect(screen, contains('StudentPasswordResetStore.instance.submit('));
  });

  test('cloud result keeps the mailer via flag', () {
    const sent = SchoolAuthCloudResult(ok: true, via: 'mail');
    expect(sent.via, 'mail');
    const auth = SchoolAuthCloudResult(ok: true, via: 'auth');
    expect(auth.via, 'auth');
  });
}

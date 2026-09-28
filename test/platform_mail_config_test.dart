import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/platform_mail_cloud_service.dart';

void main() {
  test('parses a configured mail status payload', () {
    final status = PlatformMailStatus.fromMap({
      'ok': true,
      'configured': true,
      'from': 'MayaBela <onboarding@resend.dev>',
      'hasResend': true,
      'hasSmtp': false,
    });
    expect(status.ok, isTrue);
    expect(status.configured, isTrue);
    expect(status.hasResend, isTrue);
    expect(status.from, contains('onboarding@resend.dev'));
  });

  test('treats a missing sender as not configured', () {
    final status = PlatformMailStatus.fromMap({
      'ok': true,
      'configured': false,
      'from': '',
      'hasResend': false,
      'hasSmtp': false,
    });
    expect(status.configured, isFalse);
    expect(status.hasResend, isFalse);
  });
}

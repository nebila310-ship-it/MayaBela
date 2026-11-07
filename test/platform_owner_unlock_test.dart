import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/platform_owner_service.dart';
import 'package:mayabela/widgets/platform_pin_flows.dart';

void main() {
  test('owner unlock errors explain authenticator and lockout states', () {
    expect(ownerUnlockErrorText('totp_required'), contains('authenticator'));
    expect(ownerUnlockErrorText('totp_invalid'), contains('Wrong authenticator code'));
    expect(ownerUnlockErrorText('rate_limited'), contains('Too many attempts'));
    expect(ownerUnlockErrorText(null), 'Wrong PIN. Try again.');
    expect(ownerUnlockErrorText('unauthorized'), 'Wrong PIN. Try again.');
  });

  test('platform calls carry no owner session until the server issues one', () {
    final service = PlatformOwnerService.instance;
    service.clearSessionPin();
    expect(service.ownerSessionFields, isEmpty);
    expect(service.needsTotpCode, isFalse);
  });
}

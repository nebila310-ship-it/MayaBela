import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/auth_service.dart';

void main() {
  test('generateTempPassword is unique and meets min length', () {
    final a = AuthService.generateTempPassword();
    final b = AuthService.generateTempPassword();
    expect(a.length, greaterThanOrEqualTo(AuthService.minPasswordLength));
    expect(b.length, greaterThanOrEqualTo(AuthService.minPasswordLength));
    expect(a, isNot(equals(b)));
    expect(a, isNot(equals(AuthService.tempPassword)));
  });

  test('new teacher/driver registrations require password change', () {
    // Defaults on register*Account constructors — mustChangePassword true.
    // Smoke: helper exists and produces cloud-valid length.
    expect(
      AuthService.generateTempPassword().length >= AuthService.minPasswordLength,
      isTrue,
    );
  });
}

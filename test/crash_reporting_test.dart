import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/crash_reporting.dart';

void main() {
  test('crash context drops secrets and keeps safe keys', () {
    final cleaned = CrashReporting.sanitizeContext({
      'schoolId': 'TB-001',
      'password': 'should-not-leave',
      'accessToken': 'tok',
      'role': 'teacher',
    });
    expect(cleaned['schoolId'], 'TB-001');
    expect(cleaned['role'], 'teacher');
    expect(cleaned.containsKey('password'), isFalse);
    expect(cleaned.containsKey('accessToken'), isFalse);
  });
}

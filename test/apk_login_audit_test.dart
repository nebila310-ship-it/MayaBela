import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/app_version.dart';
import 'package:mayabela/supabase_options.dart';

void main() {
  test('pilot APK version is 1.0.5+6 so testers can see a new install', () {
    expect(kMayaBelaVersion, '1.0.5+6');
  });

  test('APK uses the same live Supabase project as the website', () {
    expect(kSupabaseReady, isTrue);
    expect(kSupabaseUrl, contains('hwkiihonthueadbhcvfi.supabase.co'));
    expect(kSupabaseAnonKey, isNotEmpty);
  });
}

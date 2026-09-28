import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/supabase_options.dart';

void main() {
  test('compiled defaults keep the live Supabase project reachable', () {
    expect(kSupabaseConfigured, isTrue);
    expect(kSupabaseUrl, 'https://hwkiihonthueadbhcvfi.supabase.co');
    expect(kSupabaseAnonKey, isNotEmpty);
    expect(kSupabaseReady, isTrue);
  });
}

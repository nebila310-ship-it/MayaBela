import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/supabase_options.dart';

String _jwtPayload(String token) {
  final parts = token.split('.');
  expect(parts.length, 3);
  var b64 = parts[1].replaceAll('-', '+').replaceAll('_', '/');
  while (b64.length % 4 != 0) {
    b64 += '=';
  }
  return utf8.decode(base64.decode(b64));
}

void main() {
  test('the compiled client key is an anon JWT, not service_role', () {
    final payload = _jwtPayload(kSupabaseAnonKey);
    expect(payload, contains('"role":"anon"'));
    expect(payload, isNot(contains('service_role')));
  });

  test('Dart under lib/ does not embed a service-role secret', () {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (entity.path.endsWith('supabase_options.dart')) {
        expect(text, contains('Never put the **service_role** key here'));
        continue;
      }
      if (text.contains('SERVICE_ROLE') ||
          text.contains('supabaseServiceRole') ||
          text.contains('role":"service_role"')) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty, reason: hits.join(', '));
  });
}

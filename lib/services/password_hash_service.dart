import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Stores passwords as `salt:sha256hex` for student portal accounts.
class PasswordHashService {
  PasswordHashService._();
  static final instance = PasswordHashService._();

  static const _prefix = 'sha256:';

  bool isHashed(String value) => value.startsWith(_prefix);

  String hashPassword(String plain) {
    final salt = _randomSalt();
    final digest = _digest(plain, salt);
    return '$_prefix$salt:$digest';
  }

  bool verifyPassword(String plain, String stored) {
    if (!isHashed(stored)) return plain == stored;
    final body = stored.substring(_prefix.length);
    final parts = body.split(':');
    if (parts.length != 2) return false;
    final expected = _digest(plain, parts[0]);
    return expected == parts[1];
  }

  String _digest(String plain, String salt) {
    final bytes = utf8.encode('$salt::$plain');
    return sha256.convert(bytes).toString();
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

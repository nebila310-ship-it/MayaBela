import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 6238 TOTP (HMAC-SHA1, 30s, 6 digits) plus recovery-code hashing.
/// Secrets and recovery codes must never be logged.
abstract final class Totp {
  static const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static const periodSeconds = 30;
  static const digits = 6;

  static String generateSecret({int bytes = 20}) {
    final rng = Random.secure();
    final data = List<int>.generate(bytes, (_) => rng.nextInt(256));
    return base32Encode(data);
  }

  static String generateCode(
    String secret, {
    DateTime? at,
    int periodSeconds = periodSeconds,
    int digits = Totp.digits,
  }) {
    final seconds =
        (at ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final counter = seconds ~/ periodSeconds;
    return hotp(secret, counter, digits: digits);
  }

  static bool verify(
    String secret,
    String code, {
    DateTime? at,
    int window = 1,
  }) {
    final expected = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(expected)) return false;
    final now = at ?? DateTime.now().toUtc();
    for (var i = -window; i <= window; i++) {
      final candidate = generateCode(
        secret,
        at: now.add(Duration(seconds: i * periodSeconds)),
      );
      if (constantTimeEquals(candidate, expected)) return true;
    }
    return false;
  }

  static String hotp(String secret, int counter, {int digits = Totp.digits}) {
    final key = base32Decode(secret);
    final msg = Uint8List(8);
    var value = counter;
    for (var i = 7; i >= 0; i--) {
      msg[i] = value & 0xff;
      value >>= 8;
    }
    final digest = Hmac(sha1, key).convert(msg).bytes;
    final offset = digest[digest.length - 1] & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);
    final otp = binary % _pow10(digits);
    return otp.toString().padLeft(digits, '0');
  }

  static List<String> generateRecoveryCodes({int count = 8}) {
    final rng = Random.secure();
    return List<String>.generate(count, (_) {
      final n = rng.nextInt(0x100000000);
      final hex = n.toRadixString(16).padLeft(8, '0').toUpperCase();
      return '${hex.substring(0, 4)}-${hex.substring(4)}';
    });
  }

  static String hashRecovery(String code) {
    final normalized =
        code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var acc = 0;
    for (var i = 0; i < a.length; i++) {
      acc |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return acc == 0;
  }

  static String base32Encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) {
      out.write(alphabet[(buffer << (5 - bits)) & 31]);
    }
    return out.toString();
  }

  static List<int> base32Decode(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s=]'), '').toUpperCase();
    var buffer = 0;
    var bits = 0;
    final out = <int>[];
    for (final rune in cleaned.runes) {
      final idx = alphabet.indexOf(String.fromCharCode(rune));
      if (idx < 0) continue;
      buffer = (buffer << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xff);
      }
    }
    return out;
  }

  static int _pow10(int digits) {
    var n = 1;
    for (var i = 0; i < digits; i++) {
      n *= 10;
    }
    return n;
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive_ce.dart';

class SecurityService {
  // A static salt used to stretch the password uniformly across your 3 devices.
  static const String _salt = "VaultMoneySecureSalt2026_UniqueKey!";

  /// Derives a secure 32-byte (256-bit) AES key from a user password
  static Uint8List deriveKey(String password) {
    var bytes = utf8.encode(password + _salt);
    var currentHash = sha256.convert(bytes);

    // Key Stretching loop
    for (int i = 0; i < 10000; i++) {
      currentHash = sha256.convert(currentHash.bytes);
    }

    return Uint8List.fromList(currentHash.bytes);
  }
}

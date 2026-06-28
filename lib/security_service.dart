import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

// DEPRECATED: Use KeyDerivationFunction in core/security/kdf.dart instead.
// This file uses a static salt and SHA256-only derivation (not PBKDF2).
// Kept only for migrating existing data if any was created with this method.
class SecurityService {
  static const String _salt = "VaultMoneySecureSalt2026_UniqueKey!";

  static Uint8List deriveKey(String password) {
    var bytes = utf8.encode(password + _salt);
    var currentHash = sha256.convert(bytes);

    for (int i = 0; i < 10000; i++) {
      currentHash = sha256.convert(currentHash.bytes);
    }

    return Uint8List.fromList(currentHash.bytes);
  }
}

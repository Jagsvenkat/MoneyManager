// Key Derivation Function (KDF) implementation
// Supports PBKDF2-HMAC-SHA512 via the cryptography package

import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';

class KdfParams {
  final String algorithm; // 'argon2id' or 'pbkdf2'
  final int timeParam; // Argon2id time cost
  final int memoryParam; // Argon2id memory cost (KB)
  final int parallelism; // Argon2id parallelism
  final int iterations; // PBKDF2 iterations
  final int outputLength;

  const KdfParams({
    required this.algorithm,
    this.timeParam = 3,
    this.memoryParam = 65536,
    this.parallelism = 4,
    this.iterations = 600000,
    this.outputLength = 32,
  });

  Map<String, dynamic> toJson() => {
    'algorithm': algorithm,
    'timeParam': timeParam,
    'memoryParam': memoryParam,
    'parallelism': parallelism,
    'iterations': iterations,
    'outputLength': outputLength,
  };

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
    algorithm: json['algorithm'] ?? 'pbkdf2',
    timeParam: json['timeParam'] ?? 3,
    memoryParam: json['memoryParam'] ?? 65536,
    parallelism: json['parallelism'] ?? 4,
    iterations: json['iterations'] ?? 600000,
    outputLength: json['outputLength'] ?? 32,
  );
}

/// Key derivation using PBKDF2-HMAC-SHA512 (Argon2id support pending)
class KeyDerivationFunction {
  static const defaultParams = KdfParams(
    algorithm: 'pbkdf2',
    iterations: 600000,
    outputLength: 32,
  );

  /// Derive a User Master Key (UMK) from username, password, and salt
  /// Returns 32-byte derived key
  static Future<Uint8List> deriveUserMasterKey(
    String username,
    String password,
    Uint8List salt, {
    KdfParams params = defaultParams,
  }) async {
    final input = username + password;
    return _derivePbkdf2(input, salt, params);
  }

  /// PBKDF2-HMAC-SHA512 with minimum iteration floor
  static Future<Uint8List> _derivePbkdf2(
    String input,
    Uint8List salt,
    KdfParams params,
  ) async {
    final bytes = utf8.encode(input);
    final iterations = params.iterations > 600000 ? params.iterations : 600000;

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac(Sha512()),
      iterations: iterations,
      bits: params.outputLength * 8,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(bytes),
      nonce: salt,
    );
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  /// Derive a wrapping key from UMK for envelope encryption
  static Future<Uint8List> deriveWrappingKey(
    Uint8List umk,
    String context,
  ) async {
    // Use HKDF-SHA256 for wrapping key derivation
    final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(umk),
      nonce: utf8.encode(context),
    );
    return Uint8List.fromList(await derived.extractBytes());
  }
}



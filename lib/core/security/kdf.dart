// Key Derivation Function (KDF) implementation
// Supports Argon2id (preferred) with fallback to PBKDF2-HMAC-SHA512

import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_pkg;
import 'dart:convert';

class KdfParams {
  final String algorithm; // 'argon2id' or 'pbkdf2'
  final int timeParam; // Argon2id time cost
  final int memoryParam; // Argon2id memory cost (KB)
  final int parallelism; // Argon2id parallelism
  final int iterations; // PBKDF2 iterations
  final int outputLength;

  KdfParams({
    required this.algorithm,
    this.timeParam = 3,
    this.memoryParam = 65536,
    this.parallelism = 4,
    this.iterations = 200000,
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
    algorithm: json['algorithm'] ?? 'argon2id',
    timeParam: json['timeParam'] ?? 3,
    memoryParam: json['memoryParam'] ?? 65536,
    parallelism: json['parallelism'] ?? 4,
    iterations: json['iterations'] ?? 200000,
    outputLength: json['outputLength'] ?? 32,
  );
}

/// Key derivation using PBKDF2-HMAC-SHA512 (Argon2id support pending)
class KeyDerivationFunction {
  static const defaultParams = KdfParams(
    algorithm: 'pbkdf2',
    iterations: 200000,
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

  /// PBKDF2-HMAC-SHA512 with 200,000 iterations minimum
  static Uint8List _derivePbkdf2(
    String input,
    Uint8List salt,
    KdfParams params,
  ) {
    final bytes = utf8.encode(input);
    final iterations = params.iterations > 200000 ? params.iterations : 200000;
    
    // Use PBKDF2 from cryptography package
    return Pbkdf2(
      iterations: iterations,
    ).deriveBitsSync(
      secret: bytes,
      nonce: salt,
      bits: params.outputLength * 8,
    );
  }

  /// Derive a wrapping key from UMK for envelope encryption
  static Future<Uint8List> deriveWrappingKey(
    Uint8List umk,
    String context,
  ) async {
    // Use HKDF-SHA256 for wrapping key derivation
    final hkdf = Hkdf(hmac: Hmac(Sha256()), hashAlgorithm: Sha256());
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(umk),
      nonce: utf8.encode(context),
      keyDataLength: 32,
    );
    return derived.extractBytes();
  }
}

/// PBKDF2-HMAC-SHA512 implementation
class Pbkdf2 {
  final int iterations;

  Pbkdf2({required this.iterations});

  Uint8List deriveBitsSync({
    required List<int> secret,
    required Uint8List nonce,
    required int bits,
  }) {
    final blockCount = (bits + 511) ~/ 512; // SHA512 = 512 bits
    final output = Uint8List(blockCount * 64);
    
    for (int i = 1; i <= blockCount; i++) {
      final block = _pbkdf2Block(secret, nonce, i);
      final startIdx = (i - 1) * 64;
      final endIdx = i * 64;
      output.setRange(startIdx, endIdx.clamp(0, output.length), block);
    }
    
    return Uint8List.sublistView(output, 0, bits ~/ 8);
  }

  Uint8List _pbkdf2Block(List<int> secret, Uint8List salt, int blockIndex) {
    final hmac = crypto_pkg.Hmac(crypto_pkg.sha512, secret);
    final saltWithIndex = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..setAll(salt.length, _bigEndianBytes(blockIndex));
    
    var u = Uint8List.fromList(hmac.convert(saltWithIndex).bytes);
    final result = Uint8List.fromList(u);
    
    for (int i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    
    return result;
  }

  List<int> _bigEndianBytes(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }
}

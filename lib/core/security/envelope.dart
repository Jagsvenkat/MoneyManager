// Envelope encryption implementation
// Uses XChaCha20-Poly1305 for AEAD encryption with DEK wrapping

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

/// Data Encryption Envelope for secure storage and transmission
/// Stores encrypted data with metadata for integrity and versioning
class EncryptionEnvelope {
  final String recordId; // Unique record identifier
  final String version; // Envelope version for migrations
  final String deviceId; // Device that created this record
  final DateTime timestamp; // Record creation/update time

  // Envelope contents (base64 encoded)
  final String encDek; // Encrypted Data Encryption Key
  final String nonce; // Unique nonce for AEAD (base64)
  final String ciphertext; // Encrypted payload (base64)
  final String aad; // Additional Authenticated Data (plaintext JSON)

  // Metadata for sync and conflict resolution
  final String syncStatus; // 'pending', 'synced', 'conflict'
  final String? conflictMarker; // Timestamp of conflicting version

  EncryptionEnvelope({
    required this.recordId,
    required this.version,
    required this.deviceId,
    required this.timestamp,
    required this.encDek,
    required this.nonce,
    required this.ciphertext,
    required this.aad,
    this.syncStatus = 'pending',
    this.conflictMarker,
  });

  Map<String, dynamic> toJson() => {
    'recordId': recordId,
    'version': version,
    'deviceId': deviceId,
    'timestamp': timestamp.toIso8601String(),
    'encDek': encDek,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'aad': aad,
    'syncStatus': syncStatus,
    'conflictMarker': conflictMarker,
  };

  factory EncryptionEnvelope.fromJson(Map<String, dynamic> json) =>
      EncryptionEnvelope(
        recordId: json['recordId'] as String,
        version: json['version'] as String,
        deviceId: json['deviceId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        encDek: json['encDek'] as String,
        nonce: json['nonce'] as String,
        ciphertext: json['ciphertext'] as String,
        aad: json['aad'] as String,
        syncStatus: json['syncStatus'] as String? ?? 'pending',
        conflictMarker: json['conflictMarker'] as String?,
      );
}

/// Envelope encryption/decryption using XChaCha20-Poly1305
/// Implements secure AEAD encryption with DEK wrapping
class EnvelopeEncryption {
  static const version = '1.0';

  /// Encrypt a payload and wrap DEK with user's wrapping key
  static Future<EncryptionEnvelope> encrypt({
    required String recordId,
    required String deviceId,
    required Map<String, dynamic> payload,
    required Uint8List wrappingKey,
    required Map<String, dynamic> metadata,
  }) async {
    final timestamp = DateTime.now().toUtc();

    // Generate random 32-byte DEK for this record
    final dek = _generateRandomBytes(32);

    // Generate random 24-byte nonce for XChaCha20-Poly1305
    final nonce = _generateRandomBytes(24);

    // Create AAD: version + deviceId + timestamp + recordId
    final aadData = {
      'version': version,
      'deviceId': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'recordId': recordId,
      ...metadata, // Include additional metadata for integrity
    };
    final aadBytes = utf8.encode(jsonEncode(aadData));

    // Encrypt payload with DEK using XChaCha20-Poly1305
    final plaintextBytes = utf8.encode(jsonEncode(payload));
    final encryptedPayload = await _encryptAead(
      plaintext: plaintextBytes,
      key: dek,
      nonce: nonce,
      aad: aadBytes,
    );

    // Encrypt DEK with wrapping key
    final wrappingNonce = _generateRandomBytes(24);
    final encryptedDek = await _encryptAead(
      plaintext: dek,
      key: wrappingKey,
      nonce: wrappingNonce,
      aad: aadBytes,
    );

    // Combine DEK and its nonce for storage
    final encDekWithNonce =
        Uint8List(encryptedDek.length + wrappingNonce.length)
          ..setRange(0, wrappingNonce.length, wrappingNonce)
          ..setRange(
            wrappingNonce.length,
            wrappingNonce.length + encryptedDek.length,
            encryptedDek,
          );

    return EncryptionEnvelope(
      recordId: recordId,
      version: version,
      deviceId: deviceId,
      timestamp: timestamp,
      encDek: base64Encode(encDekWithNonce),
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(encryptedPayload),
      aad: jsonEncode(aadData),
      syncStatus: 'pending',
    );
  }

  /// Decrypt envelope and return plaintext payload
  static Future<Map<String, dynamic>> decrypt({
    required EncryptionEnvelope envelope,
    required Uint8List wrappingKey,
  }) async {
    try {
      // Decode all base64 values
      final encDekWithNonce = base64Decode(envelope.encDek);
      final nonce = base64Decode(envelope.nonce);
      final ciphertext = base64Decode(envelope.ciphertext);
      final aadBytes = utf8.encode(envelope.aad);

      // Extract wrapping nonce and encrypted DEK
      final wrappingNonce = encDekWithNonce.sublist(0, 24);
      final encryptedDek = encDekWithNonce.sublist(24);

      // Decrypt DEK with wrapping key
      final dek = await _decryptAead(
        ciphertext: encryptedDek,
        key: wrappingKey,
        nonce: wrappingNonce,
        aad: aadBytes,
      );

      // Decrypt payload with DEK
      final plaintext = await _decryptAead(
        ciphertext: ciphertext,
        key: dek,
        nonce: nonce,
        aad: aadBytes,
      );

      // Parse and return payload
      return jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    } catch (e) {
      throw DecryptionException('Failed to decrypt envelope: $e');
    }
  }

  /// XChaCha20-Poly1305 AEAD encryption
  static Future<Uint8List> _encryptAead({
    required Uint8List plaintext,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
  }) async {
    final cipher = Xchacha20.poly1305Aead();
    final secretKey = SecretKey(key);

    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );

    // Return ciphertext + tag (authenticator), nonce is stored separately
    return Uint8List.fromList(
      secretBox.cipherText + secretBox.mac.bytes,
    );
  }

  /// XChaCha20-Poly1305 AEAD decryption
  static Future<Uint8List> _decryptAead({
    required Uint8List ciphertext,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
  }) async {
    final cipher = Xchacha20.poly1305Aead();
    final secretKey = SecretKey(key);

    // Extract ciphertext and tag (last 16 bytes)
    final actualCiphertext = ciphertext.sublist(0, ciphertext.length - 16);
    final tag = ciphertext.sublist(ciphertext.length - 16);

    final secretBox = SecretBox(actualCiphertext, nonce: nonce, mac: Mac(tag));

    return await cipher.decrypt(secretBox, secretKey: secretKey, aad: aad);
  }

  /// Generate cryptographically secure random bytes
  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}

class DecryptionException implements Exception {
  final String message;
  DecryptionException(this.message);

  @override
  String toString() => 'DecryptionException: $message';
}

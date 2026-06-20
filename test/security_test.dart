// Tests for key derivation, encryption, and envelope operations

import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/security/kdf.dart';
import 'package:money_manager/core/security/envelope.dart';
import 'package:money_manager/core/services/auth_service.dart';
import 'dart:typed_data';
import 'dart:convert';

void main() {
  group('KeyDerivationFunction Tests', () {
    test('deriveUserMasterKey produces consistent output', () async {
      const username = 'testuser';
      const password = 'TestPassword123!@#';
      final salt = SecureRandom.nextBytes(32);

      final umk1 = await KeyDerivationFunction.deriveUserMasterKey(
        username,
        password,
        salt,
      );

      final umk2 = await KeyDerivationFunction.deriveUserMasterKey(
        username,
        password,
        salt,
      );

      expect(umk1, equals(umk2));
      expect(umk1.length, equals(32));
    });

    test('deriveUserMasterKey differs with different passwords', () async {
      const username = 'testuser';
      final salt = SecureRandom.nextBytes(32);

      final umk1 = await KeyDerivationFunction.deriveUserMasterKey(
        username,
        'Password123!@#',
        salt,
      );

      final umk2 = await KeyDerivationFunction.deriveUserMasterKey(
        username,
        'Password123!@$',
        salt,
      );

      expect(umk1, isNot(equals(umk2)));
    });

    test('deriveUserMasterKey differs with different salts', () async {
      const username = 'testuser';
      const password = 'TestPassword123!@#';

      final umk1 = await KeyDerivationFunction.deriveUserMasterKey(
        username,
        password,
        SecureRandom.nextBytes(32),
      );

      final umk2 = await KeyDerivationFunction.deriveUserMasterKey(
        username,
        password,
        SecureRandom.nextBytes(32),
      );

      expect(umk1, isNot(equals(umk2)));
    });

    test('deriveWrappingKey produces 32-byte key', () async {
      final umk = SecureRandom.nextBytes(32);
      final wrappingKey = await KeyDerivationFunction.deriveWrappingKey(
        umk,
        'context',
      );

      expect(wrappingKey.length, equals(32));
    });
  });

  group('EnvelopeEncryption Tests', () {
    late Uint8List wrappingKey;

    setUp(() async {
      wrappingKey = SecureRandom.nextBytes(32);
    });

    test('encrypt and decrypt roundtrip', () async {
      const recordId = 'test-record-1';
      const deviceId = 'device-1';
      final payload = {
        'amount': 100.50,
        'category': 'Food',
        'timestamp': DateTime.now().toIso8601String(),
      };
      final metadata = {'type': 'expense'};

      // Encrypt
      final envelope = await EnvelopeEncryption.encrypt(
        recordId: recordId,
        deviceId: deviceId,
        payload: payload,
        wrappingKey: wrappingKey,
        metadata: metadata,
      );

      // Verify envelope structure
      expect(envelope.recordId, equals(recordId));
      expect(envelope.deviceId, equals(deviceId));
      expect(envelope.version, equals('1.0'));
      expect(envelope.syncStatus, equals('pending'));

      // Decrypt
      final decrypted = await EnvelopeEncryption.decrypt(
        envelope: envelope,
        wrappingKey: wrappingKey,
      );

      // Verify decrypted data
      expect(decrypted['amount'], equals(100.50));
      expect(decrypted['category'], equals('Food'));
    });

    test('decryption fails with wrong wrapping key', () async {
      const recordId = 'test-record-2';
      const deviceId = 'device-1';
      final payload = {'secret': 'data'};

      final envelope = await EnvelopeEncryption.encrypt(
        recordId: recordId,
        deviceId: deviceId,
        payload: payload,
        wrappingKey: wrappingKey,
        metadata: {},
      );

      // Try with wrong key
      final wrongKey = SecureRandom.nextBytes(32);

      expect(
        () => EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: wrongKey,
        ),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('decryption fails with tampered ciphertext', () async {
      const recordId = 'test-record-3';
      const deviceId = 'device-1';
      final payload = {'data': 'sensitive'};

      var envelope = await EnvelopeEncryption.encrypt(
        recordId: recordId,
        deviceId: deviceId,
        payload: payload,
        wrappingKey: wrappingKey,
        metadata: {},
      );

      // Tamper with ciphertext
      final tampered = envelope.ciphertext.replaceRange(0, 5, 'XXXXX');
      envelope = EncryptionEnvelope(
        recordId: envelope.recordId,
        version: envelope.version,
        deviceId: envelope.deviceId,
        timestamp: envelope.timestamp,
        encDek: envelope.encDek,
        nonce: envelope.nonce,
        ciphertext: tampered,
        aad: envelope.aad,
        syncStatus: envelope.syncStatus,
      );

      expect(
        () => EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: wrappingKey,
        ),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('envelope JSON serialization roundtrip', () async {
      final envelope1 = await EnvelopeEncryption.encrypt(
        recordId: 'test-4',
        deviceId: 'device-1',
        payload: {'test': 'data'},
        wrappingKey: wrappingKey,
        metadata: {},
      );

      final json = envelope1.toJson();
      final envelope2 = EncryptionEnvelope.fromJson(json);

      expect(envelope1.recordId, equals(envelope2.recordId));
      expect(envelope1.deviceId, equals(envelope2.deviceId));
      expect(envelope1.ciphertext, equals(envelope2.ciphertext));
      expect(envelope1.nonce, equals(envelope2.nonce));
    });
  });

  group('PasswordValidator Tests', () {
    test('validates weak passwords', () {
      expect(PasswordValidator.isStrong('short'), isFalse);
      expect(PasswordValidator.isStrong('nouppercase123!'), isFalse);
      expect(PasswordValidator.isStrong('NOLOWERCASE123!'), isFalse);
      expect(PasswordValidator.isStrong('NoNumbers!'), isFalse);
      expect(PasswordValidator.isStrong('NoSpecial123'), isFalse);
    });

    test('validates strong passwords', () {
      expect(PasswordValidator.isStrong('ValidPass123!'), isTrue);
      expect(PasswordValidator.isStrong('AnotherValid1@#'), isTrue);
      expect(PasswordValidator.isStrong('VeryLongPassword123!@#$'), isTrue);
    });

    test('provides feedback for weak passwords', () {
      expect(
        PasswordValidator.getStrengthFeedback(''),
        contains('Enter a password'),
      );
      expect(
        PasswordValidator.getStrengthFeedback('short'),
        contains('12 characters'),
      );
      expect(
        PasswordValidator.getStrengthFeedback('nouppercase123!'),
        contains('uppercase'),
      );
    });

    test('calculates strength score correctly', () {
      expect(PasswordValidator.getStrengthScore(''), equals(0));
      expect(PasswordValidator.getStrengthScore('ShortPass1!'), lessThan(3));
      expect(PasswordValidator.getStrengthScore('ValidPass123!@#'), greaterThan(3));
      expect(PasswordValidator.getStrengthScore('VeryLongPassword123!@#$'), greaterThan(4));
    });
  });

  group('SecureRandom Tests', () {
    test('generates random bytes of correct length', () {
      final bytes32 = SecureRandom.nextBytes(32);
      expect(bytes32.length, equals(32));

      final bytes64 = SecureRandom.nextBytes(64);
      expect(bytes64.length, equals(64));
    });

    test('generates different random values', () {
      final bytes1 = SecureRandom.nextBytes(32);
      final bytes2 = SecureRandom.nextBytes(32);

      // Extremely unlikely to be equal (2^-256 probability)
      expect(bytes1, isNot(equals(bytes2)));
    });

    test('nextInt respects upper bound', () {
      for (int i = 0; i < 100; i++) {
        final value = SecureRandom.nextInt(100);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(100));
      }
    });
  });

  group('Integration Tests', () {
    test('full encryption workflow with metadata', () async {
      final umk = SecureRandom.nextBytes(32);

      // Create expense envelope
      final expense = {
        'id': 'exp-123',
        'amount': 50.00,
        'category': 'Food',
        'merchant': 'Restaurant',
        'dateTime': DateTime.now().toIso8601String(),
      };

      final envelope = await EnvelopeEncryption.encrypt(
        recordId: 'exp-123',
        deviceId: 'device-1',
        payload: expense,
        wrappingKey: umk,
        metadata: {
          'type': 'expense',
          'userId': 'user-1',
          'version': '1.0',
        },
      );

      // Verify envelope can be serialized to JSON
      final jsonStr = jsonEncode(envelope.toJson());
      final parsed = jsonDecode(jsonStr);
      expect(parsed['recordId'], equals('exp-123'));
      expect(parsed['syncStatus'], equals('pending'));

      // Decrypt and verify
      final decrypted = await EnvelopeEncryption.decrypt(
        envelope: envelope,
        wrappingKey: umk,
      );
      expect(decrypted['amount'], equals(50.00));
    });
  });
}

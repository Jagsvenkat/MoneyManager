// Authentication service with KDF and key management
// Handles user registration, login, and session management

import 'dart:typed_data';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import '../security/kdf.dart';
import '../security/secure_storage.dart';
import '../security/envelope.dart';
import '../database/local_database.dart';

/// Secure random number generator
class SecureRandom {
  static final _random = Random.secure();

  static int nextInt(int max) {
    return _random.nextInt(max);
  }

  static Uint8List nextBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}

class AuthService {
  static late LocalDatabaseService _db;
  late Uint8List _userMasterKey;
  late String _currentUserId;
  late String _deviceId;

  /// Initialize auth service
  Future<void> initialize() async {
    await SecureStorageService.initialize();

    // Load or create device ID
    var deviceId = await SecureStorageService.loadDeviceId();
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await SecureStorageService.saveDeviceId(deviceId);
    }
    _deviceId = deviceId;

    _db = LocalDatabaseService();
  }

  /// Register new user
  /// Returns encrypted backup for safekeeping
  Future<String> register({
    required String username,
    required String password,
  }) async {
    if (password.length < 12) {
      throw Exception('Password must be at least 12 characters');
    }

    // Generate random salt
    final salt = SecureRandom.nextBytes(32);

    // Derive UMK from username + password + salt
    final umk = await KeyDerivationFunction.deriveUserMasterKey(
      username,
      password,
      salt,
      params: KdfParams.defaultParams,
    );

    // Encrypt UMK with a password-derived key for backup
    final backupUmkEncrypted = await _encryptUmkForBackup(umk, password);

    // Save KDF params and encrypted UMK to secure storage
    await SecureStorageService.saveKdfParams(
      userId: username,
      salt: salt,
      algorithm: KdfParams.defaultParams.algorithm,
      params: KdfParams.defaultParams.toJson(),
    );
    await SecureStorageService.saveEncryptedUmk(
      userId: username,
      encryptedUmk: backupUmkEncrypted,
    );

    _currentUserId = username;
    _userMasterKey = umk;

    // Initialize local database
    await _db.initialize(
      userId: username,
      deviceId: _deviceId,
      wrappingKey: _userMasterKey,
    );

    return backupUmkEncrypted;
  }

  /// Login user
  Future<void> login({
    required String username,
    required String password,
  }) async {
    // Load KDF params
    final kdfParams = await SecureStorageService.loadKdfParams(username);
    if (kdfParams == null) {
      throw Exception('User not found');
    }

    // Extract salt and params
    final salt = kdfParams['salt'] as Uint8List;
    final params = KdfParams.fromJson(kdfParams);

    // Derive UMK
    final umk = await KeyDerivationFunction.deriveUserMasterKey(
      username,
      password,
      salt,
      params: params,
    );

    // Verify by attempting to decrypt stored UMK backup
    final encryptedUmk = await SecureStorageService.loadEncryptedUmk(username);
    if (encryptedUmk == null) {
      throw Exception('No backup UMK found for user');
    }

    try {
      // Verify UMK is correct by decrypting backup
      await _decryptUmkBackup(encryptedUmk, password);
    } catch (e) {
      throw Exception('Invalid password');
    }

    _currentUserId = username;
    _userMasterKey = umk;

    // Initialize local database
    await _db.initialize(
      userId: username,
      deviceId: _deviceId,
      wrappingKey: _userMasterKey,
    );
  }

  /// Get current user
  String get currentUserId => _currentUserId;

  /// Get current device ID
  String get deviceId => _deviceId;

  /// Get current UMK (for creating envelopes)
  Uint8List get userMasterKey => _userMasterKey;

  /// Get local database service
  LocalDatabaseService get database => _db;

  /// Change password (re-wrap UMK)
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 12) {
      throw Exception('New password must be at least 12 characters');
    }

    // Verify old password
    final kdfParams = await SecureStorageService.loadKdfParams(_currentUserId);
    if (kdfParams == null) throw Exception('User not found');

    final salt = kdfParams['salt'] as Uint8List;
    final params = KdfParams.fromJson(kdfParams);

    final oldUmk = await KeyDerivationFunction.deriveUserMasterKey(
      _currentUserId,
      oldPassword,
      salt,
      params: params,
    );

    // Verify UMK matches current one
    if (!_bytesEqual(oldUmk, _userMasterKey)) {
      throw Exception('Invalid current password');
    }

    // Re-encrypt UMK with new password
    final newEncryptedUmk = await _encryptUmkForBackup(
      _userMasterKey,
      newPassword,
    );

    // Save new encrypted UMK
    await SecureStorageService.saveEncryptedUmk(
      userId: _currentUserId,
      encryptedUmk: newEncryptedUmk,
    );
  }

  /// Logout user (clear session)
  Future<void> logout() async {
    await _db.close();
    await SecureStorageService.clearUserStorage(_currentUserId);
  }

  // Private helper methods

  /// Encrypt UMK for secure backup using password-derived key
  Future<String> _encryptUmkForBackup(Uint8List umk, String password) async {
    // Derive a wrapping key from password
    final passwordSalt = Uint8List(16);
    final wrappingKey = await KeyDerivationFunction.deriveUserMasterKey(
      'backup',
      password,
      passwordSalt,
    );

    // Encrypt UMK
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: 'umk_backup',
      deviceId: _deviceId,
      payload: {'umk': base64Encode(umk)},
      wrappingKey: wrappingKey,
      metadata: {'type': 'umk_backup'},
    );

    return jsonEncode(envelope.toJson());
  }

  /// Decrypt UMK from secure backup
  Future<Uint8List> _decryptUmkBackup(
    String encryptedJson,
    String password,
  ) async {
    final envelope = EncryptionEnvelope.fromJson(
      jsonDecode(encryptedJson) as Map<String, dynamic>,
    );

    // Derive wrapping key from password
    final passwordSalt = Uint8List(16);
    final wrappingKey = await KeyDerivationFunction.deriveUserMasterKey(
      'backup',
      password,
      passwordSalt,
    );

    // Decrypt
    final decrypted = await EnvelopeEncryption.decrypt(
      envelope: envelope,
      wrappingKey: wrappingKey,
    );

    return base64Decode(decrypted['umk'] as String);
  }

  /// Compare two byte arrays for equality
  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Password strength validator
class PasswordValidator {
  static bool isStrong(String password) {
    if (password.length < 12) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  static String getStrengthFeedback(String password) {
    if (password.isEmpty) return 'Enter a password';
    if (password.length < 12) return 'At least 12 characters required';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Add uppercase letters';
    if (!password.contains(RegExp(r'[a-z]'))) return 'Add lowercase letters';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Add numbers';
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Add special characters';
    }
    return 'Strong password';
  }

  static int getStrengthScore(String password) {
    int score = 0;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;
    return score;
  }
}

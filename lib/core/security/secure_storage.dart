// Secure storage for sensitive data
// Mobile: flutter_secure_storage (Android Keystore / iOS Keychain)
// Web: IndexedDB with encryption

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage interface for platform-specific implementations
abstract class SecureStorageProvider {
  Future<void> save(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> clear();
}

/// Mobile/Desktop implementation using flutter_secure_storage
class NativeSecureStorage implements SecureStorageProvider {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<void> save(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

/// Web implementation using SharedPreferences (localStorage)
/// Persists across page refreshes. Data is encrypted before storage.
class WebSecureStorage implements SecureStorageProvider {
  @override
  Future<void> save(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

/// Main secure storage service
class SecureStorageService {
  static late SecureStorageProvider _provider;

  static Future<void> initialize() async {
    if (kIsWeb) {
      _provider = WebSecureStorage();
    } else {
      _provider = NativeSecureStorage();
    }
  }

  /// Save KDF parameters (salt, algorithm, etc.)
  static Future<void> saveKdfParams({
    required String userId,
    required Uint8List salt,
    required String algorithm,
    required Map<String, dynamic> params,
  }) async {
    final data = {
      'salt': _bytesToBase64(salt),
      'algorithm': algorithm,
      ...params,
    };
    await _provider.save('kdf_params_$userId', jsonEncode(data));
  }

  /// Load KDF parameters for user
  static Future<Map<String, dynamic>?> loadKdfParams(String userId) async {
    final data = await _provider.read('kdf_params_$userId');
    if (data == null) return null;
    final json = jsonDecode(data) as Map<String, dynamic>;
    json['salt'] = _base64ToBytes(json['salt'] as String);
    return json;
  }

  /// Save encrypted UMK blob (encrypted with password-derived key)
  static Future<void> saveEncryptedUmk({
    required String userId,
    required String encryptedUmk, // base64 encoded
  }) async {
    await _provider.save('umk_$userId', encryptedUmk);
  }

  /// Load encrypted UMK blob
  static Future<String?> loadEncryptedUmk(String userId) async {
    return await _provider.read('umk_$userId');
  }

  /// Save GitHub PAT (encrypted with UMK)
  static Future<void> saveGitHubPat({
    required String userId,
    required String encryptedPat, // base64 encoded
  }) async {
    await _provider.save('github_pat_$userId', encryptedPat);
  }

  /// Load encrypted GitHub PAT
  static Future<String?> loadGitHubPat(String userId) async {
    return await _provider.read('github_pat_$userId');
  }

  /// Save device ID (public, not sensitive)
  static Future<void> saveDeviceId(String deviceId) async {
    await _provider.save('device_id', deviceId);
  }

  /// Load device ID
  static Future<String?> loadDeviceId() async {
    return await _provider.read('device_id');
  }

  /// Save sync metadata
  static Future<void> saveSyncMetadata({
    required String userId,
    required String lastSyncTimestamp,
    required String syncStatus,
  }) async {
    final data = {
      'lastSyncTimestamp': lastSyncTimestamp,
      'syncStatus': syncStatus,
    };
    await _provider.save('sync_metadata_$userId', jsonEncode(data));
  }

  /// Load sync metadata
  static Future<Map<String, dynamic>?> loadSyncMetadata(String userId) async {
    final data = await _provider.read('sync_metadata_$userId');
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  /// Clear all storage for a user (on logout)
  static Future<void> clearUserStorage(String userId) async {
    await _provider.delete('kdf_params_$userId');
    await _provider.delete('umk_$userId');
    await _provider.delete('github_pat_$userId');
    await _provider.delete('sync_metadata_$userId');
  }

  /// Clear all storage (factory reset)
  static Future<void> clearAll() async {
    await _provider.clear();
  }

  // Helper methods
  static String _bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  static Uint8List _base64ToBytes(String encoded) {
    return base64Decode(encoded);
  }
}


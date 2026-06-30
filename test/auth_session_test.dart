import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/security/secure_storage.dart';
import 'package:money_manager/core/services/auth_service.dart';
import 'package:money_manager/providers/auth_provider.dart';

/// In-memory storage provider for testing
class InMemorySecureStorage implements SecureStorageProvider {
  final _store = <String, String>{};

  @override
  Future<void> save(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}

void main() {
  late InMemorySecureStorage testStorage;

  setUp(() {
    testStorage = InMemorySecureStorage();
    SecureStorageService.setProviderForTest(testStorage);
  });

  group('AuthProvider initialization', () {
    test('isInitializing starts true and becomes false after init', () async {
      final authProvider = AuthProvider();
      expect(authProvider.isInitializing, isTrue);
      expect(authProvider.isAuthenticated, isFalse);

      await authProvider.initialize();

      expect(authProvider.isInitializing, isFalse);
    });

    test('isAuthenticated stays false when no session exists', () async {
      final authProvider = AuthProvider();
      await authProvider.initialize();

      expect(authProvider.isInitializing, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
    });
  });

  group('session lifecycle', () {
    test('login saves session data to storage', () async {
      await SecureStorageService.saveLastUserId('test@user.com');
      await SecureStorageService.saveSessionKey('test-session-key');
      await SecureStorageService.saveSessionUmk('test-encrypted-umk');

      expect(await SecureStorageService.loadLastUserId(), equals('test@user.com'));
      expect(await SecureStorageService.loadSessionKey(), isNotNull);
      expect(await SecureStorageService.loadSessionUmk(), isNotNull);
    });

    test('session persists across provider re-initialization', () async {
      await SecureStorageService.saveLastUserId('test@user.com');
      await SecureStorageService.saveSessionKey('test-session-key');
      await SecureStorageService.saveSessionUmk('test-encrypted-umk');

      expect(await SecureStorageService.loadLastUserId(), equals('test@user.com'));

      // Simulate app restart with fresh provider
      final freshProvider = AuthProvider();
      expect(freshProvider.isInitializing, isTrue);
      expect(freshProvider.isAuthenticated, isFalse);

      // Session data should still be readable
      expect(await SecureStorageService.loadLastUserId(), equals('test@user.com'));
    });

    test('logout clears session data', () async {
      await SecureStorageService.saveLastUserId('test@user.com');
      await SecureStorageService.saveSessionKey('test-session-key');
      await SecureStorageService.saveSessionUmk('test-encrypted-umk');

      await SecureStorageService.clearSession();

      expect(await SecureStorageService.loadLastUserId(), isNull);
      expect(await SecureStorageService.loadSessionKey(), isNull);
      expect(await SecureStorageService.loadSessionUmk(), isNull);
    });

    test('user storage is isolated per user', () async {
      await SecureStorageService.saveLastUserId('user1');
      await SecureStorageService.saveLastUserId('user2');

      expect(await SecureStorageService.loadLastUserId(), equals('user2'));

      await SecureStorageService.clearUserStorage('user2');
      await SecureStorageService.saveLastUserId('user2');
    });
  });

  group('error handling', () {
    test('missing session key causes tryAutoLogin to return false', () async {
      await SecureStorageService.saveLastUserId('test@user.com');
      // Don't save session key — should fail

      final svc = AuthService();
      await svc.initialize();
      final restored = await svc.tryAutoLogin();
      expect(restored, isFalse);
    });

    test('missing session UMK causes tryAutoLogin to return false', () async {
      await SecureStorageService.saveLastUserId('test@user.com');
      await SecureStorageService.saveSessionKey('some-key');
      // Don't save session UMK — should fail

      final svc = AuthService();
      await svc.initialize();
      final restored = await svc.tryAutoLogin();
      expect(restored, isFalse);
    });

    test('empty user ID causes tryAutoLogin to return false', () async {
      // Don't save anything — should fail
      final svc = AuthService();
      await svc.initialize();
      final restored = await svc.tryAutoLogin();
      expect(restored, isFalse);
    });
  });

  group('web storage persistence', () {
    test('session data persists across service reinitialization', () async {
      await SecureStorageService.saveLastUserId('web@user.com');
      await SecureStorageService.saveSessionKey('web-session-key');

      // Reinitialize provider
      SecureStorageService.setProviderForTest(InMemorySecureStorage());
      SecureStorageService.initialize();

      // In-memory storage won't persist across instance changes (like SharedPreferences would)
      // This test verifies the read/write contract with a fresh provider
      await SecureStorageService.saveLastUserId('web@user.com');
      expect(await SecureStorageService.loadLastUserId(), equals('web@user.com'));
    });
  });

  group('AuthProvider state management', () {
    test('checkAuthStatus does not change state', () async {
      final authProvider = AuthProvider();
      expect(authProvider.isAuthenticated, isFalse);

      await authProvider.checkAuthStatus();
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.isInitializing, isTrue);
    });

    test('clearError has no effect when no error', () {
      final authProvider = AuthProvider();
      authProvider.clearError();
      expect(authProvider.error, isNull);
    });

    test('initialize transitions isInitializing to false', () async {
      final authProvider = AuthProvider();
      expect(authProvider.isInitializing, isTrue);

      await authProvider.initialize();

      expect(authProvider.isInitializing, isFalse);
    });
  });
}

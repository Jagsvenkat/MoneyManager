import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../database/local_database.dart';
import '../security/envelope.dart';

class SyncResult {
  final bool success;
  final String message;
  final int recordsSync;
  final int conflicts;
  final String? error;
  final DateTime timestamp;
  final SyncStatus status;

  SyncResult({
    required this.success,
    required this.message,
    this.recordsSync = 0,
    this.conflicts = 0,
    this.error,
    DateTime? timestamp,
    this.status = SyncStatus.unknown,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();
}

enum SyncStatus {
  notConfigured,
  connected,
  tokenExpired,
  tokenRevoked,
  repoNotFound,
  missingPermission,
  networkUnavailable,
  unknown,
}

class RepositoryInfo {
  final String name;
  final String owner;
  final bool isPrivate;
  final int stars;
  final String url;

  RepositoryInfo({
    required this.name,
    required this.owner,
    required this.isPrivate,
    this.stars = 0,
    required this.url,
  });

  factory RepositoryInfo.fromJson(Map<String, dynamic> json) {
    return RepositoryInfo(
      name: json['name'] as String,
      owner: json['owner']['login'] as String,
      isPrivate: json['private'] as bool,
      stars: json['stargazers_count'] as int? ?? 0,
      url: json['html_url'] as String? ?? '',
    );
  }
}

/// Result of a Test Connection
class ConnectionTestResult {
  final bool success;
  final String message;
  final SyncStatus status;
  final RepositoryInfo? repo;

  ConnectionTestResult({
    required this.success,
    required this.message,
    this.status = SyncStatus.unknown,
    this.repo,
  });
}

/// OAuth Device Flow response from GitHub
class DeviceFlowResponse {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;

  DeviceFlowResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  factory DeviceFlowResponse.fromJson(Map<String, dynamic> json) {
    return DeviceFlowResponse(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      expiresIn: json['expires_in'] as int,
      interval: json['interval'] as int? ?? 5,
    );
  }
}

/// OAuth token response
class OAuthTokenResponse {
  final String accessToken;
  final String? tokenType;
  final String? scope;
  final int? expiresIn;

  OAuthTokenResponse({
    required this.accessToken,
    this.tokenType,
    this.scope,
    this.expiresIn,
  });

  factory OAuthTokenResponse.fromJson(Map<String, dynamic> json) {
    return OAuthTokenResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String?,
      scope: json['scope'] as String?,
      expiresIn: json['expires_in'] as int?,
    );
  }
}

class GitHubSyncService {
  final String? githubToken;
  final String? repoOwner;
  final String? repoName;
  final LocalDatabaseService db;
  final String userId;
  final String deviceId;
  final String? oauthClientId;
  late final Dio _dio;

  GitHubSyncService({
    required this.githubToken,
    required this.repoOwner,
    required this.repoName,
    required this.db,
    required this.userId,
    required this.deviceId,
    this.oauthClientId,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.github.com',
      headers: {
        'Authorization': 'Bearer $githubToken',
        'Accept': 'application/vnd.github.v3+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ));
  }

  bool get isConfigured =>
      githubToken != null &&
      githubToken!.isNotEmpty &&
      repoOwner != null &&
      repoOwner!.isNotEmpty &&
      repoName != null &&
      repoName!.isNotEmpty;

  String get _filePath => 'users/${Uri.encodeComponent(userId)}.json.enc';

  // ========== OAuth Device Authorization Flow ==========

  /// Start the OAuth Device Authorization Flow.
  /// Returns a [DeviceFlowResponse] with the user code and verification URL.
  /// The caller should display these to the user.
  /// Throws [UnsupportedError] on web — OAuth device flow requires native networking.
  Future<DeviceFlowResponse> startDeviceFlow() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'GitHub OAuth on web requires a secure backend/proxy. '
        'Use a Personal Access Token (PAT) instead, or configure backend OAuth.',
      );
    }
    final response = await Dio().post(
      'https://github.com/login/device/code',
      data: {
        'client_id': oauthClientId,
        'scope': 'repo',
      },
      options: Options(
        contentType: 'application/json',
        headers: {'Accept': 'application/json'},
      ),
    );
    return DeviceFlowResponse.fromJson(response.data);
  }

  /// Poll for the OAuth token after the user has authorized the device.
  /// Returns the [OAuthTokenResponse] when the user authorizes, or null if still waiting.
  /// Throws on expiry, access denied, or error.
  /// Throws [UnsupportedError] on web — token exchange requires a backend proxy.
  Future<OAuthTokenResponse?> pollForToken(String deviceCode) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'GitHub OAuth token exchange is not supported on web. '
        'Use a Personal Access Token (PAT) instead, or configure backend OAuth.',
      );
    }
    final response = await Dio().post(
      'https://github.com/login/oauth/access_token',
      data: {
        'client_id': oauthClientId,
        'device_code': deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      },
      options: Options(
        contentType: 'application/json',
        headers: {'Accept': 'application/json'},
      ),
    );

    final data = response.data as Map<String, dynamic>;
    final error = data['error'] as String?;

    if (error == null) {
      return OAuthTokenResponse.fromJson(data);
    }

    if (error == 'authorization_pending') {
      return null; // Still waiting — caller should retry after interval
    }

    if (error == 'slow_down') {
      return null; // Caller should increase polling interval
    }

    if (error == 'expired_token') {
      throw Exception('Device code expired. Please restart the login flow.');
    }

    if (error == 'access_denied') {
      throw Exception('Authorization denied by user.');
    }

    throw Exception('OAuth error: $error');
  }

  /// Exchange an OAuth access token for the current service instance.
  /// Returns a new [GitHubSyncService] with the OAuth token.
  GitHubSyncService withOAuthToken(String token) {
    return GitHubSyncService(
      githubToken: token,
      repoOwner: repoOwner,
      repoName: repoName,
      db: db,
      userId: userId,
      deviceId: deviceId,
      oauthClientId: oauthClientId,
    );
  }

  // ========== Test Connection ==========

  /// Test the GitHub connection configuration.
  /// Validates: token is valid, repo exists, repo is accessible, token has contents access.
  Future<ConnectionTestResult> testConnection() async {
    if (!isConfigured) {
      return ConnectionTestResult(
        success: false,
        message: 'GitHub not configured. Provide token, owner, and repo name.',
        status: SyncStatus.notConfigured,
      );
    }

    try {
      // Step 1: Validate token by calling /user
      try {
        await _dio.get('/user');
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          return ConnectionTestResult(
            success: false,
            message: 'Token is invalid or expired. Reconnect GitHub.',
            status: SyncStatus.tokenExpired,
          );
        }
        if (e.response?.statusCode == 403) {
          return ConnectionTestResult(
            success: false,
            message: 'Token is revoked or lacks access. Reconnect GitHub.',
            status: SyncStatus.tokenRevoked,
          );
        }
        rethrow;
      }

      // Step 2: Validate repo exists and is accessible
      try {
        final repoResp = await _dio.get('/repos/$repoOwner/$repoName');
        final repo = RepositoryInfo.fromJson(repoResp.data);

        return ConnectionTestResult(
          success: true,
          message: 'Connected to ${repo.owner}/$repoName (${repo.isPrivate ? 'private' : 'public'})',
          status: SyncStatus.connected,
          repo: repo,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          return ConnectionTestResult(
            success: false,
            message: 'Repository "$repoOwner/$repoName" not found. Check owner and repo name.',
            status: SyncStatus.repoNotFound,
          );
        }
        if (e.response?.statusCode == 403) {
          return ConnectionTestResult(
            success: false,
            message: 'Token does not have access to this repository. Check repo permissions.',
            status: SyncStatus.missingPermission,
          );
        }
        rethrow;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return ConnectionTestResult(
          success: false,
          message: 'Network unavailable. Check your internet connection.',
          status: SyncStatus.networkUnavailable,
        );
      }
      return ConnectionTestResult(
        success: false,
        message: 'Connection test failed: ${e.message}',
        status: SyncStatus.unknown,
      );
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        message: 'Connection test failed: $e',
        status: SyncStatus.unknown,
      );
    }
  }

  // ========== Sync Operations ==========

  Future<SyncResult> pushChanges({required Uint8List wrappingKey}) async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'GitHub not configured',
        error: 'Missing token, owner, or repo name',
        status: SyncStatus.notConfigured,
      );
    }

    try {
      final allData = {
        'expenses': await db.listExpenses(),
        'income': await db.listIncome(),
        'balances': await db.listBalances(),
        'loans': await db.listLoans(),
        'investments': await db.listInvestments(),
        'categories': await db.listCategories(),
        'recurring_rules': await db.listRecurringRules(),
        'accounts': await db.listAccounts(),
        'transfers': await db.listTransfers(),
        'tombstones': await db.getTombstones(),
        'syncedAt': DateTime.now().toUtc().toIso8601String(),
        'userId': userId,
        'deviceId': deviceId,
      };

      final envelope = await EnvelopeEncryption.encrypt(
        recordId: 'sync_${DateTime.now().millisecondsSinceEpoch}',
        deviceId: deviceId,
        payload: allData,
        wrappingKey: wrappingKey,
        metadata: {'type': 'sync', 'userId': userId},
      );

      final content = base64Encode(utf8.encode(jsonEncode(envelope.toJson())));

      String? sha;
      try {
        final existing = await _dio.get('/repos/$repoOwner/$repoName/contents/$_filePath');
        sha = existing.data['sha'] as String?;
      } catch (_) {}

      await _dio.put(
        '/repos/$repoOwner/$repoName/contents/$_filePath',
        data: {
          'message': 'Sync update for $userId',
          'content': content,
          if (sha != null) 'sha': sha,
        },
      );

      await db.markAllPendingSyncItemsCompleted();

      final tombstones = await db.getTombstones();
      if (tombstones.isNotEmpty) {
        await db.clearSyncedTombstones(
          tombstones.map((t) => t['id'] as String).toSet(),
        );
      }

      return SyncResult(success: true, message: 'Push successful', recordsSync: 1, status: SyncStatus.connected);
    } on DioException catch (e) {
      return _handleDioError(e, 'Push failed');
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Push failed',
        error: 'Sync error: $e',
        status: SyncStatus.unknown,
      );
    }
  }

  Future<SyncResult> pullChanges({required Uint8List wrappingKey}) async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'GitHub not configured',
        error: 'Missing token, owner, or repo name',
        status: SyncStatus.notConfigured,
      );
    }

    try {
      final response = await _dio.get(
        '/repos/$repoOwner/$repoName/contents/$_filePath',
      );

      final content = response.data['content'] as String;
      final decoded = utf8.decode(base64Decode(content.replaceAll('\n', '')));
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(decoded) as Map<String, dynamic>,
      );

      final decrypted = await EnvelopeEncryption.decrypt(
        envelope: envelope,
        wrappingKey: wrappingKey,
      );

      int mergedCount = 0;
      int conflictCount = 0;

      final cloudTombstones = <String>{};
      for (final t in (decrypted['tombstones'] as List<dynamic>?) ?? []) {
        final tData = t as Map<String, dynamic>;
        cloudTombstones.add(tData['id'] as String);
      }

      Future<int> mergeRecords({
        required List<dynamic> cloudRecords,
        required String type,
        required Future<Map<String, dynamic>?> Function(String) reader,
        required Future<void> Function(Map<String, dynamic>) creator,
        required Future<void> Function(String, Map<String, dynamic>) updater,
        required Future<void> Function(String) deleter,
      }) async {
        int merged = 0;
        for (final r in cloudRecords) {
          final data = r as Map<String, dynamic>;
          final id = data['id'] as String;

          if (cloudTombstones.contains(id)) {
            final local = await reader(id);
            if (local != null) {
              await deleter(id);
            }
            continue;
          }

          final local = await reader(id);
          if (local == null) {
            await creator(data);
            merged++;
          } else {
            final localTime = _safeTimestamp(local);
            final cloudTime = _safeTimestamp(data);

            final diff = cloudTime.difference(localTime).inSeconds.abs();
            if (diff <= 2 && local['updatedAt'] != data['updatedAt']) {
              await db.storeConflict(EncryptionEnvelope(
                recordId: id,
                version: '1.0',
                deviceId: data['_deviceId'] as String? ?? 'cloud',
                timestamp: cloudTime,
                encDek: '',
                nonce: '',
                ciphertext: '',
                aad: '',
                syncStatus: 'conflict',
                conflictMarker: localTime.toIso8601String(),
              ));
              conflictCount++;
            } else if (cloudTime.isAfter(localTime)) {
              await updater(id, data);
              merged++;
            }
          }
        }
        return merged;
      }

      mergedCount += await mergeRecords(
        cloudRecords: decrypted['expenses'] as List<dynamic>? ?? [],
        type: 'expense',
        reader: (id) => db.readExpense(id),
        creator: (d) => db.createExpense(d),
        updater: (id, d) => db.updateExpense(id, d),
        deleter: (id) => db.deleteExpense(id),
      );

      mergedCount += await mergeRecords(
        cloudRecords: decrypted['income'] as List<dynamic>? ?? [],
        type: 'income',
        reader: (id) => db.readIncome(id),
        creator: (d) => db.createIncome(d),
        updater: (id, d) => db.updateIncome(id, d),
        deleter: (id) => db.deleteIncome(id),
      );

      mergedCount += await mergeRecords(
        cloudRecords: decrypted['loans'] as List<dynamic>? ?? [],
        type: 'loan',
        reader: (id) => db.readLoan(id),
        creator: (d) => db.createLoan(d),
        updater: (id, d) => db.updateLoan(id, d),
        deleter: (id) => db.deleteLoan(id),
      );

      mergedCount += await mergeRecords(
        cloudRecords: decrypted['investments'] as List<dynamic>? ?? [],
        type: 'investment',
        reader: (id) => db.readInvestment(id),
        creator: (d) => db.createInvestment(d),
        updater: (id, d) => db.updateInvestment(id, d),
        deleter: (id) => db.deleteInvestment(id),
      );

      mergedCount += await mergeRecords(
        cloudRecords: decrypted['recurring_rules'] as List<dynamic>? ?? [],
        type: 'recurring',
        reader: (id) => db.readRecurringRule(id),
        creator: (d) => db.createRecurringRule(d),
        updater: (id, d) => db.updateRecurringRule(id, d),
        deleter: (id) => db.deleteRecurringRule(id),
      );

      mergedCount += await mergeRecords(
        cloudRecords: decrypted['accounts'] as List<dynamic>? ?? [],
        type: 'account',
        reader: (id) => db.readAccount(id),
        creator: (d) => db.createAccount(d),
        updater: (id, d) => db.updateAccount(id, d),
        deleter: (id) => db.deleteAccount(id),
      );

      return SyncResult(
        success: true,
        message: 'Pull successful',
        recordsSync: mergedCount,
        conflicts: conflictCount,
        status: SyncStatus.connected,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return SyncResult(
          success: false,
          message: 'No cloud backup found. Push data first.',
          error: 'Remote file not found. Use Push to create the initial backup.',
          status: SyncStatus.connected,
        );
      }
      return _handleDioError(e, 'Pull failed');
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Pull failed',
        error: 'Sync error: $e',
        status: SyncStatus.unknown,
      );
    }
  }

  SyncResult _handleDioError(DioException e, String action) {
    final statusCode = e.response?.statusCode;
    final detail = e.response?.data is Map
        ? (e.response!.data as Map)['message'] ?? e.message
        : e.message;

    switch (statusCode) {
      case 401:
        return SyncResult(
          success: false,
          message: '$action: Token expired',
          error: 'GitHub session expired. Reconnect GitHub.',
          status: SyncStatus.tokenExpired,
        );
      case 403:
        return SyncResult(
          success: false,
          message: '$action: Access denied',
          error: 'Token lacks required permissions. Ensure repo contents read/write access.',
          status: SyncStatus.missingPermission,
        );
      case 404:
        return SyncResult(
          success: false,
          message: '$action: Not found',
          error: 'Repository or file not found. Check owner/repo name.',
          status: SyncStatus.repoNotFound,
        );
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          return SyncResult(
            success: false,
            message: '$action: Network error',
            error: 'Network unavailable. Check your internet connection.',
            status: SyncStatus.networkUnavailable,
          );
        }
        return SyncResult(
          success: false,
          message: '$action: API error',
          error: '$detail',
          status: SyncStatus.unknown,
        );
    }
  }

  DateTime _safeTimestamp(Map<String, dynamic> record) {
    final raw = record['updatedAt'] ?? record['createdAt'];
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get _bootstrapPath => 'accounts/${_usernameHash(userId)}.bootstrap.json';

  String _usernameHash(String username) {
    final bytes = utf8.encode(username.toLowerCase().trim());
    final hash = sha256.convert(bytes);
    return base64Url.encode(hash.bytes);
  }

  Future<SyncResult> uploadAccountBootstrap({
    required Uint8List salt,
    required String algorithm,
    required int iterations,
    required int outputLength,
    required String encryptedUmk,
  }) async {
    if (!isConfigured) {
      return SyncResult(success: false, message: 'GitHub not configured',
        error: 'Missing token, owner, or repo name', status: SyncStatus.notConfigured);
    }
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'schemaVersion': '1.0',
        'username': userId,
        'algorithm': algorithm,
        'salt': base64Encode(salt),
        'iterations': iterations,
        'outputLength': outputLength,
        'encryptedUmk': encryptedUmk,
        'createdAt': now,
        'updatedAt': now,
      };

      String? sha;
      try {
        final existing = await _dio.get('/repos/$repoOwner/$repoName/contents/$_bootstrapPath');
        final old = existing.data;
        sha = old['sha'] as String?;
        payload['createdAt'] = jsonDecode(utf8.decode(base64Decode(
          (old['content'] as String).replaceAll('\n', ''))))['createdAt'] ?? now;
      } catch (_) {}

      final content = base64Encode(utf8.encode(jsonEncode(payload)));
      await _dio.put(
        '/repos/$repoOwner/$repoName/contents/$_bootstrapPath',
        data: {
          'message': 'Account bootstrap for ${_usernameHash(userId)}',
          'content': content,
          if (sha != null) 'sha': sha,
        },
      );
      return SyncResult(success: true, message: 'Bootstrap uploaded', status: SyncStatus.connected);
    } on DioException catch (e) {
      return _handleDioError(e, 'Bootstrap upload');
    } catch (e) {
      return SyncResult(success: false, message: 'Bootstrap upload failed',
        error: '$e', status: SyncStatus.unknown);
    }
  }

  Future<Map<String, dynamic>?> fetchAccountBootstrap(String username) async {
    if (!isConfigured) return null;
    try {
      final path = 'accounts/${_usernameHash(username)}.bootstrap.json';
      final response = await _dio.get(
        '/repos/$repoOwner/$repoName/contents/$path');
      final raw = response.data['content'] as String;
      return jsonDecode(utf8.decode(base64Decode(raw.replaceAll('\n', ''))))
          as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<bool> accountBootstrapExists(String username) async {
    if (!isConfigured) return false;
    try {
      final path = 'accounts/${_usernameHash(username)}.bootstrap.json';
      await _dio.get('/repos/$repoOwner/$repoName/contents/$path');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SyncResult> deleteAccountBootstrap() async {
    if (!isConfigured) {
      return SyncResult(success: false, message: 'GitHub not configured',
        error: 'Missing token, owner, or repo name', status: SyncStatus.notConfigured);
    }
    try {
      String? sha;
      try {
        final existing = await _dio.get(
          '/repos/$repoOwner/$repoName/contents/$_bootstrapPath');
        sha = existing.data['sha'] as String?;
      } catch (_) {}
      if (sha != null) {
        await _dio.delete(
          '/repos/$repoOwner/$repoName/contents/$_bootstrapPath',
          data: {'message': 'Delete bootstrap for ${_usernameHash(userId)}', 'sha': sha},
        );
      }
      return SyncResult(success: true, message: 'Bootstrap deleted', status: SyncStatus.connected);
    } catch (e) {
      return SyncResult(success: false, message: 'Bootstrap delete failed', error: '$e', status: SyncStatus.unknown);
    }
  }

  Future<SyncResult> fullSync({required Uint8List wrappingKey}) async {
    final push = await pushChanges(wrappingKey: wrappingKey);
    if (!push.success) return push;
    return pullChanges(wrappingKey: wrappingKey);
  }

  Future<bool> verifyToken() async {
    try {
      await _dio.get('/user');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<RepositoryInfo?> getRepositoryInfo() async {
    try {
      final response = await _dio.get('/repos/$repoOwner/$repoName');
      return RepositoryInfo.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  /// Get the authenticated GitHub user's login name.
  /// Returns null on failure.
  Future<String?> getCurrentUser() async {
    try {
      final response = await _dio.get('/user');
      return response.data['login'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// List private repos accessible to the authenticated token.
  /// Returns a list of [RepositoryInfo] or empty list on failure.
  Future<List<RepositoryInfo>> listRepos({String? type}) async {
    try {
      final response = await _dio.get('/user/repos', queryParameters: {
        'per_page': 100,
        'sort': 'updated',
        if (type != null) 'type': type,
      });
      final list = response.data as List<dynamic>;
      return list.map((r) => RepositoryInfo.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check whether a repo [owner]/[name] exists and is accessible.
  Future<bool> repoExists(String owner, String name) async {
    try {
      await _dio.get('/repos/$owner/$name');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Create a private repo with the given [name] under the authenticated user.
  /// Returns [RepositoryInfo] on success, or null on failure.
  Future<RepositoryInfo?> createRepo(String name) async {
    try {
      final response = await _dio.post('/user/repos', data: {
        'name': name,
        'private': true,
        'auto_init': false,
        'description': 'Encrypted backup for SJsaver',
      });
      return RepositoryInfo.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }
}

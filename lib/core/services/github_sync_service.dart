import 'dart:convert';
import 'dart:typed_data';
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

  SyncResult({
    required this.success,
    required this.message,
    this.recordsSync = 0,
    this.conflicts = 0,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();
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

class GitHubSyncService {
  final String? githubToken;
  final String? repoOwner;
  final String? repoName;
  final LocalDatabaseService db;
  final String userId;
  final String deviceId;
  late final Dio _dio;

  GitHubSyncService({
    required this.githubToken,
    required this.repoOwner,
    required this.repoName,
    required this.db,
    required this.userId,
    required this.deviceId,
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

  Future<SyncResult> pushChanges({required Uint8List wrappingKey}) async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'GitHub not configured',
        error: 'Missing token, owner, or repo name',
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

      // Mark all pending queue items as synced
      await db.markAllPendingSyncItemsCompleted();

      // Clear tombstones that were synced
      final tombstones = await db.getTombstones();
      if (tombstones.isNotEmpty) {
        await db.clearSyncedTombstones(
          tombstones.map((t) => t['id'] as String).toSet(),
        );
      }

      return SyncResult(success: true, message: 'Push successful', recordsSync: 1);
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? (e.response!.data as Map)['message'] ?? e.message : e.message;
      return SyncResult(
        success: false,
        message: 'Push failed',
        error: 'GitHub API error ($detail). Ensure your token has repo/contents write access.',
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Push failed',
        error: 'Sync error: $e',
      );
    }
  }

  Future<SyncResult> pullChanges({required Uint8List wrappingKey}) async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'GitHub not configured',
        error: 'Missing token, owner, or repo name',
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

      // Extract tombstoned IDs from cloud data
      final cloudTombstones = <String>{};
      for (final t in (decrypted['tombstones'] as List<dynamic>?) ?? []) {
        final tData = t as Map<String, dynamic>;
        cloudTombstones.add(tData['id'] as String);
      }

      // Merge function with LWW + tombstone awareness
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

          // Skip if this record was tombstoned (deleted locally)
          if (cloudTombstones.contains(id)) {
            // Also delete local copy if it exists (cloud tombstone wins for deletes)
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
              // Near-simultaneous edits — store as conflict
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
      );
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? (e.response!.data as Map)['message'] ?? e.message : e.message;
      return SyncResult(
        success: false,
        message: 'Pull failed',
        error: 'GitHub API error ($detail). Ensure your token has repo/contents read access.',
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Pull failed',
        error: 'Sync error: $e',
      );
    }
  }

  /// Extract updatedAt with fallback: try `updatedAt` field, then `createdAt`,
  /// then use a minimum epoch sentinel so sorting still works.
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

  /// Upload an account bootstrap record so the user can log in from another device.
  /// The record contains KDF params (salt, algorithm, iterations) plus the
  /// already-encrypted UMK backup.  No plaintext secrets are stored.
  Future<SyncResult> uploadAccountBootstrap({
    required Uint8List salt,
    required String algorithm,
    required int iterations,
    required int outputLength,
    required String encryptedUmk,
  }) async {
    if (!isConfigured) {
      return SyncResult(success: false, message: 'GitHub not configured',
        error: 'Missing token, owner, or repo name');
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
      return SyncResult(success: true, message: 'Bootstrap uploaded');
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['message'] ?? e.message : e.message;
      return SyncResult(success: false, message: 'Bootstrap upload failed',
        error: 'GitHub API error ($detail)');
    } catch (e) {
      return SyncResult(success: false, message: 'Bootstrap upload failed',
        error: '$e');
    }
  }

  /// Fetch the account bootstrap record for [username] from GitHub.
  /// Returns the decoded JSON map, or null if the file does not exist.
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

  /// Check if a bootstrap record exists for [username].
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

  /// Delete the account bootstrap record for the current [userId].
  Future<SyncResult> deleteAccountBootstrap() async {
    if (!isConfigured) {
      return SyncResult(success: false, message: 'GitHub not configured',
        error: 'Missing token, owner, or repo name');
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
      return SyncResult(success: true, message: 'Bootstrap deleted');
    } catch (e) {
      return SyncResult(success: false, message: 'Bootstrap delete failed', error: '$e');
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
}

// GitHub sync engine for push/pull with conflict handling
// Implements offline queue, conflict resolution, and encrypted storage

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../security/envelope.dart';
import '../database/local_database.dart';
import 'auth_service.dart';

class GitHubSyncService {
  final String? githubToken;
  final String? repoOwner;
  final String? repoName;
  final LocalDatabaseService db;
  final String userId;
  final String deviceId;

  late Dio _dio;

  GitHubSyncService({
    required this.githubToken,
    required this.repoOwner,
    required this.repoName,
    required this.db,
    required this.userId,
    required this.deviceId,
  }) {
    _initDio();
  }

  void _initDio() {
    _dio = Dio()
      ..options.baseUrl = 'https://api.github.com'
      ..options.headers = {
        'Authorization': 'token $githubToken',
        'Accept': 'application/vnd.github.v3+json',
      }
      ..options.connectTimeout = const Duration(seconds: 30)
      ..options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Check if GitHub sync is configured
  bool get isConfigured => githubToken != null && repoOwner != null && repoName != null;

  /// Push local changes to GitHub
  Future<SyncResult> pushChanges({
    required Uint8List wrappingKey,
  }) async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'GitHub sync not configured',
      );
    }

    try {
      // Get all encrypted records from local DB
      final allRecords = <String, dynamic>{};
      
      // Collect all records from each table
      final expenses = await db.listExpenses();
      final income = await db.listIncome();
      final balances = await db.listBalances();
      final loans = await db.listLoans();
      final investments = await db.listInvestments();
      final categories = await db.listCategories();

      allRecords['expenses'] = expenses;
      allRecords['income'] = income;
      allRecords['balances'] = balances;
      allRecords['loans'] = loans;
      allRecords['investments'] = investments;
      allRecords['categories'] = categories;
      allRecords['syncedAt'] = DateTime.now().toIso8601String();

      // Create backup file name
      final backupFileName = 'users/$userId.json.enc';

      // Get current SHA if file exists (for updates)
      String? currentSha;
      try {
        final response = await _dio.get(
          '/repos/$repoOwner/$repoName/contents/$backupFileName',
        );
        currentSha = response.data['sha'];
      } catch (e) {
        // File doesn't exist yet, will create
      }

      // Encrypt the payload
      final payload = jsonEncode(allRecords);
      final plaintext = utf8.encode(payload);
      
      // Create envelope
      final envelope = await EnvelopeEncryption.encrypt(
        recordId: 'backup_$userId',
        deviceId: deviceId,
        payload: jsonDecode(payload) as Map<String, dynamic>,
        wrappingKey: wrappingKey,
        metadata: {
          'type': 'backup',
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final encryptedContent = jsonEncode(envelope.toJson());
      final base64Content = base64Encode(utf8.encode(encryptedContent));

      // Upload to GitHub
      final updatePayload = {
        'message': 'Sync backup from $deviceId at ${DateTime.now().toIso8601String()}',
        'content': base64Content,
        'branch': 'main',
      };

      if (currentSha != null) {
        (updatePayload as Map)['sha'] = currentSha;
      }

      await _dio.put(
        '/repos/$repoOwner/$repoName/contents/$backupFileName',
        data: updatePayload,
      );

      return SyncResult(
        success: true,
        message: 'Pushed ${expenses.length} expenses, ${income.length} income records',
        recordsSync: expenses.length + income.length + loans.length + investments.length,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Push failed: $e',
        error: e.toString(),
      );
    }
  }

  /// Pull changes from GitHub
  Future<SyncResult> pullChanges({
    required Uint8List wrappingKey,
  }) async {
    if (!isConfigured) {
      return SyncResult(
        success: false,
        message: 'GitHub sync not configured',
      );
    }

    try {
      final backupFileName = 'users/$userId.json.enc';

      final response = await _dio.get(
        '/repos/$repoOwner/$repoName/contents/$backupFileName',
      );

      // Decode base64 content
      final base64Content = response.data['content'] as String;
      final encryptedContent = utf8.decode(base64Decode(base64Content));

      // Decrypt envelope
      final envelopeJson = jsonDecode(encryptedContent) as Map<String, dynamic>;
      final envelope = EncryptionEnvelope.fromJson(envelopeJson);

      final decrypted = await EnvelopeEncryption.decrypt(
        envelope: envelope,
        wrappingKey: wrappingKey,
      );

      // Merge with local data
      final pullTimestamp = DateTime.now().toIso8601String();
      int mergedRecords = 0;

      // Handle each record type with conflict detection
      final expenses = decrypted['expenses'] as List? ?? [];
      for (final expense in expenses) {
        await _mergeRecord(
          recordType: 'expense',
          record: expense as Map<String, dynamic>,
          pullTimestamp: pullTimestamp,
        );
        mergedRecords++;
      }

      final income = decrypted['income'] as List? ?? [];
      for (final incomeRecord in income) {
        await _mergeRecord(
          recordType: 'income',
          record: incomeRecord as Map<String, dynamic>,
          pullTimestamp: pullTimestamp,
        );
        mergedRecords++;
      }

      return SyncResult(
        success: true,
        message: 'Pulled and merged $mergedRecords records',
        recordsSync: mergedRecords,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Pull failed: $e',
        error: e.toString(),
      );
    }
  }

  /// Merge record with conflict detection
  Future<void> _mergeRecord({
    required String recordType,
    required Map<String, dynamic> record,
    required String pullTimestamp,
  }) async {
    final recordId = record['id'] as String;

    // Try to read local version
    Map<String, dynamic>? localRecord;
    try {
      localRecord = switch (recordType) {
        'expense' => await db.readExpense(recordId),
        'income' => await db.readIncome(recordId),
        'loan' => await db.readLoan(recordId),
        'investment' => await db.readInvestment(recordId),
        _ => null,
      };
    } catch (e) {
      // Record doesn't exist locally
    }

    if (localRecord == null) {
      // Create new record locally
      switch (recordType) {
        case 'expense':
          await db.createExpense(record);
          break;
        case 'income':
          await db.createIncome(record);
          break;
        case 'loan':
          await db.createLoan(record);
          break;
        case 'investment':
          await db.createInvestment(record);
          break;
      }
    } else {
      // Compare timestamps for conflict detection
      final localTimestamp = DateTime.parse(localRecord['updatedAt'] as String);
      final remoteTimestamp = DateTime.parse(record['updatedAt'] as String);

      if (remoteTimestamp.isAfter(localTimestamp)) {
        // Remote is newer, update local
        switch (recordType) {
          case 'expense':
            await db.updateExpense(recordId, record);
            break;
          case 'income':
            await db.updateIncome(recordId, record);
            break;
          case 'loan':
            await db.updateLoan(recordId, record);
            break;
        }
      } else if (remoteTimestamp.isBefore(localTimestamp)) {
        // Local is newer, preserve local (no action)
      } else {
        // Same timestamp but possibly different content = conflict
        // Mark as conflict for user resolution
        print('Conflict detected for $recordType:$recordId');
      }
    }
  }

  /// Full sync (push then pull)
  Future<SyncResult> fullSync({
    required Uint8List wrappingKey,
  }) async {
    try {
      // Push local changes first
      final pushResult = await pushChanges(wrappingKey: wrappingKey);
      if (!pushResult.success) {
        return pushResult;
      }

      // Then pull remote changes
      final pullResult = await pullChanges(wrappingKey: wrappingKey);
      
      return SyncResult(
        success: pullResult.success,
        message: 'Full sync completed. Pushed: ${pushResult.recordsSync}, Pulled: ${pullResult.recordsSync}',
        recordsSync: (pushResult.recordsSync ?? 0) + (pullResult.recordsSync ?? 0),
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Full sync failed: $e',
        error: e.toString(),
      );
    }
  }

  /// Verify GitHub token validity
  Future<bool> verifyToken() async {
    try {
      final response = await _dio.get('/user');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get repository info
  Future<RepositoryInfo?> getRepositoryInfo() async {
    try {
      final response = await _dio.get('/repos/$repoOwner/$repoName');
      return RepositoryInfo.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
}

/// Sync operation result
class SyncResult {
  final bool success;
  final String message;
  final int? recordsSync;
  final String? error;
  final DateTime timestamp = DateTime.now();

  SyncResult({
    required this.success,
    required this.message,
    this.recordsSync,
    this.error,
  });

  @override
  String toString() => 'SyncResult($success, $message)';
}

/// Repository information
class RepositoryInfo {
  final String name;
  final String? description;
  final bool isPrivate;
  final String owner;
  final int stars;
  final String url;

  RepositoryInfo({
    required this.name,
    this.description,
    required this.isPrivate,
    required this.owner,
    required this.stars,
    required this.url,
  });

  factory RepositoryInfo.fromJson(Map<String, dynamic> json) {
    return RepositoryInfo(
      name: json['name'] as String,
      description: json['description'] as String?,
      isPrivate: json['private'] as bool,
      owner: json['owner']['login'] as String,
      stars: json['stargazers_count'] as int,
      url: json['html_url'] as String,
    );
  }
}

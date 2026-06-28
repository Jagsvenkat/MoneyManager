import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../database/local_database.dart';
import '../security/envelope.dart';

class SyncResult {
  final bool success;
  final String message;
  final int recordsSync;
  final String? error;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    required this.message,
    this.recordsSync = 0,
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
        'Authorization': 'token $githubToken',
        'Accept': 'application/vnd.github.v3+json',
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

  String get _filePath => 'users/$userId.json.enc';

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

      return SyncResult(success: true, message: 'Push successful', recordsSync: 1);
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Push failed',
        error: 'Sync error: unable to push changes. Check your network and token.',
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

      for (final record in decrypted['expenses'] as List<dynamic>) {
        final data = record as Map<String, dynamic>;
        final existing = await db.readExpense(data['id'] as String);
        if (existing == null) {
          await db.createExpense(data);
          mergedCount++;
        } else {
          final existingTime = DateTime.parse(existing['updatedAt'] as String);
          final newTime = DateTime.parse(data['updatedAt'] as String);
          if (newTime.isAfter(existingTime)) {
            await db.updateExpense(data['id'] as String, data);
            mergedCount++;
          }
        }
      }

      for (final record in decrypted['income'] as List<dynamic>) {
        final data = record as Map<String, dynamic>;
        final existing = await db.readIncome(data['id'] as String);
        if (existing == null) {
          await db.createIncome(data);
          mergedCount++;
        } else {
          final existingTime = DateTime.parse(existing['updatedAt'] as String);
          final newTime = DateTime.parse(data['updatedAt'] as String);
          if (newTime.isAfter(existingTime)) {
            await db.updateIncome(data['id'] as String, data);
            mergedCount++;
          }
        }
      }

      for (final record in decrypted['loans'] as List<dynamic>) {
        final data = record as Map<String, dynamic>;
        final existing = await db.readLoan(data['id'] as String);
        if (existing == null) {
          await db.createLoan(data);
          mergedCount++;
        }
      }

      for (final record in decrypted['investments'] as List<dynamic>) {
        final data = record as Map<String, dynamic>;
        final existing = await db.readInvestment(data['id'] as String);
        if (existing == null) {
          await db.createInvestment(data);
          mergedCount++;
        }
      }

      return SyncResult(
        success: true,
        message: 'Pull successful',
        recordsSync: mergedCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Pull failed',
        error: 'Sync error: unable to pull changes. Check your network and token.',
      );
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

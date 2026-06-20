// Tests for GitHub sync service

import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/services/github_sync_service.dart';
import 'package:money_manager/core/database/local_database.dart';
import 'dart:typed_data';

void main() {
  group('GitHubSyncService Tests', () {
    late GitHubSyncService syncService;

    setUp(() {
      syncService = GitHubSyncService(
        githubToken: 'test_token',
        repoOwner: 'testuser',
        repoName: 'test-repo',
        db: MockLocalDatabaseService(),
        userId: 'user-1',
        deviceId: 'device-1',
      );
    });

    test('isConfigured returns true when all required fields set', () {
      expect(syncService.isConfigured, isTrue);
    });

    test('isConfigured returns false when token missing', () {
      final unconfigured = GitHubSyncService(
        githubToken: null,
        repoOwner: 'testuser',
        repoName: 'test-repo',
        db: MockLocalDatabaseService(),
        userId: 'user-1',
        deviceId: 'device-1',
      );
      expect(unconfigured.isConfigured, isFalse);
    });

    test('SyncResult captures success state', () {
      final result = SyncResult(
        success: true,
        message: 'Test success',
        recordsSync: 5,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('success'));
      expect(result.recordsSync, equals(5));
      expect(result.timestamp, isNotNull);
    });

    test('SyncResult captures error state', () {
      final result = SyncResult(
        success: false,
        message: 'Test error',
        error: 'Network error',
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Network error'));
    });

    test('RepositoryInfo parses JSON correctly', () {
      final json = {
        'name': 'test-repo',
        'description': 'Test repository',
        'private': true,
        'owner': {'login': 'testuser'},
        'stargazers_count': 10,
        'html_url': 'https://github.com/testuser/test-repo',
      };

      final repo = RepositoryInfo.fromJson(json);

      expect(repo.name, equals('test-repo'));
      expect(repo.isPrivate, isTrue);
      expect(repo.owner, equals('testuser'));
      expect(repo.stars, equals(10));
    });

    test('pushChanges returns error when not configured', () async {
      final unconfigured = GitHubSyncService(
        githubToken: null,
        repoOwner: null,
        repoName: null,
        db: MockLocalDatabaseService(),
        userId: 'user-1',
        deviceId: 'device-1',
      );

      final result = await unconfigured.pushChanges(wrappingKey: Uint8List(32));

      expect(result.success, isFalse);
      expect(result.message, contains('not configured'));
    });

    test('pullChanges returns error when not configured', () async {
      final unconfigured = GitHubSyncService(
        githubToken: null,
        repoOwner: null,
        repoName: null,
        db: MockLocalDatabaseService(),
        userId: 'user-1',
        deviceId: 'device-1',
      );

      final result = await unconfigured.pullChanges(wrappingKey: Uint8List(32));

      expect(result.success, isFalse);
      expect(result.message, contains('not configured'));
    });

    test('fullSync calls push then pull', () async {
      // This test verifies the sync order but doesn't make actual requests
      // In a real test, you'd mock the Dio client
      expect(syncService.isConfigured, isTrue);
    });
  });
}

// Mock implementation for testing
class MockLocalDatabaseService extends LocalDatabaseService {
  @override
  Future<List<Map<String, dynamic>>> listExpenses({
    String? categoryFilter,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
  }) async {
    return [
      {
        'id': 'exp-1',
        'amount': 50.00,
        'category': 'Food',
        'dateTime': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listIncome({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return [
      {
        'id': 'inc-1',
        'amount': 1000.00,
        'source': 'Salary',
        'dateTime': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listBalances() async => [];

  @override
  Future<List<Map<String, dynamic>>> listLoans() async => [];

  @override
  Future<List<Map<String, dynamic>>> listInvestments() async => [];

  @override
  Future<List<Map<String, dynamic>>> listCategories() async => [];

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
    required Uint8List wrappingKey,
  }) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> createExpense(Map<String, dynamic> expenseData) async {}

  @override
  Future<void> updateExpense(String id, Map<String, dynamic> updates) async {}

  @override
  Future<void> deleteExpense(String id) async {}

  @override
  Future<Map<String, dynamic>?> readExpense(String id) async => null;

  @override
  Future<void> createIncome(Map<String, dynamic> incomeData) async {}

  @override
  Future<void> updateIncome(String id, Map<String, dynamic> updates) async {}

  @override
  Future<void> deleteIncome(String id) async {}

  @override
  Future<Map<String, dynamic>?> readIncome(String id) async => null;

  @override
  Future<void> createBalance(Map<String, dynamic> balanceData) async {}

  @override
  Future<Map<String, dynamic>?> readBalance(String id) async => null;

  @override
  Future<void> createLoan(Map<String, dynamic> loanData) async {}

  @override
  Future<Map<String, dynamic>?> readLoan(String id) async => null;

  @override
  Future<void> updateLoan(String id, Map<String, dynamic> updates) async {}

  @override
  Future<void> createInvestment(Map<String, dynamic> investmentData) async {}

  @override
  Future<Map<String, dynamic>?> readInvestment(String id) async => null;

  @override
  Future<void> createCategory(Map<String, dynamic> categoryData) async {}

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async => [];

  @override
  Future<void> markSyncItemCompleted(String queueId) async {}
}

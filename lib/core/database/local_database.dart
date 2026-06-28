// Local encrypted database using Hive
// Stores encrypted envelopes with CRUD operations

import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_ce/hive.dart';
import '../../models/models.dart';
import '../security/envelope.dart';
import '../security/kdf.dart';

/// Local database service for encrypted storage
class LocalDatabaseService {
  static const String _expensesBox = 'expenses';
  static const String _incomeBox = 'income';
  static const String _balanceBox = 'balance';
  static const String _loansBox = 'loans';
  static const String _investmentsBox = 'investments';
  static const String _categoriesBox = 'categories';
  static const String _syncQueue = 'sync_queue';
  static const String _conflictsBox = 'conflicts';

  late Box<String> _expensesDb;
  late Box<String> _incomeDb;
  late Box<String> _balanceDb;
  late Box<String> _loansDb;
  late Box<String> _investmentsDb;
  late Box<String> _categoriesDb;
  late Box<Map> _syncQueueDb;
  late Box<String> _conflictsDb;

  late Uint8List _wrappingKey;
  late String _userId;
  late String _deviceId;

  /// Initialize database with encryption key
  Future<void> initialize({
    required String userId,
    required String deviceId,
    required Uint8List wrappingKey,
  }) async {
    _userId = userId;
    _deviceId = deviceId;
    _wrappingKey = wrappingKey;

    // Open Hive boxes
    _expensesDb = await Hive.openBox<String>(_expensesBox);
    _incomeDb = await Hive.openBox<String>(_incomeBox);
    _balanceDb = await Hive.openBox<String>(_balanceBox);
    _loansDb = await Hive.openBox<String>(_loansBox);
    _investmentsDb = await Hive.openBox<String>(_investmentsBox);
    _categoriesDb = await Hive.openBox<String>(_categoriesBox);
    _syncQueueDb = await Hive.openBox<Map>(_syncQueue);
    _conflictsDb = await Hive.openBox<String>(_conflictsBox);
  }

  // ==== Expense Operations ====

  Future<void> createExpense(Map<String, dynamic> expenseData) async {
    final recordId = expenseData['id'] as String;
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: recordId,
      deviceId: _deviceId,
      payload: expenseData,
      wrappingKey: _wrappingKey,
      metadata: {'type': 'expense', 'userId': _userId},
    );
    await _expensesDb.put(recordId, jsonEncode(envelope.toJson()));
    await _addToSyncQueue('expense', recordId, 'create');
  }

  Future<Map<String, dynamic>?> readExpense(String id) async {
    final envelopeJson = _expensesDb.get(id);
    if (envelopeJson == null) return null;

    final envelope = EncryptionEnvelope.fromJson(
      jsonDecode(envelopeJson) as Map<String, dynamic>,
    );
    return await EnvelopeEncryption.decrypt(
      envelope: envelope,
      wrappingKey: _wrappingKey,
    );
  }

  Future<List<Map<String, dynamic>>> listExpenses({
    String? categoryFilter,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
  }) async {
    final expenses = <Map<String, dynamic>>[];

    for (final envelopeJson in _expensesDb.values) {
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(envelopeJson) as Map<String, dynamic>,
      );

      if (envelope.syncStatus == 'conflict') {
        continue; // Skip conflicted records
      }

      try {
        final expense = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: _wrappingKey,
        );

        // Apply filters
        if (categoryFilter != null && expense['category'] != categoryFilter) {
          continue;
        }
        if (startDate != null &&
            DateTime.parse(expense['dateTime'] as String).isBefore(startDate)) {
          continue;
        }
        if (endDate != null &&
            DateTime.parse(expense['dateTime'] as String).isAfter(endDate)) {
          continue;
        }
        if (minAmount != null && (expense['amount'] as double) < minAmount) {
          continue;
        }
        if (maxAmount != null && (expense['amount'] as double) > maxAmount) {
          continue;
        }

        expenses.add(expense);
      } catch (e) {
        // Log decryption error but continue
        print('Error decrypting expense: $e');
      }
    }

    return expenses;
  }

  Future<void> updateExpense(String id, Map<String, dynamic> updates) async {
    final currentData = await readExpense(id);
    if (currentData == null) throw Exception('Expense not found');

    final updatedData = {...currentData, ...updates};
    await _expensesDb.delete(id);
    await createExpense(updatedData);
    await _addToSyncQueue('expense', id, 'update');
  }

  Future<void> deleteExpense(String id) async {
    await _expensesDb.delete(id);
    await _addToSyncQueue('expense', id, 'delete');
  }

  // ==== Income Operations ====

  Future<void> createIncome(Map<String, dynamic> incomeData) async {
    final recordId = incomeData['id'] as String;
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: recordId,
      deviceId: _deviceId,
      payload: incomeData,
      wrappingKey: _wrappingKey,
      metadata: {'type': 'income', 'userId': _userId},
    );
    await _incomeDb.put(recordId, jsonEncode(envelope.toJson()));
    await _addToSyncQueue('income', recordId, 'create');
  }

  Future<Map<String, dynamic>?> readIncome(String id) async {
    final envelopeJson = _incomeDb.get(id);
    if (envelopeJson == null) return null;

    final envelope = EncryptionEnvelope.fromJson(
      jsonDecode(envelopeJson) as Map<String, dynamic>,
    );
    return await EnvelopeEncryption.decrypt(
      envelope: envelope,
      wrappingKey: _wrappingKey,
    );
  }

  Future<List<Map<String, dynamic>>> listIncome({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final incomes = <Map<String, dynamic>>[];

    for (final envelopeJson in _incomeDb.values) {
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(envelopeJson) as Map<String, dynamic>,
      );

      if (envelope.syncStatus == 'conflict') continue;

      try {
        final income = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: _wrappingKey,
        );

        if (startDate != null &&
            DateTime.parse(income['dateTime'] as String).isBefore(startDate)) {
          continue;
        }
        if (endDate != null &&
            DateTime.parse(income['dateTime'] as String).isAfter(endDate)) {
          continue;
        }

        incomes.add(income);
      } catch (e) {
        print('Error decrypting income: $e');
      }
    }

    return incomes;
  }

  Future<void> updateIncome(String id, Map<String, dynamic> updates) async {
    final currentData = await readIncome(id);
    if (currentData == null) throw Exception('Income not found');

    final updatedData = {...currentData, ...updates};
    await _incomeDb.delete(id);
    await createIncome(updatedData);
    await _addToSyncQueue('income', id, 'update');
  }

  Future<void> deleteIncome(String id) async {
    await _incomeDb.delete(id);
    await _addToSyncQueue('income', id, 'delete');
  }

  // ==== Balance Operations ====

  Future<void> createBalance(Map<String, dynamic> balanceData) async {
    final recordId = balanceData['id'] as String;
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: recordId,
      deviceId: _deviceId,
      payload: balanceData,
      wrappingKey: _wrappingKey,
      metadata: {'type': 'balance', 'userId': _userId},
    );
    await _balanceDb.put(recordId, jsonEncode(envelope.toJson()));
  }

  Future<Map<String, dynamic>?> readBalance(String id) async {
    final envelopeJson = _balanceDb.get(id);
    if (envelopeJson == null) return null;

    final envelope = EncryptionEnvelope.fromJson(
      jsonDecode(envelopeJson) as Map<String, dynamic>,
    );
    return await EnvelopeEncryption.decrypt(
      envelope: envelope,
      wrappingKey: _wrappingKey,
    );
  }

  Future<List<Map<String, dynamic>>> listBalances() async {
    final balances = <Map<String, dynamic>>[];

    for (final envelopeJson in _balanceDb.values) {
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(envelopeJson) as Map<String, dynamic>,
      );

      try {
        final balance = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: _wrappingKey,
        );
        balances.add(balance);
      } catch (e) {
        print('Error decrypting balance: $e');
      }
    }

    return balances;
  }

  // ==== Loan Operations ====

  Future<void> createLoan(Map<String, dynamic> loanData) async {
    final recordId = loanData['id'] as String;
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: recordId,
      deviceId: _deviceId,
      payload: loanData,
      wrappingKey: _wrappingKey,
      metadata: {'type': 'loan', 'userId': _userId},
    );
    await _loansDb.put(recordId, jsonEncode(envelope.toJson()));
    await _addToSyncQueue('loan', recordId, 'create');
  }

  Future<Map<String, dynamic>?> readLoan(String id) async {
    final envelopeJson = _loansDb.get(id);
    if (envelopeJson == null) return null;

    final envelope = EncryptionEnvelope.fromJson(
      jsonDecode(envelopeJson) as Map<String, dynamic>,
    );
    return await EnvelopeEncryption.decrypt(
      envelope: envelope,
      wrappingKey: _wrappingKey,
    );
  }

  Future<List<Map<String, dynamic>>> listLoans() async {
    final loans = <Map<String, dynamic>>[];

    for (final envelopeJson in _loansDb.values) {
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(envelopeJson) as Map<String, dynamic>,
      );

      try {
        final loan = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: _wrappingKey,
        );
        loans.add(loan);
      } catch (e) {
        print('Error decrypting loan: $e');
      }
    }

    return loans;
  }

  Future<void> updateLoan(String id, Map<String, dynamic> updates) async {
    final currentData = await readLoan(id);
    if (currentData == null) throw Exception('Loan not found');

    final updatedData = {...currentData, ...updates};
    await _loansDb.delete(id);
    await createLoan(updatedData);
    await _addToSyncQueue('loan', id, 'update');
  }

  // ==== Investment Operations ====

  Future<void> createInvestment(Map<String, dynamic> investmentData) async {
    final recordId = investmentData['id'] as String;
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: recordId,
      deviceId: _deviceId,
      payload: investmentData,
      wrappingKey: _wrappingKey,
      metadata: {'type': 'investment', 'userId': _userId},
    );
    await _investmentsDb.put(recordId, jsonEncode(envelope.toJson()));
    await _addToSyncQueue('investment', recordId, 'create');
  }

  Future<Map<String, dynamic>?> readInvestment(String id) async {
    final envelopeJson = _investmentsDb.get(id);
    if (envelopeJson == null) return null;

    final envelope = EncryptionEnvelope.fromJson(
      jsonDecode(envelopeJson) as Map<String, dynamic>,
    );
    return await EnvelopeEncryption.decrypt(
      envelope: envelope,
      wrappingKey: _wrappingKey,
    );
  }

  Future<List<Map<String, dynamic>>> listInvestments() async {
    final investments = <Map<String, dynamic>>[];

    for (final envelopeJson in _investmentsDb.values) {
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(envelopeJson) as Map<String, dynamic>,
      );

      try {
        final investment = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: _wrappingKey,
        );
        investments.add(investment);
      } catch (e) {
        print('Error decrypting investment: $e');
      }
    }

    return investments;
  }

  // ==== Category Operations ====

  Future<void> createCategory(Map<String, dynamic> categoryData) async {
    final recordId = categoryData['id'] as String;
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: recordId,
      deviceId: _deviceId,
      payload: categoryData,
      wrappingKey: _wrappingKey,
      metadata: {'type': 'category', 'userId': _userId},
    );
    await _categoriesDb.put(recordId, jsonEncode(envelope.toJson()));
  }

  Future<List<Map<String, dynamic>>> listCategories() async {
    final categories = <Map<String, dynamic>>[];

    for (final envelopeJson in _categoriesDb.values) {
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(envelopeJson) as Map<String, dynamic>,
      );

      try {
        final category = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: _wrappingKey,
        );
        categories.add(category);
      } catch (e) {
        print('Error decrypting category: $e');
      }
    }

    return categories;
  }

  // ==== Sync Queue Operations ====

  Future<void> _addToSyncQueue(
    String recordType,
    String recordId,
    String operation,
  ) async {
    final queueId =
        '$recordType:$recordId:${DateTime.now().millisecondsSinceEpoch}';
    await _syncQueueDb.put(queueId, {
      'recordType': recordType,
      'recordId': recordId,
      'operation': operation,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<List<Map<dynamic, dynamic>>> getPendingSyncItems() async {
    return _syncQueueDb.values
        .where((item) => item['status'] == 'pending')
        .cast<Map<dynamic, dynamic>>()
        .toList();
  }

  Future<void> markSyncItemCompleted(String queueId) async {
    final item = _syncQueueDb.get(queueId);
    if (item != null) {
      item['status'] = 'synced';
      await _syncQueueDb.put(queueId, item);
    }
  }

  // ==== Cleanup ====

  Future<void> close() async {
    await _expensesDb.close();
    await _incomeDb.close();
    await _balanceDb.close();
    await _loansDb.close();
    await _investmentsDb.close();
    await _categoriesDb.close();
    await _syncQueueDb.close();
    await _conflictsDb.close();
  }
}

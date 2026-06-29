// Local encrypted database using Hive
// Stores encrypted envelopes with CRUD operations

import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_ce/hive.dart';
import '../security/envelope.dart';

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

    await seedCategoriesIfEmpty();
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
      } catch (_) {
        // Skip decryption error silently — data integrity is maintained
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
      } catch (_) {
        // Skip silently
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
      } catch (_) {
        // Skip silently
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
      } catch (_) {
        // Skip silently
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

  Future<void> deleteLoan(String id) async {
    await _loansDb.delete(id);
    await _addToSyncQueue('loan', id, 'delete');
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
      } catch (_) {
        // Skip silently
      }
    }

    return investments;
  }

  Future<void> updateInvestment(String id, Map<String, dynamic> updates) async {
    final currentData = await readInvestment(id);
    if (currentData == null) throw Exception('Investment not found');

    final updatedData = {...currentData, ...updates};
    await _investmentsDb.delete(id);
    await createInvestment(updatedData);
    await _addToSyncQueue('investment', id, 'update');
  }

  Future<void> deleteInvestment(String id) async {
    await _investmentsDb.delete(id);
    await _addToSyncQueue('investment', id, 'delete');
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

  Future<void> updateCategory(String id, Map<String, dynamic> updates) async {
    final currentData = await readCategory(id);
    if (currentData == null) throw Exception('Category not found');
    final updatedData = {...currentData, ...updates, 'id': id};
    await _categoriesDb.delete(id);
    await createCategory(updatedData);
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesDb.delete(id);
  }

  Future<Map<String, dynamic>?> readCategory(String id) async {
    final envelopeJson = _categoriesDb.get(id);
    if (envelopeJson == null) return null;
    final envelope = EncryptionEnvelope.fromJson(
      jsonDecode(envelopeJson) as Map<String, dynamic>,
    );
    return await EnvelopeEncryption.decrypt(
      envelope: envelope,
      wrappingKey: _wrappingKey,
    );
  }

  Future<List<Map<String, dynamic>>> listCategories({String? type}) async {
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
        if (type == null || category['type'] == type) {
          categories.add(category);
        }
      } catch (_) {
        // Skip silently
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

  // ==== Seed Default Categories ====

  static const Map<String, List<Map<String, dynamic>>> defaultCategories = {
    'expense': [
      {'name': 'Food & Dining', 'color': 0xFFFB7185, 'tags': ['Meals', 'Snacks', 'Groceries', 'Zomato/Swiggy']},
      {'name': 'Transport', 'color': 0xFF60A5FA, 'tags': ['Fuel', 'Bus/Train', 'Auto/Taxi', 'Metro']},
      {'name': 'Shopping', 'color': 0xFFF472B6, 'tags': ['Clothing', 'Electronics', 'Online', 'Accessories']},
      {'name': 'Bills & Utilities', 'color': 0xFFFBBF24, 'tags': ['Electricity', 'Water', 'Gas', 'Internet', 'Phone']},
      {'name': 'Rent', 'color': 0xFFA78BFA, 'tags': ['Home', 'Office', 'PG']},
      {'name': 'Entertainment', 'color': 0xFF22D3EE, 'tags': ['Movies', 'OTT', 'Games', 'Events', 'Music']},
      {'name': 'Healthcare', 'color': 0xFF34D399, 'tags': ['Doctor', 'Medicine', 'Lab Test', 'Insurance']},
      {'name': 'Education', 'color': 0xFF818CF8, 'tags': ['Courses', 'Books', 'Fees', 'Stationery']},
      {'name': 'Subscriptions', 'color': 0xFFC084FC, 'tags': ['Netflix', 'Prime', 'Spotify', 'iCloud', 'YouTube']},
      {'name': 'Travel', 'color': 0xFF06B6D4, 'tags': ['Flight', 'Hotel', 'Cab', 'Holiday']},
      {'name': 'Insurance', 'color': 0xFF0284C7, 'tags': ['Life', 'Health', 'Vehicle', 'Term']},
      {'name': 'Personal Care', 'color': 0xFFE879F9, 'tags': ['Salon', 'Skincare', 'Gym', 'Wellness']},
      {'name': 'Gifts & Donations', 'color': 0xFFF59E0B, 'tags': ['Birthday', 'Charity', 'Festival']},
      {'name': 'Home Maintenance', 'color': 0xFFFB923C, 'tags': ['Repair', 'Cleaning', 'Furniture', 'Appliances']},
      {'name': 'Miscellaneous', 'color': 0xFF64748B, 'tags': ['ATM Fee', 'Fine', 'Other']},
    ],
    'income': [
      {'name': 'Salary', 'color': 0xFF34D399, 'tags': ['Monthly', 'Bonus', 'Incentive', 'Arrears']},
      {'name': 'Freelance', 'color': 0xFF60A5FA, 'tags': ['Project', 'Consulting', 'Contract']},
      {'name': 'Business', 'color': 0xFFA78BFA, 'tags': ['Revenue', 'Profit', 'Commission']},
      {'name': 'Investments', 'color': 0xFF22D3EE, 'tags': ['Dividend', 'Capital Gains', 'Interest']},
      {'name': 'Rental Income', 'color': 0xFFFBBF24, 'tags': ['Property', 'Vehicle', 'Equipment']},
      {'name': 'Refunds', 'color': 0xFF34D399, 'tags': ['Tax', 'Purchase', 'Deposit']},
      {'name': 'Gifts', 'color': 0xFFF472B6, 'tags': ['Birthday', 'Festival', 'Cash Gift']},
      {'name': 'Other Income', 'color': 0xFF64748B, 'tags': ['Cashback', 'Reimbursement', 'Misc']},
    ],
    'loan': [
      {'name': 'Personal Loan', 'color': 0xFFFB7185, 'tags': []},
      {'name': 'Home Loan', 'color': 0xFF60A5FA, 'tags': []},
      {'name': 'Car Loan', 'color': 0xFFFBBF24, 'tags': []},
      {'name': 'Education Loan', 'color': 0xFFA78BFA, 'tags': []},
      {'name': 'Business Loan', 'color': 0xFF22D3EE, 'tags': []},
      {'name': 'Credit Card', 'color': 0xFFF472B6, 'tags': []},
      {'name': 'Friend/Family', 'color': 0xFF34D399, 'tags': []},
      {'name': 'Other Loan', 'color': 0xFF64748B, 'tags': []},
    ],
    'investment': [
      {'name': 'Stocks', 'color': 0xFF34D399, 'tags': ['Large Cap', 'Mid Cap', 'Small Cap', 'IPO']},
      {'name': 'Mutual Funds', 'color': 0xFF60A5FA, 'tags': ['Large Cap', 'Mid Cap', 'Small Cap', 'ELSS', 'Debt']},
      {'name': 'Fixed Deposit', 'color': 0xFFFBBF24, 'tags': ['Bank FD', 'Corporate FD', 'Recurring']},
      {'name': 'Gold', 'color': 0xFFF59E0B, 'tags': ['Physical', 'ETF', 'Digital', 'Sovereign']},
      {'name': 'Real Estate', 'color': 0xFFA78BFA, 'tags': ['Residential', 'Commercial', 'Land']},
      {'name': 'Crypto', 'color': 0xFF22D3EE, 'tags': ['Bitcoin', 'Ethereum', 'Altcoin']},
      {'name': 'PPF / EPF', 'color': 0xFF34D399, 'tags': ['PPF', 'EPF', 'VPF']},
      {'name': 'NPS', 'color': 0xFF818CF8, 'tags': ['Tier 1', 'Tier 2']},
      {'name': 'Bonds', 'color': 0xFFC084FC, 'tags': ['Corporate', 'Government', 'Tax Free']},
      {'name': 'Other Investment', 'color': 0xFF64748B, 'tags': ['Crypto', 'Art', 'Collectibles']},
    ],
  };

  Future<void> seedCategoriesIfEmpty({String? type}) async {
    final typesToSeed = type != null ? [type] : defaultCategories.keys;
    for (final t in typesToSeed) {
      final existing = await listCategories(type: t);
      if (existing.isNotEmpty) continue;
      final defaults = defaultCategories[t] ?? [];
      for (final cat in defaults) {
        await createCategory({
          'id': '${t}_${cat['name']}'.replaceAll(' ', '_').replaceAll('&', 'and'),
          'name': cat['name'],
          'type': t,
          'color': cat['color'],
          'tags': cat['tags'],
        });
      }
    }
  }

  // ==== Cleanup ====

  Future<void> deleteAll() async {
    await _expensesDb.clear();
    await _incomeDb.clear();
    await _balanceDb.clear();
    await _loansDb.clear();
    await _investmentsDb.clear();
    await _categoriesDb.clear();
    await _syncQueueDb.clear();
    await _conflictsDb.clear();
  }

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

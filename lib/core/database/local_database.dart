// Local encrypted database using Hive
// Stores encrypted envelopes with CRUD operations

import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_ce/hive.dart';
import '../security/envelope.dart';
import 'database_helpers.dart';

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
  static const String _settingsBox = 'app_settings';
  static const String _tombstonesBox = 'tombstones';
  static const String _recurringRulesBox = 'recurring_rules';
  static const String _accountsBox = 'accounts';
  static const String _transfersBox = 'transfers';
  static const String _loanRepaymentsBox = 'loan_repayments';

  late Box<String> _expensesDb;
  late Box<String> _incomeDb;
  late Box<String> _balanceDb;
  late Box<String> _loansDb;
  late Box<String> _investmentsDb;
  late Box<String> _categoriesDb;
  late Box<Map> _syncQueueDb;
  late Box<String> _conflictsDb;
  late Box<String> _appSettingsDb;
  late Box<String> _tombstonesDb;
  late Box<String> _recurringRulesDb;
  late Box<String> _accountsDb;
  late Box<String> _transfersDb;
  late Box<String> _loanRepaymentsDb;

  late Uint8List _wrappingKey;
  late String _userId;
  late String _deviceId;

  // Shared CRUD helpers (lazy-initialized after boxes are opened)
  DatabaseHelpers get _expenseHelper => DatabaseHelpers(
    box: _expensesDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'expense', syncQueueBox: _syncQueueDb,
  );
  DatabaseHelpers get _incomeHelper => DatabaseHelpers(
    box: _incomeDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'income', syncQueueBox: _syncQueueDb,
  );
  DatabaseHelpers get _loanHelper => DatabaseHelpers(
    box: _loansDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'loan', syncQueueBox: _syncQueueDb,
  );
  DatabaseHelpers get _investmentHelper => DatabaseHelpers(
    box: _investmentsDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'investment', syncQueueBox: _syncQueueDb,
  );
  DatabaseHelpers get _categoryHelper => DatabaseHelpers(
    box: _categoriesDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'category',
  );
  DatabaseHelpers get _recurringHelper => DatabaseHelpers(
    box: _recurringRulesDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'recurring',
  );
  DatabaseHelpers get _accountHelper => DatabaseHelpers(
    box: _accountsDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'account',
  );
  DatabaseHelpers get _transferHelper => DatabaseHelpers(
    box: _transfersDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'transfer',
  );
  DatabaseHelpers get _loanRepaymentHelper => DatabaseHelpers(
    box: _loanRepaymentsDb, wrappingKey: _wrappingKey, deviceId: _deviceId, userId: _userId,
    recordType: 'loan_repayment',
  );

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
    _appSettingsDb = await Hive.openBox<String>(_settingsBox);
    _tombstonesDb = await Hive.openBox<String>(_tombstonesBox);
    _recurringRulesDb = await Hive.openBox<String>(_recurringRulesBox);
    _accountsDb = await Hive.openBox<String>(_accountsBox);
    _transfersDb = await Hive.openBox<String>(_transfersBox);
    _loanRepaymentsDb = await Hive.openBox<String>(_loanRepaymentsBox);

    await seedCategoriesIfEmpty();
  }

  // ==== Expense Operations ====

  Future<void> createExpense(Map<String, dynamic> expenseData) async {
    _ensureTimestamps(expenseData);
    await _expenseHelper.create(expenseData);
  }

  Future<Map<String, dynamic>?> readExpense(String id) async {
    return _expenseHelper.read(id);
  }

  Future<List<Map<String, dynamic>>> listExpenses({
    String? categoryFilter,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String? searchText,
    String? tagFilter,
    String? metadataFilter,
    String? accountId,
  }) async {
    final all = await _expenseHelper.list();
    return all.where((expense) {
      if (categoryFilter != null && expense['category'] != categoryFilter) return false;
      if (startDate != null && DateTime.parse(expense['dateTime'] as String).isBefore(startDate)) return false;
      if (endDate != null && DateTime.parse(expense['dateTime'] as String).isAfter(endDate)) return false;
      if (minAmount != null && (expense['amount'] as double) < minAmount) return false;
      if (maxAmount != null && (expense['amount'] as double) > maxAmount) return false;
      if (searchText != null && searchText.isNotEmpty) {
        if (!(expense['description'] as String? ?? '').toLowerCase().contains(searchText.toLowerCase())) return false;
      }
      if (tagFilter != null && tagFilter.isNotEmpty && (expense['tag'] as String? ?? '') != tagFilter) return false;
      if (metadataFilter != null && metadataFilter.isNotEmpty) {
        if (!(expense['metadata'] as String? ?? '').toLowerCase().contains(metadataFilter.toLowerCase())) return false;
      }
      if (accountId != null && accountId.isNotEmpty && expense['accountId'] != accountId) return false;
      return true;
    }).toList();
  }

  Future<void> updateExpense(String id, Map<String, dynamic> updates) async {
    await _expenseHelper.update(id, updates);
  }

  Future<void> deleteExpense(String id) async {
    await _addTombstone('expense', id);
    await _expenseHelper.delete(id);
  }

  // ==== Income Operations ====

  Future<void> createIncome(Map<String, dynamic> incomeData) async {
    _ensureTimestamps(incomeData);
    await _incomeHelper.create(incomeData);
  }

  Future<Map<String, dynamic>?> readIncome(String id) async {
    return _incomeHelper.read(id);
  }

  Future<List<Map<String, dynamic>>> listIncome({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final all = await _incomeHelper.list();
    return all.where((income) {
      if (startDate != null && DateTime.parse(income['dateTime'] as String).isBefore(startDate)) return false;
      if (endDate != null && DateTime.parse(income['dateTime'] as String).isAfter(endDate)) return false;
      return true;
    }).toList();
  }

  Future<void> updateIncome(String id, Map<String, dynamic> updates) async {
    await _incomeHelper.update(id, updates);
  }

  Future<void> deleteIncome(String id) async {
    await _addTombstone('income', id);
    await _incomeHelper.delete(id);
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
    _ensureTimestamps(loanData);
    await _loanHelper.create(loanData);
  }

  Future<Map<String, dynamic>?> readLoan(String id) async {
    return _loanHelper.read(id);
  }

  Future<List<Map<String, dynamic>>> listLoans() async {
    return _loanHelper.list();
  }

  Future<void> updateLoan(String id, Map<String, dynamic> updates) async {
    await _loanHelper.update(id, updates);
  }

  Future<void> deleteLoan(String id) async {
    await _addTombstone('loan', id);
    await _loanHelper.delete(id);
  }

  // ==== Investment Operations ====

  Future<void> createInvestment(Map<String, dynamic> investmentData) async {
    _ensureTimestamps(investmentData);
    await _investmentHelper.create(investmentData);
  }

  Future<Map<String, dynamic>?> readInvestment(String id) async {
    return _investmentHelper.read(id);
  }

  Future<List<Map<String, dynamic>>> listInvestments() async {
    return _investmentHelper.list();
  }

  Future<void> updateInvestment(String id, Map<String, dynamic> updates) async {
    await _investmentHelper.update(id, updates);
  }

  Future<void> deleteInvestment(String id) async {
    await _addTombstone('investment', id);
    await _investmentHelper.delete(id);
  }

  // ==== Recurring Rule Operations ====

  Future<void> createRecurringRule(Map<String, dynamic> ruleData) async {
    _ensureTimestamps(ruleData);
    await _recurringHelper.create(ruleData);
  }

  Future<Map<String, dynamic>?> readRecurringRule(String id) async {
    return _recurringHelper.read(id);
  }

  Future<List<Map<String, dynamic>>> listRecurringRules({String? type}) async {
    final all = await _recurringHelper.list();
    if (type == null) return all;
    return all.where((r) => r['type'] == type).toList();
  }

  Future<void> updateRecurringRule(String id, Map<String, dynamic> updates) async {
    await _recurringHelper.update(id, updates);
  }

  Future<void> deleteRecurringRule(String id) async {
    await _recurringHelper.delete(id);
  }

  /// Find active recurring rules whose nextDueDate is on or before today
  Future<List<Map<String, dynamic>>> getDueRecurringRules() async {
    final now = DateTime.now();
    final rules = await listRecurringRules(type: null);
    return rules.where((r) {
      if (r['status'] != 'active') return false;
      final nextDue = DateTime.tryParse(r['nextDueDate'] as String? ?? '');
      if (nextDue == null || nextDue.isAfter(now)) return false;
      final endDate = r['endDate'] as String?;
      if (endDate != null && endDate.isNotEmpty) {
        if (DateTime.tryParse(endDate)?.isBefore(now) == true) return false;
      }
      return true;
    }).toList();
  }

  /// Advance nextDueDate by the rule's frequency interval
  DateTime _advanceDate(DateTime from, String frequency, int interval) {
    switch (frequency) {
      case 'daily': return from.add(Duration(days: interval));
      case 'weekly': return from.add(Duration(days: 7 * interval));
      case 'monthly': return DateTime(from.year, from.month + interval, from.day);
      case 'yearly': return DateTime(from.year + interval, from.month, from.day);
      case 'custom': return from.add(Duration(days: interval));
      default: return from.add(Duration(days: 30));
    }
  }

  /// Process all due recurring rules and create corresponding records.
  /// Returns count of generated records.
  Future<int> processDueRecurringRules() async {
    final dueRules = await getDueRecurringRules();
    int created = 0;
    for (final rule in dueRules) {
      try {
        final ruleId = rule['id'] as String;
        final nextDue = DateTime.parse(rule['nextDueDate'] as String);
        final now = DateTime.now();

        // Create actual record
        final recordId = '${ruleId}_${nextDue.millisecondsSinceEpoch}';
        final recordData = <String, dynamic>{
          'id': recordId,
          'amount': rule['amount'],
          'category': rule['category'],
          'dateTime': nextDue.toIso8601String(),
          '_recurringRuleId': ruleId,
          'metadata': rule['metadata'] ?? '',
        };

        if (rule['type'] == 'expense') {
          recordData['description'] = rule['description'] ?? 'Recurring';
          await createExpense(recordData);
        } else {
          recordData['source'] = rule['description'] ?? 'Recurring Income';
          recordData['frequency'] = 'recurring';
          await createIncome(recordData);
        }

        // Advance nextDueDate
        final frequency = rule['frequency'] as String? ?? 'monthly';
        final interval = (rule['interval'] as num?)?.toInt() ?? 1;
        final advanced = _advanceDate(nextDue, frequency, interval);
        await updateRecurringRule(ruleId, {
          'nextDueDate': advanced.toIso8601String(),
          'lastCreatedAt': now.toIso8601String(),
        });
        created++;
      } catch (_) {}
    }
    return created;
  }

  /// Get upcoming recurring items (next N due dates without creating records)
  Future<List<Map<String, dynamic>>> getUpcomingRecurring({int count = 5}) async {
    final rules = await listRecurringRules();
    final active = rules.where((r) => r['status'] == 'active').toList();
    final upcoming = <Map<String, dynamic>>[];
    for (final rule in active) {
      final nextDueStr = rule['nextDueDate'] as String?;
      final endDateStr = rule['endDate'] as String?;
      if (nextDueStr == null || nextDueStr.isEmpty) continue;
      var cursor = DateTime.parse(nextDueStr);
      final end = endDateStr != null && endDateStr.isNotEmpty ? DateTime.tryParse(endDateStr) : null;
      if (end != null && cursor.isAfter(end)) continue;

      final frequency = rule['frequency'] as String? ?? 'monthly';
      final interval = (rule['interval'] as num?)?.toInt() ?? 1;

      // Generate upcoming dates (up to count per rule)
      for (int i = 0; i < count; i++) {
        if (end != null && cursor.isAfter(end)) break;
        if (cursor.isBefore(DateTime.now()) && i == 0) {
          // If the current nextDueDate is in the past, advance one period
          cursor = _advanceDate(cursor, frequency, interval);
          if (end != null && cursor.isAfter(end)) break;
        }
        upcoming.add({
          'ruleId': rule['id'],
          'type': rule['type'],
          'amount': rule['amount'],
          'category': rule['category'],
          'description': rule['description'],
          'nextDueDate': cursor.toIso8601String(),
          'frequency': frequency,
        });
        cursor = _advanceDate(cursor, frequency, interval);
        if (end != null && cursor.isAfter(end)) break;
      }
    }
    // Sort by nextDueDate
    upcoming.sort((a, b) {
      final da = DateTime.parse(a['nextDueDate'] as String);
      final db = DateTime.parse(b['nextDueDate'] as String);
      return da.compareTo(db);
    });
    return upcoming.take(count).toList();
  }

  // ==== Account Operations ====

  Future<void> createAccount(Map<String, dynamic> accountData) async {
    _ensureTimestamps(accountData);
    await _accountHelper.create(accountData);
  }

  Future<Map<String, dynamic>?> readAccount(String id) async {
    return _accountHelper.read(id);
  }

  Future<List<Map<String, dynamic>>> listAccounts() async {
    return _accountHelper.list();
  }

  Future<void> updateAccount(String id, Map<String, dynamic> updates) async {
    await _accountHelper.update(id, updates);
  }

  Future<void> deleteAccount(String id) async {
    await _accountHelper.delete(id);
  }

  // ==== Transfer Operations ====

  Future<void> createTransfer(Map<String, dynamic> transferData) async {
    _ensureTimestamps(transferData);
    await _transferHelper.create(transferData);

    // Update balances
    final fromAccount = await readAccount(transferData['fromAccountId'] as String);
    final toAccount = await readAccount(transferData['toAccountId'] as String);
    if (fromAccount != null) {
      final fromBal = (fromAccount['balance'] as num?)?.toDouble() ?? 0;
      final amt = (transferData['amount'] as num).toDouble();
      await updateAccount(transferData['fromAccountId'] as String, {
        'balance': fromBal - amt,
      });
    }
    if (toAccount != null) {
      final toBal = (toAccount['balance'] as num?)?.toDouble() ?? 0;
      final amt = (transferData['amount'] as num).toDouble();
      await updateAccount(transferData['toAccountId'] as String, {
        'balance': toBal + amt,
      });
    }
  }

  Future<List<Map<String, dynamic>>> listTransfers() async {
    return _transferHelper.list();
  }

  // ==== Category Budget Operations ====

  Future<void> setCategoryBudget(String category, double amount) async {
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: 'cat_budget_$category',
      deviceId: _deviceId,
      payload: {'category': category, 'amount': amount, 'month': '${DateTime.now().year}_${DateTime.now().month}'},
      wrappingKey: _wrappingKey,
      metadata: {'type': 'category_budget', 'userId': _userId},
    );
    await _appSettingsDb.put('cat_budget_$category', jsonEncode(envelope.toJson()));
  }

  Future<double> getCategoryBudget(String category) async {
    final val = _appSettingsDb.get('cat_budget_$category');
    if (val == null) return 0;
    try {
      final envelope = EncryptionEnvelope.fromJson(jsonDecode(val) as Map<String, dynamic>);
      final data = await EnvelopeEncryption.decrypt(envelope: envelope, wrappingKey: _wrappingKey);
      return (data['amount'] as num?)?.toDouble() ?? 0;
    } catch (_) { return 0; }
  }

  Future<Map<String, double>> getAllCategoryBudgets() async {
    final result = <String, double>{};
    for (final key in _appSettingsDb.keys) {
      if (!key.startsWith('cat_budget_')) continue;
      try {
        final envelope = EncryptionEnvelope.fromJson(
          jsonDecode(_appSettingsDb.get(key)!) as Map<String, dynamic>,
        );
        final data = await EnvelopeEncryption.decrypt(envelope: envelope, wrappingKey: _wrappingKey);
        final cat = data['category'] as String?;
        final amt = (data['amount'] as num?)?.toDouble() ?? 0;
        if (cat != null && cat.isNotEmpty) result[cat] = amt;
      } catch (_) {}
    }
    return result;
  }

  // ==== Loan Repayment Operations ====

  Future<void> addLoanRepayment(Map<String, dynamic> repaymentData) async {
    _ensureTimestamps(repaymentData);
    await _loanRepaymentHelper.create(repaymentData);

    // Update loan outstanding balance
    final loanId = repaymentData['loanId'] as String;
    final loan = await readLoan(loanId);
    if (loan != null) {
      final outstanding = (loan['outstandingBalance'] as num?)?.toDouble() ?? (loan['amount'] as num?)?.toDouble() ?? 0;
      final paid = (repaymentData['amount'] as num).toDouble();
      final repayments = (loan['repaymentHistory'] as List<dynamic>?) ?? [];
      repayments.add(repaymentData);
      await updateLoan(loanId, {
        'outstandingBalance': outstanding - paid,
        'repaymentHistory': repayments,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getLoanRepayments(String loanId) async {
    final all = await _loanRepaymentHelper.list();
    final repayments = all.where((r) => r['loanId'] == loanId).toList();
    repayments.sort((a, b) {
      final da = DateTime.tryParse(a['dateTime'] as String? ?? '');
      final db = DateTime.tryParse(b['dateTime'] as String? ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return repayments;
  }

  // ==== Category Operations ====

  Future<void> createCategory(Map<String, dynamic> categoryData) async {
    _ensureTimestamps(categoryData);
    await _categoryHelper.create(categoryData);
  }

  Future<Map<String, dynamic>?> readCategory(String id) async {
    return _categoryHelper.read(id);
  }

  Future<List<Map<String, dynamic>>> listCategories({String? type}) async {
    final all = await _categoryHelper.list();
    if (type == null) return all;
    return all.where((c) => c['type'] == type).toList();
  }

  Future<void> updateCategory(String id, Map<String, dynamic> updates) async {
    await _categoryHelper.update(id, updates);
  }

  Future<void> deleteCategory(String id) async {
    await _categoryHelper.delete(id);
  }

  Map<String, dynamic> _ensureTimestamps(Map<String, dynamic> data) {
    final now = DateTime.now().toUtc().toIso8601String();
    if (data['createdAt'] == null || (data['createdAt'] as String).isEmpty) {
      data['createdAt'] = now;
    }
    data['updatedAt'] = now;
    return data;
  }

  /// Get pending sync items
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

  Future<void> markAllPendingSyncItemsCompleted() async {
    final keys = _syncQueueDb.keys.toList();
    for (final key in keys) {
      final item = _syncQueueDb.get(key);
      if (item != null && item['status'] == 'pending') {
        item['status'] = 'synced';
        await _syncQueueDb.put(key, item);
      }
    }
  }

  Future<int> getPendingSyncCount() async {
    return _syncQueueDb.values
        .where((item) => item['status'] == 'pending')
        .length;
  }

  // ==== Tombstone Operations ====

  Future<void> _addTombstone(String recordType, String recordId) async {
    await _tombstonesDb.put(recordId, jsonEncode({
      'id': recordId,
      'recordType': recordType,
      'deletedAt': DateTime.now().toUtc().toIso8601String(),
    }));
  }

  Future<List<Map<String, dynamic>>> getTombstones() async {
    return _tombstonesDb.values
        .map((v) => jsonDecode(v) as Map<String, dynamic>)
        .toList();
  }

  Future<Set<String>> getTombstonedIds() async {
    return _tombstonesDb.keys.cast<String>().toSet();
  }

  Future<void> removeTombstone(String recordId) async {
    await _tombstonesDb.delete(recordId);
  }

  Future<void> clearSyncedTombstones(Set<String> syncedIds) async {
    for (final id in syncedIds) {
      await _tombstonesDb.delete(id);
    }
  }

  // ==== Conflict Operations ====

  Future<List<Map<String, dynamic>>> getConflicts() async {
    final conflicts = <Map<String, dynamic>>[];
    for (final key in _conflictsDb.keys) {
      try {
        final envelope = EncryptionEnvelope.fromJson(
          jsonDecode(_conflictsDb.get(key)!) as Map<String, dynamic>,
        );
        final data = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: _wrappingKey,
        );
        conflicts.add(data);
      } catch (_) {}
    }
    return conflicts;
  }

  Future<int> getConflictCount() async {
    return _conflictsDb.length;
  }

  /// Resolve a conflict by choosing which version to keep.
  Future<void> resolveConflict(String conflictId, String choice) async {
    final conflictJson = _conflictsDb.get(conflictId);
    if (conflictJson == null) return;
    try {
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(conflictJson) as Map<String, dynamic>,
      );
      if (choice == 'cloud') {
        final data = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: _wrappingKey,
        );
        final recordType = data['_recordType'] as String? ?? 'expense';
        switch (recordType) {
          case 'expense': await createExpense(data); break;
          case 'income': await createIncome(data); break;
          case 'loan': await createLoan(data); break;
          case 'investment': await createInvestment(data); break;
        }
      }
      await _conflictsDb.delete(conflictId);
    } catch (_) {}
  }

  Future<void> storeConflict(EncryptionEnvelope envelope) async {
    await _conflictsDb.put(envelope.recordId, jsonEncode(envelope.toJson()));
  }

  // ==== Seed Default Categories ====

  static const Map<String, List<Map<String, dynamic>>> defaultCategories = {
    'expense': [
      {'name': 'Food & Dining', 'color': 0xFFFB7185, 'tags': ['Meals', 'Snacks', 'Groceries', 'Zomato/Swiggy']},
      {'name': 'Fuel', 'color': 0xFFF97316, 'tags': ['Petrol', 'Diesel', 'CNG', 'EV Charging', 'Full Tank', 'Top-up']},
      {'name': 'Transport', 'color': 0xFF60A5FA, 'tags': ['Bus/Train', 'Auto/Taxi', 'Metro']},
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
      {'name': 'Vehicle Maintenance', 'color': 0xFF10B981, 'tags': ['Regular Service', 'Repair', 'Puncture', 'Battery', 'Tyre Change', 'Insurance']},
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
      final existingIds = existing.map((c) => c['id'] as String?).toSet();
      final defaults = defaultCategories[t] ?? [];
      for (final cat in defaults) {
        final id = '${t}_${cat['name']}'.replaceAll(' ', '_').replaceAll('&', 'and');
        if (existingIds.contains(id)) continue;
        await createCategory({
          'id': id,
          'name': cat['name'],
          'type': t,
          'color': cat['color'],
          'tags': cat['tags'],
        });
      }
    }
  }

  // ==== App Settings (budget, preferences) ====

  Future<double> getMonthlyBudget() async {
    final val = _appSettingsDb.get('monthly_budget');
    if (val == null) return 0;
    try {
      final envelope = EncryptionEnvelope.fromJson(
        jsonDecode(val) as Map<String, dynamic>,
      );
      final data = await EnvelopeEncryption.decrypt(
        envelope: envelope,
        wrappingKey: _wrappingKey,
      );
      return (data['amount'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setMonthlyBudget(double amount) async {
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: 'monthly_budget',
      deviceId: _deviceId,
      payload: {'amount': amount},
      wrappingKey: _wrappingKey,
      metadata: {'type': 'settings', 'userId': _userId},
    );
    await _appSettingsDb.put('monthly_budget', jsonEncode(envelope.toJson()));
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
    await _appSettingsDb.clear();
    await _tombstonesDb.clear();
    await _recurringRulesDb.clear();
    await _accountsDb.clear();
    await _transfersDb.clear();
    await _loanRepaymentsDb.clear();
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
    await _appSettingsDb.close();
    await _tombstonesDb.close();
    await _recurringRulesDb.close();
    await _accountsDb.close();
    await _transfersDb.close();
    await _loanRepaymentsDb.close();
  }
}

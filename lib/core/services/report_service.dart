import 'dart:collection';
import 'package:intl/intl.dart';
import '../database/local_database.dart';

class CategorySummary {
  final String category;
  final double totalAmount;
  final int transactionCount;
  final double percentage;
  CategorySummary({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });
}

class TagSummary {
  final String tag;
  final double totalAmount;
  final int transactionCount;
  TagSummary({required this.tag, required this.totalAmount, required this.transactionCount});
}

class MonthlyTrend {
  final String label;
  final DateTime sortKey;
  final double income;
  final double expense;
  final double netSavings;
  final double investment;
  MonthlyTrend({
    required this.label,
    required this.sortKey,
    this.income = 0,
    this.expense = 0,
    this.netSavings = 0,
    this.investment = 0,
  });
}

class BudgetAnalysis {
  final String category;
  final double budget;
  final double actualSpending;
  final double remaining;
  final String status;
  BudgetAnalysis({
    required this.category,
    required this.budget,
    required this.actualSpending,
    required this.remaining,
    required this.status,
  });
}

class ReportData {
  final DateTime startDate;
  final DateTime endDate;
  final String userId;

  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> incomes = [];
  List<Map<String, dynamic>> loans = [];
  List<Map<String, dynamic>> investments = [];

  double totalIncome = 0;
  double totalExpenses = 0;
  double netSavings = 0;
  double savingsRate = 0;
  double totalInvested = 0;
  double totalLoans = 0;
  double monthlyBudget = 0;
  double actualSpending = 0;
  double budgetUsedPercent = 0;

  List<CategorySummary> categorySummary = [];
  List<TagSummary> tagSummary = [];
  List<MonthlyTrend> monthlyTrend = [];
  List<BudgetAnalysis> budgetAnalysis = [];

  ReportData({
    required this.startDate,
    required this.endDate,
    required this.userId,
  });
}

class ReportService {
  final LocalDatabaseService db;

  ReportService(this.db);

  Future<ReportData> generateReport({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final data = ReportData(
      startDate: startDate,
      endDate: endDate,
      userId: userId ?? '',
    );

    final results = await Future.wait([
      db.listExpenses(startDate: startDate, endDate: endOfDay),
      db.listIncome(startDate: startDate, endDate: endOfDay),
      db.listLoans(),
      db.listInvestments(),
      db.getMonthlyBudget(),
    ]);

    data.expenses = results[0] as List<Map<String, dynamic>>;
    data.incomes = results[1] as List<Map<String, dynamic>>;
    data.loans = results[2] as List<Map<String, dynamic>>;
    data.investments = results[3] as List<Map<String, dynamic>>;
    data.monthlyBudget = results[4] as double;

    _filterLoansByDate(data);
    _filterInvestmentsByDate(data);

    _computeSummaries(data);
    _computeCategorySummary(data);
    _computeTagSummary(data);
    _computeMonthlyTrend(data);
    _computeBudgetAnalysis(data);

    return data;
  }

  void _filterLoansByDate(ReportData data) {
    data.loans = data.loans.where((l) {
      final dt = _safeParseDateTime(l['dateTime']);
      return dt != null && !dt.isBefore(data.startDate) && !dt.isAfter(data.endDate);
    }).toList();
  }

  void _filterInvestmentsByDate(ReportData data) {
    data.investments = data.investments.where((inv) {
      final dt = _safeParseDateTime(inv['dateTime']);
      return dt != null && !dt.isBefore(data.startDate) && !dt.isAfter(data.endDate);
    }).toList();
  }

  void _computeSummaries(ReportData data) {
    for (final e in data.expenses) {
      data.totalExpenses += _safeToDouble(e['amount']);
    }
    for (final i in data.incomes) {
      data.totalIncome += _safeToDouble(i['amount']);
    }
    for (final inv in data.investments) {
      data.totalInvested += _safeToDouble(inv['amount']);
    }
    for (final l in data.loans) {
      data.totalLoans += _safeToDouble(l['amount']);
    }

    data.netSavings = data.totalIncome - data.totalExpenses;
    data.savingsRate = data.totalIncome > 0
        ? ((data.netSavings / data.totalIncome) * 100).clamp(0, 100)
        : 0;

    data.actualSpending = data.totalExpenses;
    data.budgetUsedPercent = data.monthlyBudget > 0
        ? ((data.actualSpending / data.monthlyBudget) * 100).clamp(0, 999)
        : 0;
  }

  void _computeCategorySummary(ReportData data) {
    final catTotals = <String, double>{};
    final catCounts = <String, int>{};

    for (final e in data.expenses) {
      final cat = e['category'] as String? ?? 'Other';
      catTotals[cat] = (catTotals[cat] ?? 0) + _safeToDouble(e['amount']);
      catCounts[cat] = (catCounts[cat] ?? 0) + 1;
    }

    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sorted) {
      final pct = data.totalExpenses > 0
          ? (entry.value / data.totalExpenses * 100)
          : 0.0;
      data.categorySummary.add(CategorySummary(
        category: entry.key,
        totalAmount: entry.value,
        transactionCount: catCounts[entry.key] ?? 0,
        percentage: pct,
      ));
    }
  }

  void _computeTagSummary(ReportData data) {
    final tagTotals = <String, double>{};
    final tagCounts = <String, int>{};

    for (final e in data.expenses) {
      final rawTag = e['tag'] as String?;
      if (rawTag == null || rawTag.isEmpty) continue;
      final tags = rawTag.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
      for (final tag in tags) {
        tagTotals[tag] = (tagTotals[tag] ?? 0) + _safeToDouble(e['amount']);
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    final sorted = tagTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sorted) {
      data.tagSummary.add(TagSummary(
        tag: entry.key,
        totalAmount: entry.value,
        transactionCount: tagCounts[entry.key] ?? 0,
      ));
    }
  }

  void _computeMonthlyTrend(ReportData data) {
    final monthMap = LinkedHashMap<String, _MonthAccumulator>();

    for (final e in data.expenses) {
      final dt = _safeParseDateTime(e['dateTime']);
      if (dt == null) continue;
      final key = DateFormat('MMM yy').format(dt);
      final sortKey = DateTime(dt.year, dt.month);
      monthMap.putIfAbsent(key, () => _MonthAccumulator(sortKey: sortKey));
      monthMap[key]!.expense += _safeToDouble(e['amount']);
    }

    for (final i in data.incomes) {
      final dt = _safeParseDateTime(i['dateTime']);
      if (dt == null) continue;
      final key = DateFormat('MMM yy').format(dt);
      final sortKey = DateTime(dt.year, dt.month);
      monthMap.putIfAbsent(key, () => _MonthAccumulator(sortKey: sortKey));
      monthMap[key]!.income += _safeToDouble(i['amount']);
    }

    for (final inv in data.investments) {
      final dt = _safeParseDateTime(inv['dateTime']);
      if (dt == null) continue;
      final key = DateFormat('MMM yy').format(dt);
      final sortKey = DateTime(dt.year, dt.month);
      monthMap.putIfAbsent(key, () => _MonthAccumulator(sortKey: sortKey));
      monthMap[key]!.investment += _safeToDouble(inv['amount']);
    }

    final sorted = monthMap.entries.toList()
      ..sort((a, b) => a.value.sortKey.compareTo(b.value.sortKey));

    for (final entry in sorted) {
      final acc = entry.value;
      data.monthlyTrend.add(MonthlyTrend(
        label: entry.key,
        sortKey: acc.sortKey,
        income: acc.income,
        expense: acc.expense,
        netSavings: acc.income - acc.expense,
        investment: acc.investment,
      ));
    }
  }

  void _computeBudgetAnalysis(ReportData data) {
    if (data.monthlyBudget <= 0) return;

    final catSpending = <String, double>{};
    for (final e in data.expenses) {
      final cat = e['category'] as String? ?? 'Other';
      catSpending[cat] = (catSpending[cat] ?? 0) + _safeToDouble(e['amount']);
    }

    final totalSpending = catSpending.values.fold(0.0, (a, b) => a + b);
    final totalRemaining = data.monthlyBudget - totalSpending;

    data.budgetAnalysis.add(BudgetAnalysis(
      category: 'Overall Budget',
      budget: data.monthlyBudget,
      actualSpending: totalSpending,
      remaining: totalRemaining,
      status: totalRemaining >= 0 ? 'Under Budget' : 'Over Budget',
    ));
  }

  DateTime? _safeParseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0;
  }
}

class _MonthAccumulator {
  final DateTime sortKey;
  double income = 0;
  double expense = 0;
  double investment = 0;
  _MonthAccumulator({required this.sortKey});
}

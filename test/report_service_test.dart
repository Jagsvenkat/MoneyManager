import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:money_manager/core/services/report_service.dart';
import 'package:money_manager/core/database/local_database.dart';

class MockDatabase extends Mock implements LocalDatabaseService {}

void main() {
  late MockDatabase db;
  late ReportService reportService;

  setUp(() {
    db = MockDatabase();
    reportService = ReportService(db);

    when(() => db.listLoans()).thenAnswer((_) async => []);
    when(() => db.listInvestments()).thenAnswer((_) async => []);
    when(() => db.getMonthlyBudget()).thenAnswer((_) async => 0.0);
  });

  group('ReportService.generateReport', () {
    test('returns ReportData with correct date range', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);

      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 12, 31);
      final data = await reportService.generateReport(startDate: start, endDate: end);

      expect(data.startDate, start);
      expect(data.endDate, end);
    });

    test('computes total income correctly', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 50000, 'dateTime': '2025-06-15T10:00:00'},
            {'amount': 25000, 'dateTime': '2025-06-20T10:00:00'},
          ]);

      final data = await reportService.generateReport(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 12, 31));

      expect(data.totalIncome, closeTo(75000, 0.01));
    });

    test('computes total expenses and net savings', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 1000, 'category': 'Food', 'dateTime': '2025-06-10T12:00:00'},
            {'amount': 2000, 'category': 'Transport', 'dateTime': '2025-06-11T12:00:00'},
          ]);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 10000, 'dateTime': '2025-06-01T10:00:00'},
          ]);

      final data = await reportService.generateReport(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 12, 31));

      expect(data.totalExpenses, closeTo(3000, 0.01));
      expect(data.netSavings, closeTo(7000, 0.01));
      expect(data.savingsRate, closeTo(70, 0.01));
    });

    test('computes category summary sorted by amount descending', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 500, 'category': 'Food', 'dateTime': '2025-06-10T12:00:00', 'tag': ''},
            {'amount': 1500, 'category': 'Rent', 'dateTime': '2025-06-01T12:00:00', 'tag': ''},
            {'amount': 300, 'category': 'Food', 'dateTime': '2025-06-15T12:00:00', 'tag': ''},
          ]);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);

      final data = await reportService.generateReport(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 12, 31));

      expect(data.categorySummary.length, 2);
      expect(data.categorySummary[0].category, 'Rent');
      expect(data.categorySummary[0].totalAmount, closeTo(1500, 0.01));
      expect(data.categorySummary[0].transactionCount, 1);
      expect(data.categorySummary[1].category, 'Food');
      expect(data.categorySummary[1].totalAmount, closeTo(800, 0.01));
      expect(data.categorySummary[1].transactionCount, 2);
    });

    test('computes tag summary correctly', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 100, 'category': 'Food', 'tag': 'groceries', 'dateTime': '2025-06-10T12:00:00'},
            {'amount': 200, 'category': 'Food', 'tag': 'groceries,weekly', 'dateTime': '2025-06-15T12:00:00'},
            {'amount': 50, 'category': 'Transport', 'tag': 'daily', 'dateTime': '2025-06-12T12:00:00'},
          ]);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);

      final data = await reportService.generateReport(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 12, 31));

      expect(data.tagSummary.any((t) => t.tag == 'groceries'), isTrue);
      expect(data.tagSummary.any((t) => t.tag == 'weekly'), isTrue);
      expect(data.tagSummary.any((t) => t.tag == 'daily'), isTrue);

      final groceries = data.tagSummary.firstWhere((t) => t.tag == 'groceries');
      expect(groceries.totalAmount, closeTo(300, 0.01));
      expect(groceries.transactionCount, 2);
    });

    test('computes monthly trend with correct sorting', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 100, 'category': 'Food', 'dateTime': '2025-06-10T12:00:00'},
            {'amount': 200, 'category': 'Food', 'dateTime': '2025-05-05T12:00:00'},
          ]);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 5000, 'dateTime': '2025-05-01T10:00:00'},
          ]);

      final data = await reportService.generateReport(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 12, 31));

      expect(data.monthlyTrend.length, 2);
      expect(data.monthlyTrend[0].label, 'May 25');
      expect(data.monthlyTrend[0].expense, closeTo(200, 0.01));
      expect(data.monthlyTrend[0].income, closeTo(5000, 0.01));
      expect(data.monthlyTrend[1].label, 'Jun 25');
    });

    test('includes loans and investments within date range', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);
      when(() => db.listLoans()).thenAnswer((_) async => [
        {'amount': 10000, 'dateTime': '2025-06-15T10:00:00', 'personName': 'John'},
        {'amount': 5000, 'dateTime': '2024-06-15T10:00:00', 'personName': 'Jane'},
      ]);
      when(() => db.listInvestments()).thenAnswer((_) async => [
        {'amount': 20000, 'dateTime': '2025-06-10T10:00:00', 'name': 'Stock A'},
        {'amount': 3000, 'dateTime': '2024-12-01T10:00:00', 'name': 'Bond B'},
      ]);
      when(() => db.getMonthlyBudget()).thenAnswer((_) async => 0.0);

      final data = await reportService.generateReport(
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
      );

      expect(data.loans.length, 1);
      expect(data.totalLoans, closeTo(10000, 0.01));
      expect(data.investments.length, 1);
      expect(data.totalInvested, closeTo(20000, 0.01));
    });

    test('budget analysis shows over budget status', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 30000, 'category': 'Food', 'dateTime': '2025-06-10T12:00:00'},
          ]);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);
      when(() => db.getMonthlyBudget()).thenAnswer((_) async => 25000.0);

      final data = await reportService.generateReport(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 12, 31));

      expect(data.budgetAnalysis.length, 1);
      expect(data.budgetAnalysis[0].status, 'Over Budget');
      expect(data.budgetAnalysis[0].budget, closeTo(25000, 0.01));
      expect(data.budgetAnalysis[0].actualSpending, closeTo(30000, 0.01));
      expect(data.budgetAnalysis[0].remaining, closeTo(-5000, 0.01));
    });

    test('computes category percentages relative to total expenses', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => [
            {'amount': 7500, 'category': 'Food', 'dateTime': '2025-06-10T12:00:00'},
            {'amount': 2500, 'category': 'Transport', 'dateTime': '2025-06-11T12:00:00'},
          ]);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);

      final data = await reportService.generateReport(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 12, 31));

      expect(data.categorySummary.firstWhere((c) => c.category == 'Food').percentage, closeTo(75, 0.01));
      expect(data.categorySummary.firstWhere((c) => c.category == 'Transport').percentage, closeTo(25, 0.01));
    });

    test('handles empty datasets gracefully', () async {
      when(() => db.listExpenses(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);
      when(() => db.listIncome(startDate: any(named: 'startDate'), endDate: any(named: 'endDate')))
          .thenAnswer((_) async => []);

      final data = await reportService.generateReport(startDate: DateTime(2025, 1, 1), endDate: DateTime(2025, 12, 31));

      expect(data.totalIncome, 0);
      expect(data.totalExpenses, 0);
      expect(data.netSavings, 0);
      expect(data.savingsRate, 0);
      expect(data.categorySummary, isEmpty);
      expect(data.tagSummary, isEmpty);
      expect(data.monthlyTrend, isEmpty);
      expect(data.budgetAnalysis, isEmpty);
    });
  });
}

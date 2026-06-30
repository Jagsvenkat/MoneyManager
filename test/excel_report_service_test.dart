import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:money_manager/core/services/report_service.dart';
import 'package:money_manager/core/services/excel_report_service.dart';

ReportData _sampleData() {
  final data = ReportData(
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 12, 31),
    userId: 'user-1',
  );

  data.expenses = [
    {'dateTime': '2025-06-10T12:00:00', 'category': 'Food', 'tag': 'groceries', 'description': 'Weekly groceries', 'amount': 2500.0},
    {'dateTime': '2025-06-15T12:00:00', 'category': 'Rent', 'tag': '', 'description': 'June rent', 'amount': 12000.0},
    {'dateTime': '2025-07-05T12:00:00', 'category': 'Food', 'tag': 'groceries', 'description': 'Monthly stock', 'amount': 3000.0},
  ];

  data.incomes = [
    {'dateTime': '2025-06-01T10:00:00', 'source': 'Salary', 'amount': 50000.0},
    {'dateTime': '2025-07-01T10:00:00', 'source': 'Salary', 'amount': 50000.0},
  ];

  data.loans = [
    {'dateTime': '2025-06-20T10:00:00', 'personName': 'John', 'loanType': 'personal', 'amount': 5000.0},
  ];

  data.investments = [
    {'dateTime': '2025-06-05T10:00:00', 'name': 'Stock A', 'type': 'equity', 'units': 10, 'pricePerUnit': 150.0, 'amount': 1500.0},
  ];

  data.totalIncome = 100000;
  data.totalExpenses = 17500;
  data.netSavings = 82500;
  data.savingsRate = 82.5;
  data.totalInvested = 1500;
  data.totalLoans = 5000;
  data.monthlyBudget = 30000;
  data.actualSpending = 17500;
  data.budgetUsedPercent = 58.33;

  data.categorySummary = [
    CategorySummary(category: 'Food', totalAmount: 5500, transactionCount: 2, percentage: 31.43),
    CategorySummary(category: 'Rent', totalAmount: 12000, transactionCount: 1, percentage: 68.57),
  ];

  data.tagSummary = [
    TagSummary(tag: 'groceries', totalAmount: 5500, transactionCount: 2),
  ];

  data.monthlyTrend = [
    MonthlyTrend(label: 'Jun 25', sortKey: DateTime(2025, 6), income: 50000, expense: 19500, netSavings: 30500, investment: 1500),
    MonthlyTrend(label: 'Jul 25', sortKey: DateTime(2025, 7), income: 50000, expense: 3000, netSavings: 47000, investment: 0),
  ];

  data.budgetAnalysis = [
    BudgetAnalysis(category: 'Overall Budget', budget: 30000, actualSpending: 17500, remaining: 12500, status: 'Under Budget'),
  ];

  return data;
}

void main() {
  group('ExcelReportService', () {
    test('generates workbook with default options', () {
      final service = ExcelReportService();
      final data = _sampleData();

      final bytes = service.generateWorkbook(data);

      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
    });

    test('generated workbook can be decoded by excel package', () {
      final service = ExcelReportService();
      final data = _sampleData();

      final bytes = service.generateWorkbook(data);

      final excel = Excel.decodeBytes(bytes!);
      expect(excel.sheets.values, isNotEmpty);
    });

    test('includes Summary sheet', () {
      final service = ExcelReportService();
      final data = _sampleData();

      final bytes = service.generateWorkbook(data);
      final excel = Excel.decodeBytes(bytes!);

      expect(excel.sheets.containsKey('Summary'), isTrue);
    });

    test('includes Expenses, Income, Loans, Investments sheets by default', () {
      final service = ExcelReportService();
      final data = _sampleData();

      final bytes = service.generateWorkbook(data);
      final excel = Excel.decodeBytes(bytes!);

      expect(excel.sheets.containsKey('Expenses'), isTrue);
      expect(excel.sheets.containsKey('Income'), isTrue);
      expect(excel.sheets.containsKey('Loans'), isTrue);
      expect(excel.sheets.containsKey('Investments'), isTrue);
    });

    test('includes Category Report and Monthly Trend sheets', () {
      final service = ExcelReportService();
      final data = _sampleData();

      final bytes = service.generateWorkbook(data);
      final excel = Excel.decodeBytes(bytes!);

      expect(excel.sheets.containsKey('Category Report'), isTrue);
      expect(excel.sheets.containsKey('Monthly Trend'), isTrue);
    });

    test('includes Tags and Budget Analysis sheets with fullWorkbook option', () {
      final service = ExcelReportService();
      final data = _sampleData();

      final bytes = service.generateWorkbook(data, options: const ExportOptions(
        fullWorkbook: true,
        includeRawTransactions: true,
      ));
      final excel = Excel.decodeBytes(bytes!);

      expect(excel.sheets.containsKey('Tags'), isTrue);
      expect(excel.sheets.containsKey('Budget Analysis'), isTrue);
    });

    test('handles data with no transactions gracefully', () {
      final service = ExcelReportService();
      final emptyData = ReportData(
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
        userId: 'user-1',
      );

      final bytes = service.generateWorkbook(emptyData);
      expect(bytes, isNotNull);
    });

    test('Includes budget analysis in full workbook when budget data exists', () {
      final service = ExcelReportService();
      final data = _sampleData();

      final bytes = service.generateWorkbook(data, options: const ExportOptions(
        fullWorkbook: true,
        includeRawTransactions: true,
      ));
      final excel = Excel.decodeBytes(bytes!);

      expect(excel.sheets.containsKey('Budget Analysis'), isTrue);
      final sheet = excel.sheets['Budget Analysis']!;
      expect(sheet.rows.length, greaterThan(0));
    });

    test('Expenses sheet has header row', () {
      final service = ExcelReportService();
      final data = _sampleData();

      final bytes = service.generateWorkbook(data);
      final excel = Excel.decodeBytes(bytes!);
      final sheet = excel.sheets['Expenses']!;

      expect(sheet.rows.length, greaterThanOrEqualTo(2));
      expect(sheet.rows[0][0]?.value.toString(), 'Date');
    });
  });
}

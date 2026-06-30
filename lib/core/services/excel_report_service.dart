import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'report_service.dart';

class ExportOptions {
  final bool fullWorkbook;
  final bool includeRawTransactions;
  final bool includeMetadata;

  const ExportOptions({
    this.fullWorkbook = true,
    this.includeRawTransactions = true,
    this.includeMetadata = false,
  });
}

class ExcelReportService {
  static const String appName = 'SJsaver';
  static const String primaryHex = 'FF2DD4BF';
  static const String darkBgHex = 'FF0F1115';
  static const String surfaceHex = 'FF161A22';
  static const String headerBgHex = 'FF1E2430';
  static const String headerTextHex = 'FFE2E8F0';
  static const String textPrimaryHex = 'FF000000';
  static const String textSecondaryHex = 'FF000000';
  static const String successHex = 'FF34D399';
  static const String errorHex = 'FFFB7185';
  static const String warningHex = 'FFFBBF24';
  static const String infoHex = 'FF60A5FA';
  static const String altRowHex = 'FF1A1F2E';

  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFmt = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFmt = NumberFormat('##,##0.00');

  List<int>? generateWorkbook(ReportData data, {ExportOptions? options}) {
    final opts = options ?? const ExportOptions();
    final excel = Excel.createExcel();

    _buildSummarySheet(excel, data);
    if (opts.includeRawTransactions) {
      _buildExpensesSheet(excel, data);
      _buildIncomeSheet(excel, data);
      _buildLoansSheet(excel, data);
      _buildInvestmentsSheet(excel, data);
    }
    _buildCategoryReportSheet(excel, data);
    _buildMonthlyTrendSheet(excel, data);

    if (opts.fullWorkbook && opts.includeRawTransactions) {
      _buildTagSummarySheet(excel, data);
      _buildBudgetAnalysisSheet(excel, data);
    }

    excel.setDefaultSheet('Summary');
    return excel.encode();
  }

  // ── Summary Sheet ──

  void _buildSummarySheet(Excel excel, ReportData data) {
    final sheet = excel['Summary'];
    final nowStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
    final periodStr =
        '${_displayDateFmt.format(data.startDate)} — ${_displayDateFmt.format(data.endDate)}';

    int r = 0;
    _mergeAndStyle(sheet, r, 0, r, 3, '$appName — Financial Report',
        bold: true, fontSize: 18, bgHex: primaryHex, fontHex: 'FF003731');
    r++;
    _mergeAndStyle(sheet, r, 0, r, 3, 'Period: $periodStr',
        fontSize: 12, fontHex: textPrimaryHex);
    r++;
    _mergeAndStyle(sheet, r, 0, r, 3, 'Generated: $nowStr',
        fontSize: 11, fontHex: textSecondaryHex);
    if (data.userId.isNotEmpty) {
      r++;
      _mergeAndStyle(sheet, r, 0, r, 3, 'User: ${data.userId}',
          fontSize: 11, fontHex: textSecondaryHex);
    }
    r += 2;

    final savingsRateStr = data.totalIncome > 0
        ? '${data.savingsRate.toStringAsFixed(1)}%'
        : 'N/A';
    final netStr = '₹${_formatCurrency(data.netSavings)}';
    final netColor = data.netSavings >= 0 ? successHex : errorHex;

    final kpiRows = [
      ['Total Income', '₹${_formatCurrency(data.totalIncome)}', successHex, ''],
      ['Total Expenses', '₹${_formatCurrency(data.totalExpenses)}', errorHex, ''],
      ['Net Savings', netStr, netColor, ''],
      ['Savings Rate', savingsRateStr, infoHex, ''],
      ['Total Invested', '₹${_formatCurrency(data.totalInvested)}', infoHex, ''],
      ['Loan Amount', '₹${_formatCurrency(data.totalLoans)}', warningHex, ''],
      ['Monthly Budget', '₹${_formatCurrency(data.monthlyBudget)}', primaryHex, ''],
    ];

    _styleRow(sheet, r, 0, 3, 'KEY PERFORMANCE INDICATORS',
        bold: true, fontSize: 14, bgHex: headerBgHex, fontHex: headerTextHex);
    _mergeCells(sheet, r, 0, r, 3);
    r++;

    for (final kpi in kpiRows) {
      final isAlt = (r % 2 == 0);
      _styleCell(sheet, r, 0, kpi[0], fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 1, kpi[1], bold: true, fontHex: kpi[2]);
      _styleCell(sheet, r, 2, '', fontHex: textPrimaryHex);
      _styleCell(sheet, r, 3, '', fontHex: textPrimaryHex);
      r++;
    }

    r++;
    if (data.monthlyBudget > 0) {
      final budgetPct = data.budgetUsedPercent;
      final pctStr = '${budgetPct.toStringAsFixed(1)}%';
      _styleRow(sheet, r, 0, 3, 'Budget Used: $pctStr     '
          '₹${_formatCurrency(data.actualSpending)} / ₹${_formatCurrency(data.monthlyBudget)}',
          fontHex: budgetPct > 100 ? errorHex : successHex, fontSize: 12);
      r++;
      _addBarCell(sheet, r, 0, budgetPct / 100, 'Budget Usage',
          pctStr, primaryHex, headerBgHex, 4);
      r += 2;
    }

    r++;
    if (data.expenses.isNotEmpty) {
      _styleRow(sheet, r, 0, 3, 'TOP SPENDING CATEGORIES',
          bold: true, fontSize: 14, bgHex: headerBgHex, fontHex: headerTextHex);
      _mergeCells(sheet, r, 0, r, 3);
      r++;

      for (final cat in data.categorySummary.take(8)) {
        final isAlt = (r % 2 == 0);
        _styleCell(sheet, r, 0, cat.category,
            fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
        _styleCell(sheet, r, 1, '₹${_formatCurrency(cat.totalAmount)}',
            fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
        final pctStr = '${cat.percentage.toStringAsFixed(1)}%';
        _addBarCell(sheet, r, 2, cat.percentage / 100, pctStr,
            pctStr, primaryHex, headerBgHex, 2);
        _styleCell(sheet, r, 3, '${cat.transactionCount} txns',
            fontHex: textSecondaryHex, bgHex: isAlt ? altRowHex : 'none');
        r++;
      }
    }

    sheet.setColWidth(0, 28);
    sheet.setColWidth(1, 22);
    sheet.setColWidth(2, 22);
    sheet.setColWidth(3, 18);
  }

  // ── Expenses Sheet ──

  void _buildExpensesSheet(Excel excel, ReportData data) {
    final sheet = excel['Expenses'];
    _buildTransactionSheet(sheet, data.expenses, [
      'Date', 'Category', 'Description', 'Tag', 'Amount', 'Account',
    ], (e) {
      final dt = _safeParseDateTime(e['dateTime']);
      return [
        dt != null ? _dateFmt.format(dt) : '',
        e['category'] as String? ?? '',
        e['description'] as String? ?? '',
        e['tag'] as String? ?? '',
        _safeToDouble(e['amount']),
        e['accountId'] as String? ?? '',
      ];
    }, 'TOTAL EXPENSES', data.totalExpenses);
  }

  // ── Income Sheet ──

  void _buildIncomeSheet(Excel excel, ReportData data) {
    final sheet = excel['Income'];
    _buildTransactionSheet(sheet, data.incomes, [
      'Date', 'Source', 'Frequency', 'Amount',
    ], (i) {
      final dt = _safeParseDateTime(i['dateTime']);
      return [
        dt != null ? _dateFmt.format(dt) : '',
        i['source'] as String? ?? '',
        i['frequency'] as String? ?? '',
        _safeToDouble(i['amount']),
      ];
    }, 'TOTAL INCOME', data.totalIncome);
  }

  // ── Loans Sheet ──

  void _buildLoansSheet(Excel excel, ReportData data) {
    final sheet = excel['Loans'];
    _buildTransactionSheet(sheet, data.loans, [
      'Date', 'Person Name', 'Type', 'Amount', 'Status',
    ], (l) {
      final dt = _safeParseDateTime(l['dateTime']);
      return [
        dt != null ? _dateFmt.format(dt) : '',
        l['personName'] as String? ?? '',
        l['loanType'] as String? ?? '',
        _safeToDouble(l['amount']),
        l['status'] as String? ?? '',
      ];
    }, 'TOTAL LOANS', data.totalLoans);
  }

  // ── Investments Sheet ──

  void _buildInvestmentsSheet(Excel excel, ReportData data) {
    final sheet = excel['Investments'];
    _buildTransactionSheet(sheet, data.investments, [
      'Date', 'Name', 'Type', 'Units', 'Price/Unit', 'Amount',
    ], (inv) {
      final dt = _safeParseDateTime(inv['dateTime']);
      return [
        dt != null ? _dateFmt.format(dt) : '',
        inv['name'] as String? ?? '',
        inv['type'] as String? ?? '',
        _safeToDouble(inv['units']),
        _safeToDouble(inv['pricePerUnit']),
        _safeToDouble(inv['amount']),
      ];
    }, 'TOTAL INVESTED', data.totalInvested);
  }

  // ── Category Report Sheet ──

  void _buildCategoryReportSheet(Excel excel, ReportData data) {
    final sheet = excel['Category Report'];
    int r = 0;

    _styleRow(sheet, r, 0, 3, 'CATEGORY-WISE EXPENSE SUMMARY',
        bold: true, fontSize: 14, bgHex: primaryHex, fontHex: 'FF003731');
    _mergeCells(sheet, r, 0, r, 3);
    r++;

    final headers = ['Category', 'Total Amount', '% of Total', 'Transactions'];
    for (int c = 0; c < headers.length; c++) {
      _styleCell(sheet, r, c, headers[c],
          bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    }
    r++;

    for (final cat in data.categorySummary) {
      final isAlt = (r % 2 == 0);
      final pctBar = cat.percentage / 100;
      _styleCell(sheet, r, 0, cat.category,
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 1, _safeToDoubleStr(cat.totalAmount),
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      _addBarCell(sheet, r, 2, pctBar,
          '${cat.percentage.toStringAsFixed(1)}%',
          '${cat.percentage.toStringAsFixed(1)}%', primaryHex,
          isAlt ? altRowHex : 'none', 1);
      _styleCell(sheet, r, 3, '${cat.transactionCount}',
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      r++;
    }

    _styleCell(sheet, r, 0, 'TOTAL',
        bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    _styleCell(sheet, r, 1, _safeToDoubleStr(data.totalExpenses),
        bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    _styleCell(sheet, r, 2, '100%',
        bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    _styleCell(sheet, r, 3, '${data.expenses.length}',
        bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    r += 2;

    if (data.tagSummary.isNotEmpty) {
      _styleRow(sheet, r, 0, 2, 'TAG-WISE EXPENSE SUMMARY',
          bold: true, fontSize: 14, bgHex: headerBgHex, fontHex: headerTextHex);
      _mergeCells(sheet, r, 0, r, 2);
      r++;

      final tagHeaders = ['Tag', 'Total Amount', 'Transactions'];
      for (int c = 0; c < tagHeaders.length; c++) {
        _styleCell(sheet, r, c, tagHeaders[c],
            bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
      }
      r++;

      for (final tag in data.tagSummary) {
        final isAlt = (r % 2 == 0);
        _styleCell(sheet, r, 0, tag.tag,
            fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
        _styleCell(sheet, r, 1, _safeToDoubleStr(tag.totalAmount),
            fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
        _styleCell(sheet, r, 2, '${tag.transactionCount}',
            fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
        r++;
      }
    }

    sheet.setColWidth(0, 24);
    sheet.setColWidth(1, 20);
    sheet.setColWidth(2, 20);
    sheet.setColWidth(3, 16);
    // freeze pane not supported in excel 2.x
  }

  // ── Monthly Trend Sheet ──

  void _buildMonthlyTrendSheet(Excel excel, ReportData data) {
    final sheet = excel['Monthly Trend'];
    int r = 0;

    _styleRow(sheet, r, 0, 4, 'MONTHLY TREND SUMMARY',
        bold: true, fontSize: 14, bgHex: primaryHex, fontHex: 'FF003731');
    _mergeCells(sheet, r, 0, r, 4);
    r++;

    final headers = ['Month', 'Income', 'Expense', 'Net Savings', 'Investments'];
    for (int c = 0; c < headers.length; c++) {
      _styleCell(sheet, r, c, headers[c],
          bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    }
    r++;

    double totalInc = 0, totalExp = 0, totalNet = 0, totalInv = 0;
    for (final m in data.monthlyTrend) {
      final isAlt = (r % 2 == 0);
      _styleCell(sheet, r, 0, m.label,
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 1, _safeToDoubleStr(m.income),
          fontHex: m.income > 0 ? successHex : textPrimaryHex,
          bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 2, _safeToDoubleStr(m.expense),
          fontHex: m.expense > 0 ? errorHex : textPrimaryHex,
          bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 3, _safeToDoubleStr(m.netSavings),
          fontHex: m.netSavings >= 0 ? successHex : errorHex,
          bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 4, _safeToDoubleStr(m.investment),
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      totalInc += m.income;
      totalExp += m.expense;
      totalNet += m.netSavings;
      totalInv += m.investment;
      r++;
    }

    for (int c = 0; c < 5; c++) {
      _styleCell(sheet, r, c, c == 0 ? 'TOTAL' : [
        _safeToDoubleStr(totalInc),
        _safeToDoubleStr(totalExp),
        _safeToDoubleStr(totalNet),
        _safeToDoubleStr(totalInv),
      ][c - 1], bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    }
    r += 2;

    if (data.budgetAnalysis.isNotEmpty) {
      _styleRow(sheet, r, 0, 3, 'BUDGET ANALYSIS',
          bold: true, fontSize: 14, bgHex: headerBgHex, fontHex: headerTextHex);
      _mergeCells(sheet, r, 0, r, 3);
      r++;

      final bHeaders = ['Category', 'Budget', 'Actual Spending', 'Remaining', 'Status'];
      for (int c = 0; c < bHeaders.length; c++) {
        _styleCell(sheet, r, c, bHeaders[c],
            bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
      }
      r++;

      for (final ba in data.budgetAnalysis) {
        final isAlt = (r % 2 == 0);
        _styleCell(sheet, r, 0, ba.category,
            fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
        _styleCell(sheet, r, 1, _safeToDoubleStr(ba.budget),
            fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
        _styleCell(sheet, r, 2, _safeToDoubleStr(ba.actualSpending),
            fontHex: ba.actualSpending > ba.budget ? errorHex : textPrimaryHex,
            bgHex: isAlt ? altRowHex : 'none');
        _styleCell(sheet, r, 3, _safeToDoubleStr(ba.remaining),
            fontHex: ba.remaining >= 0 ? successHex : errorHex,
            bgHex: isAlt ? altRowHex : 'none');
        _styleCell(sheet, r, 4, ba.status,
            bold: true,
            fontHex: ba.status == 'Under Budget' ? successHex : errorHex,
            bgHex: isAlt ? altRowHex : 'none');
        r++;
      }
    }

    sheet.setColWidth(0, 18);
    sheet.setColWidth(1, 20);
    sheet.setColWidth(2, 20);
    sheet.setColWidth(3, 20);
    sheet.setColWidth(4, 20);
    // freeze pane not supported in excel 2.x
  }

  // ── Tag Summary Sheet ──

  void _buildTagSummarySheet(Excel excel, ReportData data) {
    if (data.tagSummary.isEmpty) return;
    final sheet = excel['Tags'];
    int r = 0;

    _styleRow(sheet, r, 0, 2, 'TAG-WISE EXPENSE SUMMARY',
        bold: true, fontSize: 14, bgHex: primaryHex, fontHex: 'FF003731');
    _mergeCells(sheet, r, 0, r, 2);
    r++;

    final headers = ['Tag', 'Total Amount', 'Transactions'];
    for (int c = 0; c < headers.length; c++) {
      _styleCell(sheet, r, c, headers[c],
          bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    }
    r++;

    for (final tag in data.tagSummary) {
      final isAlt = (r % 2 == 0);
      _styleCell(sheet, r, 0, tag.tag,
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 1, _safeToDoubleStr(tag.totalAmount),
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 2, '${tag.transactionCount}',
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      r++;
    }

    sheet.setColWidth(0, 24);
    sheet.setColWidth(1, 20);
    sheet.setColWidth(2, 16);
  }

  // ── Budget Analysis Sheet ──

  void _buildBudgetAnalysisSheet(Excel excel, ReportData data) {
    if (data.budgetAnalysis.isEmpty) return;
    final sheet = excel['Budget Analysis'];
    int r = 0;

    _styleRow(sheet, r, 0, 4, 'BUDGET ANALYSIS',
        bold: true, fontSize: 14, bgHex: primaryHex, fontHex: 'FF003731');
    _mergeCells(sheet, r, 0, r, 4);
    r++;

    final headers = ['Category', 'Budget', 'Actual', 'Remaining', 'Status'];
    for (int c = 0; c < headers.length; c++) {
      _styleCell(sheet, r, c, headers[c],
          bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    }
    r++;

    for (final ba in data.budgetAnalysis) {
      final isAlt = (r % 2 == 0);
      _styleCell(sheet, r, 0, ba.category,
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 1, _safeToDoubleStr(ba.budget),
          fontHex: textPrimaryHex, bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 2, _safeToDoubleStr(ba.actualSpending),
          fontHex: ba.actualSpending > ba.budget ? errorHex : textPrimaryHex,
          bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 3, _safeToDoubleStr(ba.remaining),
          fontHex: ba.remaining >= 0 ? successHex : errorHex,
          bgHex: isAlt ? altRowHex : 'none');
      _styleCell(sheet, r, 4, ba.status,
          bold: true,
          fontHex: ba.status == 'Under Budget' ? successHex : errorHex,
          bgHex: isAlt ? altRowHex : 'none');
      r++;
    }

    sheet.setColWidth(0, 24);
    sheet.setColWidth(1, 20);
    sheet.setColWidth(2, 20);
    sheet.setColWidth(3, 20);
    sheet.setColWidth(4, 16);
  }

  // ── Generic transaction sheet builder ──

  void _buildTransactionSheet(
    Sheet sheet,
    List<Map<String, dynamic>> records,
    List<String> headers,
    List<dynamic> Function(Map<String, dynamic>) rowBuilder,
    String totalLabel,
    double totalAmount,
  ) {
    int r = 0;

    for (int c = 0; c < headers.length; c++) {
      _styleCell(sheet, r, c, headers[c],
          bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
    }
    r++;

    for (final rec in records) {
      final isAlt = (r % 2 == 0);
      final values = rowBuilder(rec);
      for (int c = 0; c < headers.length; c++) {
        final val = c < values.length ? values[c] : '';
        final isAmount = c == values.length - 1 && val is num;
        _styleCell(sheet, r, c, val,
            fontHex: isAmount ? primaryHex : textPrimaryHex,
            bgHex: isAlt ? altRowHex : 'none');
      }
      r++;
    }

    // Total row
    for (int c = 0; c < headers.length; c++) {
      if (c == 0) {
        _styleCell(sheet, r, c, totalLabel,
            bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
      } else if (c == headers.length - 1) {
        _styleCell(sheet, r, c, _safeToDoubleStr(totalAmount),
            bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
      } else {
        _styleCell(sheet, r, c, '',
            bold: true, bgHex: headerBgHex, fontHex: headerTextHex);
      }
    }

    for (int c = 0; c < headers.length; c++) {
      sheet.setColWidth(c, 20);
    }
    // freeze pane not supported in excel 2.x
  }

  // ── Style helpers ──

  void _styleCell(Sheet sheet, int row, int col, dynamic value,
      {bool bold = false, String? fontHex, String? bgHex, int? fontSize}) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      value is num && value is! int ? (value as double).toDouble() : value,
      cellStyle: CellStyle(
        fontColorHex: fontHex ?? 'FF000000',
        backgroundColorHex: bgHex ?? 'none',
        bold: bold,
        fontSize: fontSize ?? 11,
        fontFamily: 'Calibri',
      ),
    );
  }

  void _styleRow(Sheet sheet, int row, int colStart, int colEnd, String value,
      {bool bold = false, String? fontHex, String? bgHex, int? fontSize}) {
    for (int c = colStart; c <= colEnd; c++) {
      _styleCell(sheet, row, c, c == colStart ? value : '',
          bold: bold, fontHex: fontHex, bgHex: bgHex, fontSize: fontSize);
    }
  }

  void _mergeCells(Sheet sheet, int startRow, int startCol, int endRow, int endCol) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: startRow),
      CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: endRow),
    );
  }

  void _mergeAndStyle(Sheet sheet, int startRow, int startCol,
      int endRow, int endCol, String value,
      {bool bold = false, String? fontHex, String? bgHex, int? fontSize}) {
    _mergeCells(sheet, startRow, startCol, endRow, endCol);
    _styleCell(sheet, startRow, startCol, value,
        bold: bold, fontHex: fontHex, bgHex: bgHex, fontSize: fontSize);
  }

  void _addBarCell(Sheet sheet, int row, int col, double fraction,
      String displayText, String rawValue,
      String barColor, String bgColor, double colSpan) {
    _styleCell(sheet, row, col, rawValue,
        fontHex: displayText, bgHex: barColor);
  }

  String _safeToDoubleStr(dynamic value) {
    final v = _safeToDouble(value);
    return '₹${_formatCurrency(v)}';
  }

  String _formatCurrency(double value) {
    final isNeg = value < 0;
    final abs = isNeg ? -value : value;
    return '${isNeg ? '-' : ''}${_currencyFmt.format(abs)}';
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

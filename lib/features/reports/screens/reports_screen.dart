import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/core/services/report_service.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:money_manager/core/services/excel_report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange? _dateRange;
  bool _isLoading = false;

  ReportData? _reportData;
  ReportService? _reportService;

  static const _presets = [
    'This Month', 'Last Month', 'Last 3 Months', 'Last 6 Months',
    'This Year', 'Last Year', 'Custom',
  ];

  String _selectedPreset = 'This Month';

  @override
  void initState() {
    super.initState();
    _applyPreset('This Month');
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    late DateTime start;
    late DateTime end;

    switch (preset) {
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = now;
      case 'Last Month':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0);
      case 'Last 3 Months':
        start = DateTime(now.year, now.month - 3, 1);
        end = now;
      case 'Last 6 Months':
        start = DateTime(now.year, now.month - 6, 1);
        end = now;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        end = now;
      case 'Last Year':
        start = DateTime(now.year - 1, 1, 1);
        end = DateTime(now.year - 1, 12, 31);
      case 'Custom':
        _pickDateRange();
        return;
      default:
        start = DateTime(now.year, now.month, 1);
        end = now;
    }

    setState(() {
      _selectedPreset = preset;
      _dateRange = DateTimeRange(start: start, end: end);
    });
    _loadData();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedPreset = 'Custom';
        _dateRange = picked;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final srv = context.read<AuthProvider>().authService;
    if (srv == null || _dateRange == null) return;
    setState(() => _isLoading = true);
    try {
      _reportService = ReportService(srv.database);
      final data = await _reportService!.generateReport(
        startDate: _dateRange!.start,
        endDate: _dateRange!.end,
        userId: context.read<AuthProvider>().currentUserId,
      );
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showExportDialog() async {
    final result = await showDialog<ExportOptions>(
      context: context,
      builder: (ctx) => _ExportOptionsDialog(dateRange: _dateRange!),
    );
    if (result != null && mounted) {
      _exportReport(result);
    }
  }

  Future<void> _exportReport(ExportOptions options) async {
    final srv = context.read<AuthProvider>().authService;
    if (srv == null || _dateRange == null || _reportData == null) return;
    final cs = Theme.of(context).colorScheme;

    try {
      if (_reportService == null) {
        _reportService = ReportService(srv.database);
      }
      final data = _reportData!;
      final excelService = ExcelReportService();
      final bytes = excelService.generateWorkbook(data, options: options);
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final fileName =
          'SJsaver_Report_${DateFormat('yyyyMMdd').format(_dateRange!.start)}_to_${DateFormat('yyyyMMdd').format(_dateRange!.end)}.xlsx';

      if (kIsWeb) {
        excel_pkg.Excel.decodeBytes(bytes).save(fileName: fileName);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (!mounted) return;
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'SJsaver Report',
          text: 'SJsaver financial report',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: cs.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final totalWidth = MediaQuery.of(context).size.width - 32;
    final data = _reportData;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Reports', style: TextStyle(color: cs.onSurface)),
        actions: [
          if (data != null && (data.expenses.isNotEmpty || data.incomes.isNotEmpty))
            IconButton(
              icon: Icon(Icons.file_download, color: cs.primary),
              onPressed: _showExportDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Preset chips + date picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (ctx, i) {
                        final p = _presets[i];
                        final isSelected = _selectedPreset == p;
                        return FilterChip(
                          label: Text(p, style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? AppColors.background : cs.onSurfaceVariant,
                          )),
                          selected: isSelected,
                          onSelected: (_) => _applyPreset(p),
                          selectedColor: cs.primary,
                          checkmarkColor: AppColors.background,
                          backgroundColor: cs.surfaceContainerHighest,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDateRange,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range, color: cs.primary, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _dateRange != null
                                ? '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}'
                                : 'Select date range',
                            style: TextStyle(color: cs.onSurface, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : data == null || (data.expenses.isEmpty && data.incomes.isEmpty)
                    ? _buildEmptyState(cs)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: cs.primary,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryCards(cs, totalWidth, data),
                              const SizedBox(height: 16),
                              if (data.categorySummary.isNotEmpty)
                                _buildCategoryPieChart(cs, totalWidth, data),
                              const SizedBox(height: 16),
                              if (data.monthlyTrend.length >= 2)
                                _buildMonthlyTrendChart(cs, totalWidth, data),
                              const SizedBox(height: 16),
                              if (data.categorySummary.isNotEmpty)
                                _buildTopCategories(cs, data),
                              const SizedBox(height: 16),
                              _buildTransactionList(cs, data),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text('No data for this period', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Select a wider date range', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ColorScheme cs, double totalWidth, ReportData data) {
    final net = data.netSavings;
    final savingsRate = data.savingsRate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard('Income', '₹${data.totalIncome.toStringAsFixed(0)}', AppColors.success, cs, (totalWidth - 48) / 3),
              const SizedBox(width: 8),
              _statCard('Expenses', '₹${data.totalExpenses.toStringAsFixed(0)}', cs.error, cs, (totalWidth - 48) / 3),
              const SizedBox(width: 8),
              _statCard('Net', '₹${net.toStringAsFixed(0)}', net >= 0 ? AppColors.success : cs.error, cs, (totalWidth - 48) / 3),
            ],
          ),
          if (data.totalIncome > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Savings Rate', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const Spacer(),
                Text('${savingsRate.toStringAsFixed(1)}%', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: savingsRate / 100,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  savingsRate > 30 ? AppColors.success : savingsRate > 15 ? cs.tertiary : cs.error,
                ),
              ),
            ),
          ],
          if (data.monthlyBudget > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Budget Used', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const Spacer(),
                Text('${data.budgetUsedPercent.toStringAsFixed(1)}%', style: TextStyle(
                  color: data.budgetUsedPercent > 100 ? cs.error : AppColors.success,
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (data.budgetUsedPercent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  data.budgetUsedPercent > 100 ? cs.error : AppColors.success,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${data.expenses.length} expense${data.expenses.length == 1 ? '' : 's'} · '
              '${data.incomes.length} income${data.incomes.length == 1 ? '' : 's'} · '
              '${data.loans.length} loan${data.loans.length == 1 ? '' : 's'}',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, ColorScheme cs, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(ColorScheme cs, double totalWidth, ReportData data) {
    final cats = data.categorySummary.take(8).toList();
    final colors = AppColors.chartColors;
    final total = data.totalExpenses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(cats.length, (i) {
                        final pct = total > 0 ? cats[i].totalAmount / total * 100 : 0.0;
                        return PieChartSectionData(
                          value: cats[i].totalAmount,
                          title: '${pct.toStringAsFixed(0)}%',
                          color: colors[i % colors.length],
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(cats.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cats[i].category,
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart(ColorScheme cs, double totalWidth, ReportData data) {
    final entries = data.monthlyTrend;
    final maxVal = entries.isEmpty ? 1.0 : entries.map((e) => e.expense).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(entries[idx].label, style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          return Text('₹${value.toInt()}', style: TextStyle(color: AppColors.textTertiary, fontSize: 9));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxVal / 4,
                    getDrawingHorizontalLine: (value) => FlLine(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(entries.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(toY: entries[i].expense, color: cs.error, width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategories(ColorScheme cs, ReportData data) {
    final entries = data.categorySummary.take(8).toList();
    final total = data.totalExpenses;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Spending Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 12),
          ...List.generate(entries.length, (i) {
            final pct = total > 0 ? entries[i].totalAmount / total * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(entries[i].category, style: TextStyle(color: cs.onSurface, fontSize: 13)),
                      const Spacer(),
                      Text('₹${entries[i].totalAmount.toStringAsFixed(0)}', style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(AppColors.chartColors[i % AppColors.chartColors.length]),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionList(ColorScheme cs, ReportData data) {
    final transactions = <Map<String, dynamic>>[];
    for (final e in data.expenses) {
      transactions.add({...e, '_type': 'Expense'});
    }
    for (final i in data.incomes) {
      transactions.add({...i, '_type': 'Income', 'description': i['source'] as String? ?? ''});
    }
    transactions.sort((a, b) {
      final da = DateTime.tryParse(a['dateTime'] as String? ?? '');
      final db = DateTime.tryParse(b['dateTime'] as String? ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    final display = transactions.take(20).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 12),
          if (display.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No transactions', style: TextStyle(color: cs.onSurfaceVariant))),
            )
          else
            ...List.generate(display.length, (i) {
              final t = display[i];
              final isExpense = t['_type'] == 'Expense';
              final amt = (t['amount'] as num?)?.toDouble() ?? 0;
              final dt = DateTime.tryParse(t['dateTime'] as String? ?? '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isExpense ? cs.error : AppColors.success).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(isExpense ? Icons.arrow_upward : Icons.arrow_downward, color: isExpense ? cs.error : AppColors.success, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['description'] ?? t['source'] ?? 'Transaction', style: TextStyle(color: cs.onSurface, fontSize: 13)),
                          Row(
                            children: [
                              Text(t['category'] as String? ?? '', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                              if (dt != null) ...[
                                const SizedBox(width: 6),
                                Text(DateFormat('dd/MM').format(dt), style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isExpense ? '-' : '+'}₹${amt.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isExpense ? cs.error : AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (transactions.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Text('+ ${transactions.length - 20} more', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Export Options Dialog ──

class _ExportOptionsDialog extends StatefulWidget {
  final DateTimeRange dateRange;
  const _ExportOptionsDialog({required this.dateRange});

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  bool _fullWorkbook = true;
  bool _includeTransactions = true;
  bool _includeMetadata = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      title: Text('Export Options', style: TextStyle(color: cs.onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('dd MMM').format(widget.dateRange.start)} — ${DateFormat('dd MMM yyyy').format(widget.dateRange.end)}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Export Full Workbook', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Includes Summary, Tags, Budget sheets', style: TextStyle(fontSize: 11)),
              value: _fullWorkbook,
              activeColor: cs.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _fullWorkbook = v),
            ),
            SwitchListTile(
              title: const Text('Include Raw Transactions', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Expenses, Income, Loans, Investments sheets', style: TextStyle(fontSize: 11)),
              value: _includeTransactions,
              activeColor: cs.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _includeTransactions = v),
            ),
            SwitchListTile(
              title: const Text('Include Metadata Fields', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Adds category-dependent fields to exports', style: TextStyle(fontSize: 11)),
              value: _includeMetadata,
              activeColor: cs.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _includeMetadata = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ExportOptions(
            fullWorkbook: _fullWorkbook,
            includeRawTransactions: _includeTransactions,
            includeMetadata: _includeMetadata,
          )),
          child: Text('Export', style: TextStyle(color: cs.primary)),
        ),
      ],
    );
  }
}

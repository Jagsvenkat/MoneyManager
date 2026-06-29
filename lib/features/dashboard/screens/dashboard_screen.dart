import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _totalInvested = 0;
  List<Map<String, dynamic>> _recentExpenses = [];
  bool _isLoading = true;
  Map<String, double> _categoryTotals = {};
  int _selectedPeriod = 1;
  static const _periodOptions = [1, 3, 6, 12, 36];
  static const _periodLabels = ['1M', '3M', '6M', '1Y', '3Y'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboard();
  }

  DateTime _cutoffDate() =>
      DateTime.now().subtract(Duration(days: 30 * _selectedPeriod));

  Future<void> _loadDashboard() async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    try {
      final incomes = await authService.database.listIncome();
      final expenses = await authService.database.listExpenses();
      final investments = await authService.database.listInvestments();
      final cutoff = _cutoffDate();

      double totalIncome = 0;
      for (final inc in incomes) {
        totalIncome += (inc['amount'] as num?)?.toDouble() ?? 0;
      }

      double totalExpenses = 0;
      final categoryTotals = <String, double>{};
      for (final exp in expenses) {
        final dt = DateTime.tryParse(exp['dateTime'] as String? ?? '');
        if (dt != null && dt.isBefore(cutoff)) continue;
        final amt = (exp['amount'] as num?)?.toDouble() ?? 0;
        totalExpenses += amt;
        final cat = (exp['category'] as String?) ?? 'Other';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
      }

      double totalInvested = 0;
      for (final inv in investments) {
        final units = (inv['units'] as num?)?.toDouble() ?? 0;
        final price = (inv['pricePerUnit'] as num?)?.toDouble() ?? 0;
        totalInvested += units * price;
      }

      expenses.sort((a, b) {
        final da = DateTime.tryParse(a['dateTime'] as String? ?? '');
        final db = DateTime.tryParse(b['dateTime'] as String? ?? '');
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() {
          _totalIncome = totalIncome;
          _totalExpenses = totalExpenses;
          _totalInvested = totalInvested;
          _recentExpenses = expenses.take(5).toList();
          _categoryTotals = categoryTotals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () { setState(() => _isLoading = true); _loadDashboard(); },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadDashboard,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 20),
                      _buildQuickStats(),
                      const SizedBox(height: 20),
                      if (_categoryTotals.isNotEmpty) _buildCharts(),
                      const SizedBox(height: 20),
                      _buildRecentActivity(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _totalIncome - _totalExpenses;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOTAL BALANCE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          Row(
            children: [
              _statItem('Income', '₹${_totalIncome.toStringAsFixed(2)}', AppColors.success),
              const Spacer(),
              _statItem('Expenses', '₹${_totalExpenses.toStringAsFixed(2)}', AppColors.error),
              const Spacer(),
              _statItem('Invested', '₹${_totalInvested.toStringAsFixed(2)}', AppColors.tertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String title, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildQuickStats() {
    double avgDaily = 0;
    if (_recentExpenses.isNotEmpty) {
      final total = _recentExpenses.fold<double>(0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
      avgDaily = total / _recentExpenses.length;
    }
    return Row(
      children: [
        Expanded(child: _quickStatCard('Highest Expense', '₹${_recentExpenses.isNotEmpty ? _recentExpenses.first['amount']?.toStringAsFixed(2) ?? '0' : '0'}', Icons.arrow_upward, AppColors.error)),
        const SizedBox(width: 12),
        Expanded(child: _quickStatCard('Avg. Daily', '₹${avgDaily.toStringAsFixed(2)}', Icons.show_chart, AppColors.info)),
        const SizedBox(width: 12),
        Expanded(child: _quickStatCard('This Month', '₹${_totalExpenses.toStringAsFixed(2)}', Icons.calendar_month, AppColors.primary)),
      ],
    );
  }

  Widget _quickStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCharts() {
    final colors = AppColors.chartColors;
    final entries = _categoryTotals.entries.toList();
    final maxY = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Spending Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Row(
              children: List.generate(_periodOptions.length, (i) {
                final selected = _selectedPeriod == _periodOptions[i];
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedPeriod = _periodOptions[i]);
                      _loadDashboard();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _periodLabels[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.black : AppColors.textSecondary,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: entries.isEmpty
                ? const Center(child: Text('No data for this period', style: TextStyle(color: AppColors.textSecondary)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.2,
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
                                child: Text(entries[idx].key, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text('₹${value.toInt()}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 10));
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(entries.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: entries[i].value,
                              color: colors[i % colors.length],
                              width: 22,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _recentExpenses.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No recent transactions', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : Column(
                  children: _recentExpenses.map((exp) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt, color: AppColors.error, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp['description'] ?? 'Expense', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                              Text(exp['category'] ?? '', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('₹${(exp['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ),
        ),
      ],
    );
  }
}

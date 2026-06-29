import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/core/services/github_sync_service.dart';
import 'package:money_manager/core/security/secure_storage.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _totalInvested = 0;
  double _lastMonthExpenses = 0;
  List<Map<String, dynamic>> _recentExpenses = [];
  bool _isLoading = true;
  Map<String, double> _categoryTotals = {};
  int _selectedPeriod = 1;
  static const _periodOptions = [1, 3, 6, 12, 36];
  static const _periodLabels = ['1M', '3M', '6M', '1Y', '3Y'];
  bool _isSyncing = false;
  double _monthlyBudget = 0;

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
      double lastMonthExpenses = 0;
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final categoryTotals = <String, double>{};
      for (final exp in expenses) {
        final dt = DateTime.tryParse(exp['dateTime'] as String? ?? '');
        if (dt != null && dt.isBefore(cutoff)) continue;
        final amt = (exp['amount'] as num?)?.toDouble() ?? 0;
        totalExpenses += amt;
        final cat = (exp['category'] as String?) ?? 'Other';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
        if (dt != null && !dt.isBefore(lastMonthStart) && dt.isBefore(thisMonthStart)) {
          lastMonthExpenses += amt;
        }
      }

      double totalInvested = 0;
      for (final inv in investments) {
        final units = (inv['units'] as num?)?.toDouble() ?? 0;
        final price = (inv['pricePerUnit'] as num?)?.toDouble() ?? 0;
        totalInvested += units * price;
      }

      final budget = await authService.database.getMonthlyBudget();

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
          _lastMonthExpenses = lastMonthExpenses;
          _recentExpenses = expenses.take(5).toList();
          _categoryTotals = categoryTotals;
          _monthlyBudget = budget;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerSync() async {
    final cs = Theme.of(context).colorScheme;
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    final auth = context.read<AuthProvider>();
    final srv = auth.authService;
    if (srv == null) { setState(() => _isSyncing = false); return; }

    final token = await SecureStorageService.loadGitHubPat('sync');
    final settings = await SecureStorageService.loadSyncSettings();
    if (token == null || settings == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync not configured — go to Settings'), backgroundColor: AppColors.warning),
        );
      }
      setState(() => _isSyncing = false);
      return;
    }

    final syncService = GitHubSyncService(
      githubToken: token,
      repoOwner: settings['owner'] as String,
      repoName: settings['repoName'] as String,
      db: srv.database,
      userId: auth.currentUserId ?? '',
      deviceId: srv.deviceId,
    );

    final result = await syncService.pushChanges(wrappingKey: srv.userMasterKey);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? 'Data synced!' : 'Sync failed'),
          backgroundColor: result.success ? AppColors.success : cs.error,
        ),
      );
    }
    setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Dashboard', style: TextStyle(color: cs.onSurface)),
        actions: [
          IconButton(
            icon: _isSyncing
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : Icon(Icons.cloud_upload, color: cs.primary),
            onPressed: _isSyncing ? null : _triggerSync,
            tooltip: 'Sync to GitHub',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: cs.primary),
            onPressed: () { setState(() => _isLoading = true); _loadDashboard(); },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadDashboard,
                color: cs.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 20),
                      if (_monthlyBudget > 0) ...[
                        _buildBudgetSection(),
                        SizedBox(height: 20),
                      ],
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
    final cs = Theme.of(context).colorScheme;
    final balance = _totalIncome - _totalExpenses;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.2),
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL BALANCE', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text('₹${balance.toStringAsFixed(2)}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 20),
          Row(
            children: [
              _statItem('Income', '₹${_totalIncome.toStringAsFixed(2)}', AppColors.success),
              const Spacer(),
              _statItem('Expenses', '₹${_totalExpenses.toStringAsFixed(2)}', cs.error),
              const Spacer(),
              _statItem('Invested', '₹${_totalInvested.toStringAsFixed(2)}', cs.tertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String title, String amount, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
      ],
    );
  }

  Widget _buildBudgetSection() {
    final cs = Theme.of(context).colorScheme;
    final spent = _totalExpenses;
    final pct = _monthlyBudget > 0 ? (spent / _monthlyBudget).clamp(0, 1).toDouble() : 0.0;
    final remaining = _monthlyBudget - spent;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Budget', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
              Text('₹${spent.toStringAsFixed(0)} / ₹${_monthlyBudget.toStringAsFixed(0)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(pct > 0.9 ? cs.error : pct > 0.7 ? cs.tertiary : cs.primary),
            ),
          ),
          SizedBox(height: 8),
          Text(
            remaining >= 0 ? '₹${remaining.toStringAsFixed(0)} remaining' : '₹${(-remaining).toStringAsFixed(0)} over budget!',
            style: TextStyle(color: remaining >= 0 ? cs.onSurfaceVariant : cs.error, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final cs = Theme.of(context).colorScheme;
    double avgDaily = 0;
    if (_recentExpenses.isNotEmpty) {
      final count = _recentExpenses.length;
      final total = _recentExpenses.fold<double>(0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
      avgDaily = total / count;
    }
    final vsLastMonth = _lastMonthExpenses > 0
        ? ((_totalExpenses - _lastMonthExpenses) / _lastMonthExpenses * 100).toStringAsFixed(1)
        : '+0.0';
    final isUp = _totalExpenses > _lastMonthExpenses;
    return Row(
      children: [
        Expanded(child: _quickStatCard('This Month', '₹${_totalExpenses.toStringAsFixed(0)}', Icons.calendar_month, cs.primary)),
        const SizedBox(width: 12),
        Expanded(child: _quickStatCard('vs Last Month', '${isUp ? '+' : ''}$vsLastMonth%', isUp ? Icons.trending_up : Icons.trending_down, isUp ? cs.error : AppColors.success)),
        const SizedBox(width: 12),
        Expanded(child: _quickStatCard('Avg/Transaction', '₹${avgDaily.toStringAsFixed(0)}', Icons.show_chart, AppColors.info)),
      ],
    );
  }

  Widget _quickStatCard(String label, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.surfaceContainerHighest.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildCharts() {
    final cs = Theme.of(context).colorScheme;
    final colors = AppColors.chartColors;
    final entries = _categoryTotals.entries.toList();
    final maxY = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Spending Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
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
                        color: selected ? cs.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _periodLabels[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.black : cs.onSurfaceVariant,
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
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: entries.isEmpty
                ? Center(child: Text('No data for this period', style: TextStyle(color: cs.onSurfaceVariant)))
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
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _recentExpenses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('No recent transactions', style: TextStyle(color: cs.onSurfaceVariant)),
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
                            color: cs.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.receipt, color: cs.error, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp['description'] ?? 'Expense', style: TextStyle(color: cs.onSurface, fontSize: 13)),
                              Text(exp['category'] ?? '', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('₹${(exp['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: cs.error, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ),
        ),
      ],
    );
  }
}

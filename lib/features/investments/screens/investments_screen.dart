import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  List<Map<String, dynamic>> _investments = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadInvestments();
  }

  Future<void> _loadInvestments() async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    try {
      final investments = await authService.database.listInvestments();
      investments.sort((a, b) {
        final da = DateTime.tryParse(a['dateTime'] as String? ?? '');
        final db = DateTime.tryParse(b['dateTime'] as String? ?? '');
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      if (mounted) setState(() { _investments = investments; _isLoading = false; });
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
        title: const Text('Investments', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: () => _showAddInvestmentDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _investments.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadInvestments,
                  color: AppColors.primary,
                  child: _buildInvestmentList(),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No investments tracked', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Track stocks, mutual funds, and other investments', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddInvestmentDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Investment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tertiary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _investments.length,
      itemBuilder: (context, index) {
        final inv = _investments[index];
        final units = (inv['units'] as num?)?.toDouble() ?? 0;
        final price = (inv['pricePerUnit'] as num?)?.toDouble() ?? 0;
        final totalValue = units * price;
        final dt = DateTime.tryParse(inv['dateTime'] as String? ?? '');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.show_chart, color: AppColors.tertiary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv['name'] ?? 'Investment', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                    Row(
                      children: [
                        Text('${inv['units']} units @ ₹${inv['pricePerUnit']}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        if (dt != null) ...[
                          const SizedBox(width: 6),
                          Text(DateFormat('dd/MM').format(dt), style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text('₹${totalValue.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.tertiary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  void _showAddInvestmentDialog() {
    final nameCtrl = TextEditingController();
    final unitsCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String type = 'equity';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Add Investment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                    ), child: child!),
                  );
                  if (picked != null) setModalState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Instrument Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                dropdownColor: AppColors.surfaceVariant,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Type',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'equity', child: Text('Equity')),
                  DropdownMenuItem(value: 'mutual_fund', child: Text('Mutual Fund')),
                  DropdownMenuItem(value: 'commodity', child: Text('Commodity')),
                  DropdownMenuItem(value: 'crypto', child: Text('Crypto')),
                ],
                onChanged: (v) => setModalState(() => type = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitsCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Units',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true, fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Price/Unit',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true, fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final units = double.tryParse(unitsCtrl.text);
                    final price = double.tryParse(priceCtrl.text);
                    if (nameCtrl.text.isEmpty || units == null || price == null) return;
                    final authService = context.read<AuthProvider>().authService;
                    if (authService == null) return;
                    try {
                      await authService.database.createInvestment({
                        'id': const Uuid().v4(),
                        'name': nameCtrl.text,
                        'type': type,
                        'units': units,
                        'pricePerUnit': price,
                        'dateTime': selectedDate.toIso8601String(),
                      });
                      await _loadInvestments();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Investment saved'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Save Investment', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

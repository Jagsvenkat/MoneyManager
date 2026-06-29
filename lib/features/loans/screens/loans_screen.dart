import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  List<Map<String, dynamic>> _loans = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    try {
      final loans = await authService.database.listLoans();
      loans.sort((a, b) {
        final da = DateTime.tryParse(a['dateTime'] as String? ?? '');
        final db = DateTime.tryParse(b['dateTime'] as String? ?? '');
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      if (mounted) setState(() { _loans = loans; _isLoading = false; });
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
        title: const Text('Loans', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: () => _showAddLoanDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loans.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadLoans,
                  color: AppColors.primary,
                  child: _buildLoanList(),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.handshake, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No loans tracked', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Track money you lent or borrowed', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddLoanDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Loan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _loans.length,
      itemBuilder: (context, index) {
        final loan = _loans[index];
        final isToReceive = loan['loanType'] == 'To Receive';
        final dt = DateTime.tryParse(loan['dateTime'] as String? ?? '');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: GestureDetector(
            onTap: () => _showEditLoanDialog(loan),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(isToReceive ? Icons.arrow_downward : Icons.arrow_upward, color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loan['personName'] ?? 'Unknown', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                      Row(
                        children: [
                          Text(isToReceive ? 'To Receive' : 'To Pay', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                          if (dt != null) ...[
                            const SizedBox(width: 6),
                            Text(DateFormat('dd/MM').format(dt), style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text('₹${loan['amount']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: AppColors.warning, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditLoanDialog(Map<String, dynamic> loan) {
    final personCtrl = TextEditingController(text: loan['personName'] as String? ?? '');
    final amountCtrl = TextEditingController(text: loan['amount']?.toString() ?? '');
    DateTime selectedDate = DateTime.tryParse(loan['dateTime'] as String? ?? '') ?? DateTime.now();
    String loanType = loan['loanType'] as String? ?? 'To Receive';

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
              const Text('Edit Loan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              Row(
                children: ['To Receive', 'To Pay'].map((type) {
                  final selected = loanType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => loanType = type),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.warning.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? AppColors.warning : AppColors.surfaceVariant),
                        ),
                        child: Center(
                          child: Text(type, style: TextStyle(color: selected ? AppColors.warning : AppColors.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
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
                controller: personCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Person Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Amount', hintStyle: TextStyle(color: Colors.grey),
                  prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDeleteLoanConfirm(loan['id'] as String);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text);
                        if (personCtrl.text.isEmpty || amount == null || amount <= 0) return;
                        final authService = context.read<AuthProvider>().authService;
                        if (authService == null) return;
                        try {
                          await authService.database.updateLoan(loan['id'] as String, {
                            'personName': personCtrl.text,
                            'amount': amount,
                            'loanType': loanType,
                            'dateTime': selectedDate.toIso8601String(),
                          });
                          await _loadLoans();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Loan updated'), backgroundColor: AppColors.success),
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
                      child: const Text('Update', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteLoanConfirm(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Loan?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authService = context.read<AuthProvider>().authService;
              if (authService == null) return;
              try {
                await authService.database.deleteLoan(id);
                await _loadLoans();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Loan deleted'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddLoanDialog() {
    final personCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String loanType = 'To Receive';

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
              const Text('Add Loan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              Row(
                children: ['To Receive', 'To Pay'].map((type) {
                  final selected = loanType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => loanType = type),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.warning.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? AppColors.warning : AppColors.surfaceVariant),
                        ),
                        child: Center(
                          child: Text(type, style: TextStyle(color: selected ? AppColors.warning : AppColors.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
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
                controller: personCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Person Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Amount', hintStyle: TextStyle(color: Colors.grey),
                  prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text);
                    if (personCtrl.text.isEmpty || amount == null || amount <= 0) return;
                    final authService = context.read<AuthProvider>().authService;
                    if (authService == null) return;
                    try {
                      await authService.database.createLoan({
                        'id': const Uuid().v4(),
                        'personName': personCtrl.text,
                        'amount': amount,
                        'loanType': loanType,
                        'dateTime': selectedDate.toIso8601String(),
                      });
                      await _loadLoans();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Loan saved'), backgroundColor: AppColors.success),
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
                  child: const Text('Save Loan', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
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

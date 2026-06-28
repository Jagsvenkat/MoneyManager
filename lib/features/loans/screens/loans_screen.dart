import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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
              : _buildLoanList(),
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
                    Text(isToReceive ? 'To Receive' : 'To Pay', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              Text('₹${loan['amount']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: AppColors.warning, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  void _showAddLoanDialog() {
    final personCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
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
                    await authService.database.createLoan({
                      'id': const Uuid().v4(),
                      'personName': personCtrl.text,
                      'amount': amount,
                      'loanType': loanType,
                      'dateTime': DateTime.now().toIso8601String(),
                    });
                    await _loadLoans();
                    if (ctx.mounted) Navigator.pop(ctx);
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

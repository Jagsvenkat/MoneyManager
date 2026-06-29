import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';

class OtherEntriesScreen extends StatefulWidget {
  const OtherEntriesScreen({super.key});

  @override
  State<OtherEntriesScreen> createState() => _OtherEntriesScreenState();
}

class _OtherEntriesScreenState extends State<OtherEntriesScreen> {
  int _selectedSegment = 0; // 0: Income, 1: Loans, 2: Investments
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _investments = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    try {
      final results = await Future.wait([
        authService.database.listIncome(),
        authService.database.listLoans(),
        authService.database.listInvestments(),
      ]);
      for (final list in [results[0], results[1], results[2]]) {
        (list as List).sort((a, b) {
          final da = DateTime.tryParse((a as Map)['dateTime'] as String? ?? '');
          final db = DateTime.tryParse((b as Map)['dateTime'] as String? ?? '');
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
      }
      if (mounted) {
        setState(() {
          _incomes = results[0].cast<Map<String, dynamic>>();
          _loans = results[1].cast<Map<String, dynamic>>();
          _investments = results[2].cast<Map<String, dynamic>>();
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
        title: const Text('More', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              switch (_selectedSegment) {
                case 0: _showAddIncomeDialog();
                case 1: _showAddLoanDialog();
                case 2: _showAddInvestmentDialog();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Income'), icon: Icon(Icons.trending_up, size: 16)),
                        ButtonSegment(value: 1, label: Text('Loans'), icon: Icon(Icons.handshake, size: 16)),
                        ButtonSegment(value: 2, label: Text('Invest'), icon: Icon(Icons.show_chart, size: 16)),
                      ],
                      selected: {_selectedSegment},
                      onSelectionChanged: (sel) => setState(() => _selectedSegment = sel.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.primaryContainer;
                          }
                          return AppColors.surfaceVariant;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.onPrimaryContainer;
                          }
                          return AppColors.onSurfaceVariant;
                        }),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildCurrentSection()),
              ],
            ),
    );
  }

  Widget _buildCurrentSection() {
    switch (_selectedSegment) {
      case 0: return _buildIncomeSection();
      case 1: return _buildLoanSection();
      case 2: return _buildInvestmentSection();
      default: return const SizedBox();
    }
  }

  // ========== INCOME ==========

  Widget _buildIncomeSection() {
    if (_incomes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text('No income recorded', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Track your salary, freelance, and other income', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddIncomeDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Income'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _incomes.length,
        itemBuilder: (context, index) {
          final income = _incomes[index];
          final dt = DateTime.tryParse(income['dateTime'] as String? ?? '');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: GestureDetector(
              onTap: () => _showEditIncomeDialog(income),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.trending_up, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(income['source'] ?? 'Income', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                        Row(
                          children: [
                            Text(income['frequency'] ?? 'one-time', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            if (dt != null) ...[
                              const SizedBox(width: 6),
                              Text(DateFormat('dd/MM').format(dt), style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text('₹${income['amount']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddIncomeDialog() => _showIncomeDialog();
  void _showEditIncomeDialog(Map<String, dynamic> income) => _showIncomeDialog(income: income);

  void _showIncomeDialog({Map<String, dynamic>? income}) {
    final amountCtrl = TextEditingController(text: income?['amount']?.toString() ?? '');
    final sourceCtrl = TextEditingController(text: income?['source'] as String? ?? '');
    DateTime selectedDate = DateTime.tryParse(income?['dateTime'] as String? ?? '') ?? DateTime.now();
    String frequency = income?['frequency'] as String? ?? 'one-time';
    final isEdit = income != null;

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
              Text(isEdit ? 'Edit Income' : 'Add Income', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.success),
                decoration: const InputDecoration(
                  hintText: '0.00', hintStyle: TextStyle(color: Colors.grey),
                  prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.success),
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: AppColors.surfaceVariant),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => child!,
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
                controller: sourceCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Source (Salary, Freelance, etc.)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                dropdownColor: AppColors.surfaceVariant,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'one-time', child: Text('One Time')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (v) => setModalState(() => frequency = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (isEdit)
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
                          _showDeleteIncomeConfirm(income['id'] as String);
                        },
                      ),
                    ),
                  if (isEdit) const SizedBox(width: 12),
                  Expanded(
                    flex: isEdit ? 2 : 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text);
                        if (amount == null || amount <= 0) return;
                        final srv = context.read<AuthProvider>().authService;
                        if (srv == null) return;
                        try {
                          final data = {
                            'id': income?['id'] ?? const Uuid().v4(),
                            'amount': amount,
                            'source': sourceCtrl.text,
                            'frequency': frequency,
                            'dateTime': selectedDate.toIso8601String(),
                          };
                          if (isEdit) {
                            await srv.database.updateIncome(income['id'] as String, data);
                          } else {
                            await srv.database.createIncome(data);
                          }
                          await _loadAll();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEdit ? 'Income updated' : 'Income saved'), backgroundColor: AppColors.success),
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
                      child: Text(isEdit ? 'Update' : 'Save Income', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _showDeleteIncomeConfirm(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Income?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final srv = context.read<AuthProvider>().authService;
              if (srv == null) return;
              try {
                await srv.database.deleteIncome(id);
                await _loadAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Income deleted'), backgroundColor: AppColors.success),
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

  // ========== LOANS ==========

  Widget _buildLoanSection() {
    if (_loans.isEmpty) {
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
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
      ),
    );
  }

  void _showAddLoanDialog() => _showLoanDialog();
  void _showEditLoanDialog(Map<String, dynamic> loan) => _showLoanDialog(loan: loan);

  void _showLoanDialog({Map<String, dynamic>? loan}) {
    final personCtrl = TextEditingController(text: loan?['personName'] as String? ?? '');
    final amountCtrl = TextEditingController(text: loan?['amount']?.toString() ?? '');
    DateTime selectedDate = DateTime.tryParse(loan?['dateTime'] as String? ?? '') ?? DateTime.now();
    String loanType = loan?['loanType'] as String? ?? 'To Receive';
    final isEdit = loan != null;

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
              Text(isEdit ? 'Edit Loan' : 'Add Loan', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                    builder: (ctx, child) => child!,
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
                  if (isEdit)
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
                  if (isEdit) const SizedBox(width: 12),
                  Expanded(
                    flex: isEdit ? 2 : 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text);
                        if (personCtrl.text.isEmpty || amount == null || amount <= 0) return;
                        final srv = context.read<AuthProvider>().authService;
                        if (srv == null) return;
                        try {
                          final data = {
                            'id': loan?['id'] ?? const Uuid().v4(),
                            'personName': personCtrl.text,
                            'amount': amount,
                            'loanType': loanType,
                            'dateTime': selectedDate.toIso8601String(),
                          };
                          if (isEdit) {
                            await srv.database.updateLoan(loan['id'] as String, data);
                          } else {
                            await srv.database.createLoan(data);
                          }
                          await _loadAll();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEdit ? 'Loan updated' : 'Loan saved'), backgroundColor: AppColors.success),
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
                      child: Text(isEdit ? 'Update' : 'Save Loan', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
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
              final srv = context.read<AuthProvider>().authService;
              if (srv == null) return;
              try {
                await srv.database.deleteLoan(id);
                await _loadAll();
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

  // ========== INVESTMENTS ==========

  Widget _buildInvestmentSection() {
    if (_investments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: AppColors.textTertiary),
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
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            child: GestureDetector(
              onTap: () => _showEditInvestmentDialog(inv),
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
            ),
          );
        },
      ),
    );
  }

  void _showAddInvestmentDialog() => _showInvestmentDialog();
  void _showEditInvestmentDialog(Map<String, dynamic> inv) => _showInvestmentDialog(inv: inv);

  void _showInvestmentDialog({Map<String, dynamic>? inv}) {
    final nameCtrl = TextEditingController(text: inv?['name'] as String? ?? '');
    final unitsCtrl = TextEditingController(text: inv?['units']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: inv?['pricePerUnit']?.toString() ?? '');
    DateTime selectedDate = DateTime.tryParse(inv?['dateTime'] as String? ?? '') ?? DateTime.now();
    String type = inv?['type'] as String? ?? 'equity';
    final isEdit = inv != null;

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
              Text(isEdit ? 'Edit Investment' : 'Add Investment', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => child!,
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
              Row(
                children: [
                  if (isEdit)
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
                          _showDeleteInvestmentConfirm(inv['id'] as String);
                        },
                      ),
                    ),
                  if (isEdit) const SizedBox(width: 12),
                  Expanded(
                    flex: isEdit ? 2 : 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tertiary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final units = double.tryParse(unitsCtrl.text);
                        final price = double.tryParse(priceCtrl.text);
                        if (nameCtrl.text.isEmpty || units == null || units <= 0 || price == null || price <= 0) return;
                        final srv = context.read<AuthProvider>().authService;
                        if (srv == null) return;
                        try {
                          final data = {
                            'id': inv?['id'] ?? const Uuid().v4(),
                            'name': nameCtrl.text,
                            'type': type,
                            'units': units,
                            'pricePerUnit': price,
                            'dateTime': selectedDate.toIso8601String(),
                          };
                          if (isEdit) {
                            await srv.database.updateInvestment(inv['id'] as String, data);
                          } else {
                            await srv.database.createInvestment(data);
                          }
                          await _loadAll();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEdit ? 'Investment updated' : 'Investment saved'), backgroundColor: AppColors.success),
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
                      child: Text(isEdit ? 'Update' : 'Save Investment', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _showDeleteInvestmentConfirm(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Investment?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final srv = context.read<AuthProvider>().authService;
              if (srv == null) return;
              try {
                await srv.database.deleteInvestment(id);
                await _loadAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Investment deleted'), backgroundColor: AppColors.success),
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
}

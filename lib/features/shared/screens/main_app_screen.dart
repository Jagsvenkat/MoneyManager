import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/app_provider.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/features/dashboard/screens/dashboard_screen.dart';
import 'package:money_manager/features/expenses/screens/expenses_screen.dart';
import 'package:money_manager/features/income/screens/income_screen.dart';
import 'package:money_manager/features/loans/screens/loans_screen.dart';
import 'package:money_manager/features/investments/screens/investments_screen.dart';
import 'package:money_manager/features/shared/screens/settings_screen.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    ExpensesScreen(),
    IncomeScreen(),
    LoansScreen(),
    InvestmentsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[appProvider.currentTabIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAddSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.surfaceVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: appProvider.currentTabIndex,
          onTap: (index) => appProvider.setTabIndex(index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Expenses'),
            BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Income'),
            BottomNavigationBarItem(icon: Icon(Icons.handshake), label: 'Loans'),
            BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Invest'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  void _showQuickAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Quick Add', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            _quickAddOption(ctx, Icons.receipt_long, 'Expense', AppColors.error, () => _showAddExpenseDialog(ctx)),
            _quickAddOption(ctx, Icons.trending_up, 'Income', AppColors.success, () => _showAddIncomeDialog(ctx)),
            _quickAddOption(ctx, Icons.handshake, 'Loan', AppColors.warning, () => _showAddLoanDialog(ctx)),
            _quickAddOption(ctx, Icons.show_chart, 'Investment', AppColors.tertiary, () => _showAddInvestmentDialog(ctx)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _quickAddOption(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }

  void _showAddExpenseDialog(BuildContext ctx) async {
    Navigator.pop(ctx);
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String category = '';
    String? selectedTag;
    final authService = context.read<AuthProvider>().authService;
    List<Map<String, dynamic>> categories = [];
    if (authService != null) {
      categories = await authService.database.listCategories(type: 'expense');
    }

    if (!context.mounted) return;
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
              const Text('Add Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.error),
                decoration: const InputDecoration(
                  hintText: '0.00', hintStyle: TextStyle(color: Colors.grey),
                  prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.error),
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
                  labelText: 'Description', labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                dropdownColor: AppColors.surfaceVariant,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Category', labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: categories.isEmpty
                    ? [const DropdownMenuItem(value: '', child: Text('No categories - add in Settings'))]
                    : categories.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem(value: c['name'] as String, child: Text(c['name'] as String));
                      }).toList(),
                onChanged: (v) => setModalState(() {
                  category = v!;
                  selectedTag = null;
                }),
              ),
              if (category.isNotEmpty && categories.any((c) => c['name'] == category && (c['tags'] as List?)?.isNotEmpty == true)) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedTag,
                  dropdownColor: AppColors.surfaceVariant,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Tag', labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true, fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...((categories.firstWhere((c) => c['name'] == category)['tags'] as List<String>? ?? [])).map<DropdownMenuItem<String>>((tag) {
                      return DropdownMenuItem(value: tag, child: Text(tag));
                    }),
                  ],
                  onChanged: (v) => setModalState(() => selectedTag = v),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text);
                    if (nameCtrl.text.isEmpty || amount == null || amount <= 0) return;
                    final srv = context.read<AuthProvider>().authService;
                    if (srv == null) return;
                    try {
                      await srv.database.createExpense({
                        'id': const Uuid().v4(),
                        'description': nameCtrl.text,
                        'amount': amount,
                        'category': category,
                        'tag': selectedTag,
                        'dateTime': selectedDate.toIso8601String(),
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense saved'), backgroundColor: AppColors.success),
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
                  child: const Text('Save Expense', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddIncomeDialog(BuildContext ctx) {
    Navigator.pop(ctx);
    final amountCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String frequency = 'one-time';

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
              const Text('Add Income', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                  labelText: 'Frequency', labelStyle: const TextStyle(color: AppColors.textSecondary),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text);
                    if (amount == null || amount <= 0) return;
                    final authService = context.read<AuthProvider>().authService;
                    if (authService == null) return;
                    try {
                      await authService.database.createIncome({
                        'id': const Uuid().v4(),
                        'amount': amount,
                        'source': sourceCtrl.text,
                        'frequency': frequency,
                        'dateTime': selectedDate.toIso8601String(),
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Income saved'), backgroundColor: AppColors.success),
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
                  child: const Text('Save Income', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddLoanDialog(BuildContext ctx) {
    Navigator.pop(ctx);
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
                  labelText: 'Person Name', labelStyle: const TextStyle(color: AppColors.textSecondary),
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

  void _showAddInvestmentDialog(BuildContext ctx) {
    Navigator.pop(ctx);
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
                  labelText: 'Instrument Name', labelStyle: const TextStyle(color: AppColors.textSecondary),
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
                  labelText: 'Type', labelStyle: const TextStyle(color: AppColors.textSecondary),
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
                        labelText: 'Units', labelStyle: const TextStyle(color: AppColors.textSecondary),
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
                        labelText: 'Price/Unit', labelStyle: const TextStyle(color: AppColors.textSecondary),
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

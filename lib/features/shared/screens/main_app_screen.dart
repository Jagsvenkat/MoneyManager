import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/app_provider.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/features/dashboard/screens/dashboard_screen.dart';
import 'package:money_manager/features/expenses/screens/expenses_screen.dart';
import 'package:money_manager/features/income/screens/income_screen.dart';
import 'package:money_manager/features/sync/screens/sync_screen.dart';
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
    SyncScreen(),
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
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Expenses'),
            BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Income'),
            BottomNavigationBarItem(icon: Icon(Icons.sync), label: 'Sync'),
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

  void _showAddExpenseDialog(BuildContext ctx) {
    Navigator.pop(ctx);
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'Food';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildFormSheet(
        title: 'Add Expense',
        color: AppColors.error,
        children: [
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
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: '0.00', hintStyle: TextStyle(color: Colors.grey),
              prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              border: InputBorder.none,
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
            items: const [
              DropdownMenuItem(value: 'Food', child: Text('Food')),
              DropdownMenuItem(value: 'Transport', child: Text('Transport')),
              DropdownMenuItem(value: 'Bills', child: Text('Bills')),
              DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (v) => category = v!,
          ),
        ],
        onSave: () async {
          final amount = double.tryParse(amountCtrl.text);
          if (nameCtrl.text.isEmpty || amount == null || amount <= 0) return;
          final authService = context.read<AuthProvider>().authService;
          if (authService == null) return;
          await authService.database.createExpense({
            'id': const Uuid().v4(),
            'description': nameCtrl.text,
            'amount': amount,
            'category': category,
            'dateTime': DateTime.now().toIso8601String(),
          });
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showAddIncomeDialog(BuildContext ctx) {
    Navigator.pop(ctx);
    final amountCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    String frequency = 'one-time';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildFormSheet(
        title: 'Add Income',
        color: AppColors.success,
        children: [
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
            onChanged: (v) => frequency = v!,
          ),
        ],
        onSave: () async {
          final amount = double.tryParse(amountCtrl.text);
          if (amount == null || amount <= 0) return;
          final authService = context.read<AuthProvider>().authService;
          if (authService == null) return;
          await authService.database.createIncome({
            'id': const Uuid().v4(),
            'amount': amount,
            'source': sourceCtrl.text,
            'frequency': frequency,
            'dateTime': DateTime.now().toIso8601String(),
          });
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showAddLoanDialog(BuildContext ctx) {
    Navigator.pop(ctx);
    final personCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String loanType = 'To Receive';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildFormSheet(
        title: 'Add Loan',
        color: AppColors.warning,
        children: [
          Row(
            children: ['To Receive', 'To Pay'].map((type) {
              final selected = loanType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => loanType = type,
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
        ],
        onSave: () async {
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
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showAddInvestmentDialog(BuildContext ctx) {
    Navigator.pop(ctx);
    final nameCtrl = TextEditingController();
    final unitsCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String type = 'equity';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildFormSheet(
        title: 'Add Investment',
        color: AppColors.tertiary,
        children: [
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
            onChanged: (v) => type = v!,
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
        ],
        onSave: () async {
          final units = double.tryParse(unitsCtrl.text);
          final price = double.tryParse(priceCtrl.text);
          if (nameCtrl.text.isEmpty || units == null || price == null) return;
          final authService = context.read<AuthProvider>().authService;
          if (authService == null) return;
          await authService.database.createInvestment({
            'id': const Uuid().v4(),
            'name': nameCtrl.text,
            'type': type,
            'units': units,
            'pricePerUnit': price,
            'dateTime': DateTime.now().toIso8601String(),
          });
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _buildFormSheet({
    required String title,
    required Color color,
    required List<Widget> children,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          ...children,
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onSave,
              child: Text('Save $title', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

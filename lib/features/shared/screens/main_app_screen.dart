import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:money_manager/features/shared/widgets/category_dependent_fields.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/app_provider.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/features/dashboard/screens/dashboard_screen.dart';
import 'package:money_manager/features/expenses/screens/expenses_screen.dart';
import 'package:money_manager/features/shared/screens/other_entries_screen.dart';
import 'package:money_manager/features/shared/screens/settings_screen.dart';
import 'package:money_manager/features/reports/screens/reports_screen.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    ExpensesScreen(),
    OtherEntriesScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: _screens[appProvider.currentTabIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: cs.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.surfaceContainerHighest.withValues(alpha: 0.3)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: appProvider.currentTabIndex,
          onTap: (index) => appProvider.setTabIndex(index),
          backgroundColor: cs.surface,
          selectedItemColor: cs.primary,
          unselectedItemColor: AppColors.textTertiary,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Expenses'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final authService = context.read<AuthProvider>().authService;
    List<Map<String, dynamic>> categories = [];
    if (authService != null) {
      categories = await authService.database.listCategories(type: 'expense');
    }
    String category = categories.isNotEmpty ? (categories.first['name'] as String) : '';
    String? selectedTag;
    Map<String, dynamic> metadata = {};

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Add Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.error),
                  decoration: InputDecoration(
                    hintText: '0.00', hintStyle: TextStyle(color: Colors.grey),
                    prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.error),
                    border: InputBorder.none,
                  ),
                ),

                Divider(color: cs.surfaceContainerHighest),
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
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: cs.onSurfaceVariant, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Description', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  filled: true, fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category.isEmpty ? null : category,
                dropdownColor: cs.surfaceContainerHighest,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Category', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  filled: true, fillColor: cs.surfaceContainerHighest,
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
                  value: selectedTag,
                  dropdownColor: cs.surfaceContainerHighest,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Tag', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
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
              buildCategoryFields(
                context: ctx,
                category: category,
                metadata: metadata,
                onChanged: () => setModalState(() {}),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.error,
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
                        'metadata': encodeMetadata(metadata),
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
                          SnackBar(content: Text('Error: $e'), backgroundColor: cs.error),
                        );
                      }
                    }
                  },
                  child: const Text('Save Expense', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
          },
        ),
      );
    },
    );
  }
}

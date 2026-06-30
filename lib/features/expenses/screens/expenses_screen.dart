import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/features/shared/widgets/category_dependent_fields.dart';
import 'package:money_manager/providers/auth_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String _sortOrder = 'newest';
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  double? _filterMinAmount;
  double? _filterMaxAmount;
  String? _filterTag;
  String? _filterMetadata;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    try {
      final cats = await authService.database.listCategories(type: 'expense');
      final expenses = await authService.database.listExpenses(
        categoryFilter: _selectedCategory != null && _selectedCategory != 'All' ? _selectedCategory : null,
        searchText: _searchController.text.isNotEmpty ? _searchController.text : null,
        tagFilter: _filterTag,
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        minAmount: _filterMinAmount,
        maxAmount: _filterMaxAmount,
        metadataFilter: _filterMetadata,
      );
      expenses.sort((a, b) {
        final da = DateTime.tryParse(a['dateTime'] as String? ?? '');
        final db = DateTime.tryParse(b['dateTime'] as String? ?? '');
        final amtA = (a['amount'] as num?)?.toDouble() ?? 0;
        final amtB = (b['amount'] as num?)?.toDouble() ?? 0;
        switch (_sortOrder) {
          case 'oldest':
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          case 'highest':
            return amtB.compareTo(amtA);
          case 'lowest':
            return amtA.compareTo(amtB);
          default: // newest
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
        }
      });
      if (mounted) setState(() { _categories = cats; _expenses = expenses; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddExpenseDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String category = _categories.isNotEmpty ? (_categories.first['name'] as String) : 'Other';
    String? tag;
    Map<String, dynamic> metadata = {};

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final cs = Theme.of(ctx).colorScheme;
              final recentAmounts = _expenses
                  .where((e) => e['category'] == category)
                  .map((e) => (e['amount'] as num?)?.toDouble() ?? 0)
                  .toSet()
                  .take(3)
                  .toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('Add Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 20),
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
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: '0.00', hintStyle: TextStyle(color: Colors.grey),
                      prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface),
                      border: InputBorder.none,
                    ),
                  ),
                  if (recentAmounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: recentAmounts.map((amt) => ActionChip(
                          label: Text('₹${amt.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          backgroundColor: cs.surfaceContainerHighest,
                          onPressed: () => setModalState(() { amountCtrl.text = amt.toStringAsFixed(2); }),
                        )).toList(),
                      ),
                    ),
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
                  DropdownButtonFormField<String>(
                    value: category,
                    dropdownColor: cs.surfaceContainerHighest,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Category', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      filled: true, fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c['name'] as String,
                      child: Text(c['name'] as String),
                    )).toList(),
                    onChanged: (v) => setModalState(() { category = v!; tag = null; }),
                  ),
                  if (category.isNotEmpty && _categories.any((c) => c['name'] == category && (c['tags'] as List?)?.isNotEmpty == true)) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tag,
                      dropdownColor: cs.surfaceContainerHighest,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Tag', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        filled: true, fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ...((_categories.firstWhere((c) => c['name'] == category)['tags'] as List<dynamic>? ?? []).cast<String>()).map((t) => DropdownMenuItem(value: t, child: Text(t))),
                      ],
                      onChanged: (v) => setModalState(() => tag = v),
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
                        final authService = context.read<AuthProvider>().authService;
                        if (authService == null) return;
                        try {
                          await authService.database.createExpense({
                            'id': const Uuid().v4(),
                            'description': nameCtrl.text,
                            'amount': amount,
                            'category': category,
                            'tag': tag,
                            'metadata': encodeMetadata(metadata),
                            'dateTime': selectedDate.toIso8601String(),
                          });
                          await _loadData();
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

  void _showEditExpenseDialog(Map<String, dynamic> expense) {
    final nameCtrl = TextEditingController(text: expense['description'] as String? ?? '');
    final amountCtrl = TextEditingController(text: expense['amount']?.toString() ?? '');
    DateTime selectedDate = DateTime.tryParse(expense['dateTime'] as String? ?? '') ?? DateTime.now();
    String category = expense['category'] as String? ?? (_categories.isNotEmpty ? (_categories.first['name'] as String) : 'Other');
    String? tag = expense['tag'] as String?;
    Map<String, dynamic> metadata = decodeMetadata(expense['metadata'] as String?);

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final cs = Theme.of(ctx).colorScheme;
              final recentAmounts = _expenses
                  .where((e) => e['category'] == category)
                  .map((e) => (e['amount'] as num?)?.toDouble() ?? 0)
                  .toSet()
                  .take(3)
                  .toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('Edit Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 20),
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
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: '0.00', hintStyle: TextStyle(color: Colors.grey),
                      prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface),
                      border: InputBorder.none,
                    ),
                  ),
                  if (recentAmounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: recentAmounts.map((amt) => ActionChip(
                          label: Text('₹${amt.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          backgroundColor: cs.surfaceContainerHighest,
                          onPressed: () => setModalState(() { amountCtrl.text = amt.toStringAsFixed(2); }),
                        )).toList(),
                      ),
                    ),
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
                  DropdownButtonFormField<String>(
                    value: category,
                    dropdownColor: cs.surfaceContainerHighest,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Category', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      filled: true, fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c['name'] as String,
                      child: Text(c['name'] as String),
                    )).toList(),
                    onChanged: (v) => setModalState(() { category = v!; tag = null; }),
                  ),
                  if (category.isNotEmpty && _categories.any((c) => c['name'] == category && (c['tags'] as List?)?.isNotEmpty == true)) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tag,
                      dropdownColor: cs.surfaceContainerHighest,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Tag', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        filled: true, fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ...((_categories.firstWhere((c) => c['name'] == category)['tags'] as List<dynamic>? ?? []).cast<String>()).map((t) => DropdownMenuItem(value: t, child: Text(t))),
                      ],
                      onChanged: (v) => setModalState(() => tag = v),
                    ),
                  ],
                  buildCategoryFields(
                    context: ctx,
                    category: category,
                    metadata: metadata,
                    onChanged: () => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                            side: BorderSide(color: cs.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showDeleteConfirmDialog(expense['id'] as String);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.error,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            final amount = double.tryParse(amountCtrl.text);
                            if (nameCtrl.text.isEmpty || amount == null || amount <= 0) return;
                            final authService = context.read<AuthProvider>().authService;
                            if (authService == null) return;
                            try {
                              await authService.database.updateExpense(expense['id'] as String, {
                                'description': nameCtrl.text,
                                'amount': amount,
                                'category': category,
                                'tag': tag,
                                'metadata': encodeMetadata(metadata),
                                'dateTime': selectedDate.toIso8601String(),
                              });
                              await _loadData();
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Expense updated'), backgroundColor: AppColors.success),
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
                          child: const Text('Update', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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

  void _showDeleteConfirmDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Delete Expense?', style: TextStyle(color: cs.onSurface)),
          content: Text('This action cannot be undone.', style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final authService = context.read<AuthProvider>().authService;
                if (authService == null) return;
                try {
                  await authService.database.deleteExpense(id);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense deleted'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: cs.error),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _duplicateExpense(Map<String, dynamic> exp) async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    try {
      await authService.database.createExpense({
        'id': const Uuid().v4(),
        'description': exp['description'],
        'amount': exp['amount'],
        'category': exp['category'],
        'tag': exp['tag'],
        'dateTime': DateTime.now().toIso8601String(),
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense duplicated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  void _showFilterDialog() {
    final cs = Theme.of(context).colorScheme;
    DateTime? tempStartDate = _filterStartDate;
    DateTime? tempEndDate = _filterEndDate;
    final minAmountCtrl = TextEditingController(text: _filterMinAmount?.toString() ?? '');
    final maxAmountCtrl = TextEditingController(text: _filterMaxAmount?.toString() ?? '');
    final tagCtrl = TextEditingController(text: _filterTag ?? '');
    final metadataCtrl = TextEditingController(text: _filterMetadata ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 20),
                  Text('Date Range', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempStartDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setModalState(() => tempStartDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: cs.onSurfaceVariant, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  tempStartDate != null ? DateFormat('dd MMM').format(tempStartDate!) : 'From',
                                  style: TextStyle(color: tempStartDate != null ? cs.onSurface : cs.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempEndDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setModalState(() => tempEndDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: cs.onSurfaceVariant, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  tempEndDate != null ? DateFormat('dd MMM').format(tempEndDate!) : 'To',
                                  style: TextStyle(color: tempEndDate != null ? cs.onSurface : cs.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Amount Range', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minAmountCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: cs.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Min',
                            hintStyle: TextStyle(color: cs.onSurfaceVariant),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxAmountCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: cs.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Max',
                            hintStyle: TextStyle(color: cs.onSurfaceVariant),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagCtrl,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Tag',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      hintText: 'Filter by tag...',
                      hintStyle: TextStyle(color: cs.onSurfaceVariant),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: metadataCtrl,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Metadata',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      hintText: 'Search metadata...',
                      hintStyle: TextStyle(color: cs.onSurfaceVariant),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            side: BorderSide(color: cs.surfaceContainerHighest),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            setState(() {
                              _filterStartDate = null;
                              _filterEndDate = null;
                              _filterMinAmount = null;
                              _filterMaxAmount = null;
                              _filterTag = null;
                              _filterMetadata = null;
                            });
                            _loadData();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            setState(() {
                              _filterStartDate = tempStartDate;
                              _filterEndDate = tempEndDate;
                              _filterMinAmount = double.tryParse(minAmountCtrl.text);
                              _filterMaxAmount = double.tryParse(maxAmountCtrl.text);
                              _filterTag = tagCtrl.text.isNotEmpty ? tagCtrl.text : null;
                              _filterMetadata = metadataCtrl.text.isNotEmpty ? metadataCtrl.text : null;
                            });
                            _loadData();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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

  String _buildDateFilterLabel() {
    if (_filterStartDate != null && _filterEndDate != null) {
      return '${DateFormat('dd MMM').format(_filterStartDate!)} - ${DateFormat('dd MMM').format(_filterEndDate!)}';
    } else if (_filterStartDate != null) {
      return 'From ${DateFormat('dd MMM').format(_filterStartDate!)}';
    } else if (_filterEndDate != null) {
      return 'Until ${DateFormat('dd MMM').format(_filterEndDate!)}';
    }
    return '';
  }

  String _buildAmountFilterLabel() {
    if (_filterMinAmount != null && _filterMaxAmount != null) {
      return '₹${_filterMinAmount!.toStringAsFixed(0)} - ₹${_filterMaxAmount!.toStringAsFixed(0)}';
    } else if (_filterMinAmount != null) {
      return 'Min ₹${_filterMinAmount!.toStringAsFixed(0)}';
    } else if (_filterMaxAmount != null) {
      return 'Max ₹${_filterMaxAmount!.toStringAsFixed(0)}';
    }
    return '';
  }

  Widget _activeFilterChip({required String label, required VoidCallback onRemove}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: cs.primary)),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 14, color: cs.primary),
            ),
          ],
        ),
      ),
    );
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
        title: Text('Expenses', style: TextStyle(color: cs.onSurface)),
        actions: [
          IconButton(icon: Icon(Icons.add, color: cs.primary), onPressed: _showAddExpenseDialog),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? _buildEmptyState()
                    : _buildExpenseList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text('No expenses yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tap + to add your first expense', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _expenses.length,
        itemBuilder: (context, index) {
          final exp = _expenses[index];
          final cat = exp['category'] as String? ?? 'Other';
          final tag = exp['tag'] as String?;
          final dt = DateTime.tryParse(exp['dateTime'] as String? ?? '');
          final catData = _categories.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c?['name'] == cat, orElse: () => null,
          );
          final color = Color(catData?['color'] as int? ?? AppColors.chartColors[7].toARGB32());
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: GestureDetector(
              onTap: () => _showEditExpenseDialog(exp),
              onLongPress: () => _duplicateExpense(exp),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt, color: color, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exp['description'] ?? 'Expense', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                        Row(
                          children: [
                            Text(cat, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                            if (tag != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(tag, style: TextStyle(color: color, fontSize: 9)),
                              ),
                            ],
                            if (dt != null) ...[
                              const SizedBox(width: 6),
                              Text(DateFormat('dd/MM').format(dt), style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text('₹${(exp['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortBar() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...['newest', 'oldest', 'highest', 'lowest'].map((s) {
            final icons = {'newest': Icons.arrow_downward, 'oldest': Icons.arrow_upward, 'highest': Icons.trending_up, 'lowest': Icons.trending_down};
            final labels = {'newest': 'Newest', 'oldest': 'Oldest', 'highest': 'Highest', 'lowest': 'Lowest'};
            final isSelected = _sortOrder == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() { _sortOrder = s; _loadData(); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary.withValues(alpha: 0.2) : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? cs.primary : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icons[s]!, size: 14, color: isSelected ? cs.primary : cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(labels[s]!, style: TextStyle(fontSize: 12, color: isSelected ? cs.primary : cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final cs = Theme.of(context).colorScheme;
    final hasFilters = _filterStartDate != null || _filterEndDate != null ||
        _filterMinAmount != null || _filterMaxAmount != null ||
        _filterTag != null;
    final filterCount = [
      if (_filterStartDate != null || _filterEndDate != null) 1,
      if (_filterMinAmount != null || _filterMaxAmount != null) 1,
      if (_filterTag != null) 1,
    ].length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search expenses...',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              border: InputBorder.none,
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
            onChanged: (_) => _loadData(),
          ),
          const SizedBox(height: 12),
          _buildSortBar(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_filterStartDate != null || _filterEndDate != null)
                        _activeFilterChip(
                          label: _buildDateFilterLabel(),
                          onRemove: () => setState(() { _filterStartDate = null; _filterEndDate = null; _loadData(); }),
                        ),
                      if (_filterMinAmount != null || _filterMaxAmount != null)
                        _activeFilterChip(
                          label: _buildAmountFilterLabel(),
                          onRemove: () => setState(() { _filterMinAmount = null; _filterMaxAmount = null; _loadData(); }),
                        ),
                      if (_filterTag != null)
                        _activeFilterChip(
                          label: 'Tag: $_filterTag',
                          onRemove: () => setState(() { _filterTag = null; _loadData(); }),
                        ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: _showFilterDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasFilters ? cs.primary.withValues(alpha: 0.2) : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hasFilters ? cs.primary : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list, size: 16, color: hasFilters ? cs.primary : cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        hasFilters ? 'Filters ($filterCount)' : 'Filters',
                        style: TextStyle(fontSize: 12, color: hasFilters ? cs.primary : cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() {
                    _filterStartDate = null; _filterEndDate = null;
                    _filterMinAmount = null; _filterMaxAmount = null;
                    _filterTag = null; _filterMetadata = null;
                    _loadData();
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('Reset', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', Icons.all_inclusive),
                const SizedBox(width: 8),
                ..._categories.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip(c['name'] as String, Icons.category),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, IconData icon) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategory = isSelected ? null : label;
        _loadData();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

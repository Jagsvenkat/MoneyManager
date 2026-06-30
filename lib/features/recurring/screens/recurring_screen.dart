import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/features/shared/widgets/category_dependent_fields.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _incomeCategories = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final srv = context.read<AuthProvider>().authService;
    if (srv == null) return;
    try {
      final results = await Future.wait([
        srv.database.listRecurringRules(),
        srv.database.listCategories(type: 'expense'),
        srv.database.listCategories(type: 'income'),
      ]);
      if (mounted) {
        setState(() {
          _rules = (results[0] as List).cast<Map<String, dynamic>>();
          _rules.sort((a, b) {
            final da = DateTime.tryParse((a['nextDueDate'] as String?) ?? '');
            final db = DateTime.tryParse((b['nextDueDate'] as String?) ?? '');
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
          _expenseCategories = (results[1] as List).cast<Map<String, dynamic>>();
          _incomeCategories = (results[2] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: Text('Recurring', style: TextStyle(color: cs.onSurface)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: cs.primary),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat, size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text('No recurring rules', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Set up automated income or expenses', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showAddDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Recurring'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: bg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRules,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _rules.length,
                    itemBuilder: (context, index) => _buildRuleCard(_rules[index]),
                  ),
                ),
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final cs = Theme.of(context).colorScheme;
    final isExpense = rule['type'] == 'expense';
    final color = isExpense ? cs.error : AppColors.success;
    final icon = isExpense ? Icons.receipt : Icons.trending_up;
    final isActive = rule['status'] == 'active';
    final nextDue = DateTime.tryParse(rule['nextDueDate'] as String? ?? '');
    final freqLabel = _freqLabel(rule['frequency'] as String? ?? 'monthly', (rule['interval'] as num?)?.toInt() ?? 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? Colors.transparent : cs.surfaceContainerHighest),
      ),
      child: GestureDetector(
        onTap: () => _showEditDialog(rule),
        onLongPress: () => _togglePause(rule),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isActive ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rule['description'] ?? (isExpense ? 'Expense' : 'Income'),
                          style: TextStyle(color: isActive ? cs.onSurface : cs.onSurfaceVariant, fontSize: 15),
                        ),
                      ),
                      if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('PAUSED', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(freqLabel, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                      if (nextDue != null) ...[
                        const SizedBox(width: 8),
                        Text('Next: ${DateFormat('dd MMM').format(nextDue)}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('₹${(rule['amount'] as num?)?.toStringAsFixed(0) ?? '0'}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _freqLabel(String freq, int interval) {
    if (interval == 1) {
      switch (freq) {
        case 'daily': return 'Daily';
        case 'weekly': return 'Weekly';
        case 'monthly': return 'Monthly';
        case 'yearly': return 'Yearly';
        default: return 'Every $interval days';
      }
    }
    return 'Every $interval ${freq}ly';
  }

  void _showAddDialog() => _showRuleDialog();
  void _showEditDialog(Map<String, dynamic> rule) => _showRuleDialog(rule: rule);

  void _showRuleDialog({Map<String, dynamic>? rule}) {
    final isExpense = rule == null || rule['type'] == 'expense';
    final amountCtrl = TextEditingController(text: rule?['amount']?.toString() ?? '');
    final descCtrl = TextEditingController(text: rule?['description'] as String? ?? '');
    DateTime startDate = DateTime.tryParse(rule?['startDate'] as String? ?? '') ?? DateTime.now();
    DateTime? endDate;
    if (rule != null) {
      final endStr = rule['endDate'] as String?;
      if (endStr != null && endStr.isNotEmpty) endDate = DateTime.tryParse(endStr);
    }
    DateTime nextDue = DateTime.tryParse(rule?['nextDueDate'] as String? ?? '') ?? startDate;
    String type = rule?['type'] as String? ?? 'expense';
    String frequency = rule?['frequency'] as String? ?? 'monthly';
    int interval = (rule?['interval'] as num?)?.toInt() ?? 1;
    String category = rule?['category'] as String? ?? '';
    Map<String, dynamic> metadata = decodeMetadata(rule?['metadata'] as String?);
    final isEdit = rule != null;

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
            builder: (ctx, setModalState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text(isEdit ? 'Edit Recurring' : 'Add Recurring', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 20),
                  // Type toggle
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() { type = 'expense'; category = ''; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: type == 'expense' ? cs.error.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: type == 'expense' ? cs.error : cs.surfaceContainerHighest),
                            ),
                            child: Center(
                              child: Text('Expense', style: TextStyle(
                                color: type == 'expense' ? cs.error : cs.onSurfaceVariant,
                                fontWeight: type == 'expense' ? FontWeight.bold : FontWeight.normal,
                              )),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() { type = 'income'; category = ''; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: type == 'income' ? AppColors.success.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: type == 'income' ? AppColors.success : cs.surfaceContainerHighest),
                            ),
                            child: Center(
                              child: Text('Income', style: TextStyle(
                                color: type == 'income' ? AppColors.success : cs.onSurfaceVariant,
                                fontWeight: type == 'income' ? FontWeight.bold : FontWeight.normal,
                              )),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: type == 'expense' ? cs.error : AppColors.success),
                    decoration: const InputDecoration(
                      hintText: '0.00', hintStyle: TextStyle(color: Colors.grey),
                      prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      border: InputBorder.none,
                    ),
                  ),
                  Divider(color: cs.surfaceContainerHighest),
                  // Description
                  TextField(
                    controller: descCtrl,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: type == 'expense' ? 'Description' : 'Source',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      filled: true, fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Start date
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context, initialDate: startDate,
                        firstDate: DateTime(2000), lastDate: DateTime(2100),
                        builder: (ctx, child) => child!,
                      );
                      if (picked != null) setModalState(() {
                        startDate = picked;
                        if (!isEdit) nextDue = picked;
                      });
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
                          Text('Start: ${DateFormat('dd MMM yyyy').format(startDate)}', style: TextStyle(color: cs.onSurface, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Next due date
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context, initialDate: nextDue,
                        firstDate: DateTime(2000), lastDate: DateTime(2100),
                        builder: (ctx, child) => child!,
                      );
                      if (picked != null) setModalState(() => nextDue = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event, color: cs.onSurfaceVariant, size: 18),
                          const SizedBox(width: 12),
                          Text('Next Due: ${DateFormat('dd MMM yyyy').format(nextDue)}', style: TextStyle(color: cs.onSurface, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // End date (optional)
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context, initialDate: endDate ?? startDate.add(const Duration(days: 365)),
                        firstDate: DateTime(2000), lastDate: DateTime(2100),
                        builder: (ctx, child) => child!,
                      );
                      if (picked != null) setModalState(() => endDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_note, color: cs.onSurfaceVariant, size: 18),
                          const SizedBox(width: 12),
                          Text(endDate != null ? 'End: ${DateFormat('dd MMM yyyy').format(endDate!)}' : 'No end date (tap to set)',
                            style: TextStyle(color: endDate != null ? cs.onSurface : cs.onSurfaceVariant, fontSize: 14)),
                          if (endDate != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setModalState(() => endDate = null),
                              child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Frequency dropdown
                  DropdownButtonFormField<String>(
                    value: frequency,
                    dropdownColor: cs.surfaceContainerHighest,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Frequency',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      filled: true, fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom Interval')),
                    ],
                    onChanged: (v) => setModalState(() => frequency = v!),
                  ),
                  if (frequency == 'custom') ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Interval (days)',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        filled: true, fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: cs.onSurface),
                      controller: TextEditingController(text: interval.toString()),
                      onChanged: (v) => setModalState(() => interval = int.tryParse(v) ?? 1),
                    ),
                  ],
                  // Category dropdown
                  ..._buildCategoryDropdown(type, category, setModalState, cs),
                  if (category.isNotEmpty)
                    buildCategoryFields(context: ctx, category: category, metadata: metadata, onChanged: () => setModalState(() {})),
                  const SizedBox(height: 16),
                  // Buttons
                  Row(
                    children: [
                      if (isEdit)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.error, side: BorderSide(color: cs.error),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showDeleteConfirm(rule['id'] as String);
                            },
                          ),
                        ),
                      if (isEdit) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: type == 'expense' ? cs.error : AppColors.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            final amount = double.tryParse(amountCtrl.text);
                            if (amount == null || amount <= 0 || descCtrl.text.isEmpty) return;
                            final srv = context.read<AuthProvider>().authService;
                            if (srv == null) return;
                            try {
                              final data = <String, dynamic>{
                                'id': rule?['id'] ?? const Uuid().v4(),
                                'type': type,
                                'amount': amount,
                                'description': descCtrl.text,
                                'category': category,
                                'frequency': frequency,
                                'interval': interval,
                                'startDate': startDate.toIso8601String(),
                                'nextDueDate': nextDue.toIso8601String(),
                                'status': 'active',
                                'metadata': encodeMetadata(metadata),
                              };
                              if (endDate != null) data['endDate'] = endDate!.toIso8601String();
                              if (isEdit) {
                                await srv.database.updateRecurringRule(rule['id'] as String, data);
                              } else {
                                await srv.database.createRecurringRule(data);
                              }
                              await _loadRules();
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isEdit ? 'Rule updated' : 'Rule saved'), backgroundColor: AppColors.success),
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
                          child: Text(isEdit ? 'Update' : 'Save', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
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
      },
    );
  }

  List<Widget> _buildCategoryDropdown(String type, String category, StateSetter setModalState, ColorScheme cs) {
    final categories = type == 'expense' ? _expenseCategories : _incomeCategories;
    if (categories.isEmpty) return [];
    return [
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: category.isEmpty ? null : category,
        dropdownColor: cs.surfaceContainerHighest,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          labelText: 'Category',
          labelStyle: TextStyle(color: cs.onSurfaceVariant),
          filled: true, fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        items: categories.map<DropdownMenuItem<String>>((c) {
          return DropdownMenuItem(value: c['name'] as String, child: Text(c['name'] as String));
        }).toList(),
        onChanged: (v) => setModalState(() => category = v!),
      ),
    ];
  }

  void _showDeleteConfirm(String id) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Delete Rule?', style: TextStyle(color: cs.onSurface)),
        content: Text('Future transactions will no longer be created.', style: TextStyle(color: cs.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final srv = context.read<AuthProvider>().authService;
              if (srv == null) return;
              await srv.database.deleteRecurringRule(id);
              await _loadRules();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rule deleted'), backgroundColor: AppColors.success),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePause(Map<String, dynamic> rule) async {
    final srv = context.read<AuthProvider>().authService;
    if (srv == null) return;
    final newStatus = rule['status'] == 'active' ? 'paused' : 'active';
    await srv.database.updateRecurringRule(rule['id'] as String, {'status': newStatus});
    await _loadRules();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'active' ? 'Rule resumed' : 'Rule paused'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

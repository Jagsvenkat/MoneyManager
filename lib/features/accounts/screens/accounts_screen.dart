import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  static const List<Color> _colorOptions = [
    Color(0xFF2DD4BF),
    Color(0xFF60A5FA),
    Color(0xFFFBBF24),
    Color(0xFFFB7185),
    Color(0xFFA78BFA),
    Color(0xFF22D3EE),
    Color(0xFFF472B6),
    Color(0xFF34D399),
  ];

  static const Map<String, IconData> _typeIcons = {
    'Cash': Icons.money,
    'Bank Account': Icons.account_balance,
    'UPI': Icons.phone_android,
    'Credit Card': Icons.credit_card,
    'Savings Account': Icons.savings,
    'Other': Icons.account_balance_wallet,
  };

  static const List<String> _accountTypes = [
    'Cash',
    'Bank Account',
    'UPI',
    'Credit Card',
    'Savings Account',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    try {
      final accounts = await authService.database.listAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
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
        title: Text('Accounts', style: TextStyle(color: cs.onSurface)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: cs.primary,
        onPressed: () => _showAccountDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAccounts,
                  color: cs.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      final type = account['type'] as String? ?? 'Other';
                      final icon = _typeIcons[type] ?? Icons.account_balance_wallet;
                      final color = Color(account['color'] as int? ?? 0xFF2DD4BF);
                      final balance = (account['balance'] as num?)?.toDouble() ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: GestureDetector(
                          onTap: () => _showAccountDialog(account: account),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(account['name'] as String? ?? '', style: TextStyle(color: cs.onSurface, fontSize: 15)),
                                    Text(type, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text('₹${NumberFormat('#,##0.00').format(balance)}',
                                  style: const TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text('No accounts', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Add your bank accounts, wallets, and payment methods',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAccountDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountDialog({Map<String, dynamic>? account}) {
    final nameCtrl = TextEditingController(text: account?['name'] as String? ?? '');
    final balanceCtrl = TextEditingController(text: account?['balance']?.toString() ?? '');
    final currencyCtrl = TextEditingController(text: account?['currency'] as String? ?? 'INR');
    String selectedType = account?['type'] as String? ?? 'Cash';
    Color selectedColor = Color(account?['color'] as int? ?? _colorOptions[0]);
    final isEdit = account != null;

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
            builder: (ctx, setModalState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(isEdit ? 'Edit Account' : 'Add Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: cs.surfaceContainerHighest,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Account Type',
                    labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  items: _accountTypes.map((t) => DropdownMenuItem(value: t, child: Row(
                    children: [
                      Icon(_typeIcons[t], size: 18, color: cs.onSurface),
                      const SizedBox(width: 8),
                      Text(t),
                    ],
                  ))).toList(),
                  onChanged: (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: '0.00', hintStyle: TextStyle(color: Colors.grey),
                    prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.onSurface),
                    border: InputBorder.none,
                  ),
                ),
                Divider(color: cs.surfaceContainerHighest),
                const SizedBox(height: 12),
                TextField(
                  controller: currencyCtrl,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Color', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colorOptions.map((c) {
                    final isSelected = selectedColor.value == c.value;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedColor = c),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: cs.onSurface, width: 2.5) : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (isEdit)
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
                            _showDeleteAccountConfirm(account['id'] as String);
                          },
                        ),
                      ),
                    if (isEdit) const SizedBox(width: 12),
                    Expanded(
                      flex: isEdit ? 2 : 3,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final balance = double.tryParse(balanceCtrl.text) ?? 0;
                          final srv = context.read<AuthProvider>().authService;
                          if (srv == null) return;
                          try {
                            final data = {
                              'id': account?['id'] ?? const Uuid().v4(),
                              'name': name,
                              'type': selectedType,
                              'balance': balance,
                              'currency': currencyCtrl.text.trim().isEmpty ? 'INR' : currencyCtrl.text.trim(),
                              'color': selectedColor.value,
                              'isActive': true,
                            };
                            if (isEdit) {
                              await srv.database.updateAccount(account['id'] as String, data);
                            } else {
                              await srv.database.createAccount(data);
                            }
                            await _loadAccounts();
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isEdit ? 'Account updated' : 'Account saved'), backgroundColor: AppColors.success),
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
        );
      },
    );
  }

  void _showDeleteAccountConfirm(String id) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Delete Account?', style: TextStyle(color: cs.onSurface)),
          content: Text('This action cannot be undone.', style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final srv = context.read<AuthProvider>().authService;
                if (srv == null) return;
                try {
                  await srv.database.deleteAccount(id);
                  await _loadAccounts();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account deleted'), backgroundColor: AppColors.success),
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
}

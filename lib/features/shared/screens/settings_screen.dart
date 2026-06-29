import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/config/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Account', [
            _buildSettingTile(Icons.person, 'Username', authProvider.currentUserId ?? 'Not set', onTap: () => _showUserDialog(authProvider)),
            _buildSettingTile(Icons.shield, 'Security', 'Encryption: Active', onTap: () => _showSecurityDialog()),
          ]),
          const SizedBox(height: 16),
          _buildSection('Preferences', [
            _buildSettingTile(Icons.currency_rupee, 'Currency', 'INR (₹)', onTap: () => _showCurrencyDialog()),
            _buildSettingTile(Icons.palette, 'Theme', 'Dark', onTap: () => _showThemeDialog()),
          ]),
          const SizedBox(height: 16),
          _buildSection('Categories', [
            _buildSettingTile(Icons.receipt_long, 'Expense Categories', 'Manage tags & options', onTap: () => context.push('${AppRoutes.categories}?type=expense')),
            _buildSettingTile(Icons.trending_up, 'Income Sources', 'Manage income sources', onTap: () => context.push('${AppRoutes.categories}?type=income')),
            _buildSettingTile(Icons.handshake, 'Loan Types', 'Manage loan categories', onTap: () => context.push('${AppRoutes.categories}?type=loan')),
            _buildSettingTile(Icons.show_chart, 'Investment Types', 'Manage investment types', onTap: () => context.push('${AppRoutes.categories}?type=investment')),
          ]),
          const SizedBox(height: 16),
          _buildSection('Data', [
            _buildSettingTile(Icons.file_download, 'Export Data', 'View summary', onTap: () => _exportData(authProvider)),
            _buildSettingTile(Icons.file_upload, 'Import Data', 'From backup', onTap: () => _showImportDialog()),
          ]),
          const SizedBox(height: 16),
          _buildSection('About', [
            _buildSettingTile(Icons.info, 'Version', '1.0.0'),
          ]),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeleteAccount(authProvider),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete Account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showUserDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Account', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User ID', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(authProvider.currentUserId ?? 'Not set', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Your data is stored locally and end-to-end encrypted.', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Security', style: TextStyle(color: AppColors.textPrimary)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\u2022 End-to-end encryption (XChaCha20-Poly1305)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            SizedBox(height: 8),
            Text('\u2022 Password-derived keys (PBKDF2-HMAC-SHA512)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            SizedBox(height: 8),
            Text('\u2022 Envelope encryption with unique data keys', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            SizedBox(height: 8),
            Text('\u2022 All data encrypted before storage', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            SizedBox(height: 16),
            Text('Your master key is derived from your password and never stored.', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Currency', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Indian Rupee (INR) is currently the only supported currency. International support coming soon.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Theme', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Dark theme is the default. Light theme support coming soon.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  Future<void> _exportData(AuthProvider authProvider) async {
    final srv = authProvider.authService;
    if (srv == null) return;

    try {
      final expenses = await srv.database.listExpenses();
      final incomes = await srv.database.listIncome();
      final loans = await srv.database.listLoans();
      final investments = await srv.database.listInvestments();

      final excel = Excel.createExcel();
      final dateFormat = DateFormat('yyyy-MM-dd');

      // --- EXPENSES sheet ---
      final expensesSheet = excel['Expenses'];
      expensesSheet.appendRow(['Date', 'Category', 'Tag', 'Description', 'Amount']);
      for (final e in expenses) {
        final dt = DateTime.tryParse(e['dateTime'] as String? ?? '');
        expensesSheet.appendRow([
          dt != null ? dateFormat.format(dt) : '',
          e['category'] as String? ?? '',
          e['tag'] as String? ?? '',
          e['description'] as String? ?? '',
          (e['amount'] ?? 0).toString(),
        ]);
      }

      // --- INCOME sheet ---
      final incomeSheet = excel['Income'];
      incomeSheet.appendRow(['Date', 'Source', 'Frequency', 'Amount']);
      for (final i in incomes) {
        final dt = DateTime.tryParse(i['dateTime'] as String? ?? '');
        incomeSheet.appendRow([
          dt != null ? dateFormat.format(dt) : '',
          i['source'] as String? ?? '',
          i['frequency'] as String? ?? '',
          (i['amount'] ?? 0).toString(),
        ]);
      }

      // --- LOANS sheet ---
      final loansSheet = excel['Loans'];
      loansSheet.appendRow(['Date', 'Person', 'Type', 'Amount']);
      for (final l in loans) {
        final dt = DateTime.tryParse(l['dateTime'] as String? ?? '');
        loansSheet.appendRow([
          dt != null ? dateFormat.format(dt) : '',
          l['personName'] as String? ?? '',
          l['loanType'] as String? ?? '',
          (l['amount'] ?? 0).toString(),
        ]);
      }

      // --- INVESTMENTS sheet ---
      final investmentsSheet = excel['Investments'];
      investmentsSheet.appendRow(['Date', 'Name', 'Type', 'Units', 'Price/Unit']);
      for (final inv in investments) {
        final dt = DateTime.tryParse(inv['dateTime'] as String? ?? '');
        investmentsSheet.appendRow([
          dt != null ? dateFormat.format(dt) : '',
          inv['name'] as String? ?? '',
          inv['type'] as String? ?? '',
          (inv['units'] ?? 0).toString(),
          (inv['pricePerUnit'] ?? 0).toString(),
        ]);
      }

      // Save to temp file and share
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/SJsaver_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to generate Excel file');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'SJsaver Export',
        text: 'Money Manager data export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Import Data', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Import from backup is not yet available. Export your data now and import it when this feature is ready.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(AuthProvider authProvider) {
    String typed = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will permanently delete all your data including expenses, income, loans, investments, and settings. This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              const Text('Type DELETE to confirm:', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setDialogState(() => typed = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            TextButton(
              onPressed: typed == 'DELETE' ? () async {
                Navigator.pop(ctx);
                await authProvider.deleteAccount();
                if (context.mounted) context.go('/register');
              } : null,
              style: TextButton.styleFrom(foregroundColor: typed == 'DELETE' ? AppColors.error : AppColors.textTertiary),
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
    );
  }
}

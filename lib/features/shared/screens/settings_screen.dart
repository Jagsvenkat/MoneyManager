import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/providers/app_provider.dart';
import 'package:money_manager/config/app_routes.dart';
import 'package:money_manager/core/security/secure_storage.dart';
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
  double _budgetAmount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBudget();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Settings', style: TextStyle(color: cs.onSurface)),
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
            _buildSettingTile(Icons.palette, 'Theme', _themeLabel(context.watch<AppProvider>().themeMode), onTap: () => _showThemeDialog()),
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
          _buildSection('Budget', [
            _buildSettingTile(Icons.account_balance_wallet, 'Monthly Budget', currentBudgetLabel, onTap: () => _showBudgetDialog()),
          ]),
          const SizedBox(height: 16),
          _buildSection('Backup', [
            _buildSettingTile(Icons.cloud_sync, 'GitHub Sync', 'Configure cloud backup', onTap: () => _showSyncConfigDialog()),
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
              label: Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
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
              label: Text('Delete Account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
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
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Account', style: TextStyle(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User ID', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 4),
            Text(authProvider.currentUserId ?? 'Not set', style: TextStyle(color: cs.onSurface, fontSize: 16)),
            const SizedBox(height: 16),
            Text('Your data is stored locally and end-to-end encrypted.', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: TextStyle(color: cs.primary))),
        ],
      ),
    );
  }

  void _showSecurityDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Security', style: TextStyle(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\u2022 End-to-end encryption (XChaCha20-Poly1305)', style: TextStyle(color: cs.onSurface, fontSize: 14)),
            SizedBox(height: 8),
            Text('\u2022 Password-derived keys (PBKDF2-HMAC-SHA512)', style: TextStyle(color: cs.onSurface, fontSize: 14)),
            SizedBox(height: 8),
            Text('\u2022 Envelope encryption with unique data keys', style: TextStyle(color: cs.onSurface, fontSize: 14)),
            SizedBox(height: 8),
            Text('\u2022 All data encrypted before storage', style: TextStyle(color: cs.onSurface, fontSize: 14)),
            SizedBox(height: 16),
            Text('Your master key is derived from your password and never stored.', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: TextStyle(color: cs.primary))),
        ],
      ),
    );
  }

  void _showCurrencyDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Currency', style: TextStyle(color: cs.onSurface)),
        content: Text('Indian Rupee (INR) is currently the only supported currency. International support coming soon.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: TextStyle(color: cs.primary))),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Light';
      case ThemeMode.system: return 'System';
      case ThemeMode.dark: return 'Dark';
    }
  }

  void _showThemeDialog() {
    final appProvider = context.read<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Theme', style: TextStyle(color: cs.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your preferred appearance.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 16),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                ],
                selected: {appProvider.themeMode},
                onSelectionChanged: (selected) {
                  final mode = selected.first;
                  appProvider.setThemeMode(mode);
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: TextStyle(color: cs.primary))),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(AuthProvider authProvider) async {
    final cs = Theme.of(context).colorScheme;
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

      if (kIsWeb) {
        // Web: trigger browser download via excel package
        excel.save(fileName: 'SJsaver_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
      } else {
        // Mobile: save to temp file and share
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
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: cs.error),
        );
      }
    }
  }

  void _showImportDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Import Data', style: TextStyle(color: cs.onSurface)),
        content: Text('Import from backup is not yet available. Export your data now and import it when this feature is ready.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: TextStyle(color: cs.primary))),
        ],
      ),
    );
  }

  void _showSyncConfigDialog() {
    final cs = Theme.of(context).colorScheme;
    final tokenCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    final repoCtrl = TextEditingController();
    bool tokenVisible = false;

    _loadSyncSettings(tokenCtrl, ownerCtrl, repoCtrl);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cs.surface,
          title: Text('GitHub Sync', style: TextStyle(color: cs.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Configure your GitHub repo for encrypted cloud backup.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: tokenCtrl,
                  obscureText: !tokenVisible,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Personal Access Token',
                    labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(tokenVisible ? Icons.visibility : Icons.visibility_off, color: cs.onSurfaceVariant),
                      onPressed: () => setDialogState(() => tokenVisible = !tokenVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ownerCtrl,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Repo Owner (username)',
                    labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: repoCtrl,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Repo Name',
                    labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant))),
            TextButton(
              onPressed: () async {
                await SecureStorageService.saveGitHubPat(userId: 'sync', encryptedPat: tokenCtrl.text.trim());
                await SecureStorageService.saveSyncSettings(owner: ownerCtrl.text.trim(), repoName: repoCtrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync settings saved'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: Text('Save', style: TextStyle(color: cs.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSyncSettings(TextEditingController tokenCtrl, TextEditingController ownerCtrl, TextEditingController repoCtrl) async {
    final token = await SecureStorageService.loadGitHubPat('sync');
    final settings = await SecureStorageService.loadSyncSettings();
    if (token != null) tokenCtrl.text = token;
    if (settings != null) {
      ownerCtrl.text = settings['owner'] as String? ?? '';
      repoCtrl.text = settings['repoName'] as String? ?? '';
    }
  }

  String get currentBudgetLabel => _budgetAmount > 0 ? '₹${_budgetAmount.toStringAsFixed(0)}/mo' : 'Not set';

  Future<void> _loadBudget() async {
    final srv = context.read<AuthProvider>().authService;
    if (srv == null) return;
    final budget = await srv.database.getMonthlyBudget();
    if (mounted) setState(() => _budgetAmount = budget);
  }

  void _showBudgetDialog() {
    final cs = Theme.of(context).colorScheme;
    final ctrl = TextEditingController(text: _budgetAmount > 0 ? _budgetAmount.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Monthly Budget', style: TextStyle(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set a monthly spending goal. Progress will show on Dashboard.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                prefixText: '₹ ',
                labelText: 'Budget Amount',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () { ctrl.clear(); Navigator.pop(ctx); }, child: Text('Remove', style: TextStyle(color: cs.error))),
          TextButton(onPressed: () async {
            final amt = double.tryParse(ctrl.text) ?? 0;
            final srv = context.read<AuthProvider>().authService;
            if (srv != null) await srv.database.setMonthlyBudget(amt);
            _loadBudget();
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: Text('Save', style: TextStyle(color: cs.primary))),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(AuthProvider authProvider) {
    final cs = Theme.of(context).colorScheme;
    String typed = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Delete Account', style: TextStyle(color: cs.error)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This will permanently delete all your data including expenses, income, loans, investments, and settings. This action cannot be undone.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 16),
              Text('Type DELETE to confirm:', style: TextStyle(color: cs.onSurface, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true, fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setDialogState(() => typed = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant))),
            TextButton(
              onPressed: typed == 'DELETE' ? () async {
                Navigator.pop(ctx);
                await authProvider.deleteAccount();
                if (context.mounted) context.go('/register');
              } : null,
              style: TextButton.styleFrom(foregroundColor: typed == 'DELETE' ? cs.error : AppColors.textTertiary),
              child: Text('Delete Everything'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: cs.primary),
      title: Text(title, style: TextStyle(color: cs.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
    );
  }
}

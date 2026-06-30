import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/providers/app_provider.dart';
import 'package:money_manager/config/app_routes.dart';
import 'package:money_manager/core/security/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:money_manager/core/services/github_sync_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:money_manager/core/services/report_service.dart';
import 'package:money_manager/core/services/excel_report_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

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
          _buildSection('Accounts', [
            _buildSettingTile(Icons.account_balance_wallet, 'Manage Accounts', 'Add, edit or remove wallets', onTap: () => _showAccountsDialog()),
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

  void _showAccountsDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: context.read<AuthProvider>().authService?.database.listAccounts() ?? Future.value([]),
            builder: (ctx2, snap) {
              final accounts = snap.data ?? [];
              return AlertDialog(
                backgroundColor: cs.surface,
                title: Text('Accounts', style: TextStyle(color: cs.onSurface)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: accounts.isEmpty
                      ? Text('No accounts yet. Tap + to add one.', style: TextStyle(color: cs.onSurfaceVariant))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: accounts.length,
                          itemBuilder: (ctx3, i) {
                            final acct = accounts[i];
                            final bal = (acct['balance'] as num?)?.toDouble() ?? 0;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(acct['color'] as int? ?? 0xFF60A5FA).withValues(alpha: 0.2),
                                child: Icon(Icons.account_balance, color: Color(acct['color'] as int? ?? 0xFF60A5FA), size: 20),
                              ),
                              title: Text(acct['name'] as String? ?? '', style: TextStyle(color: cs.onSurface)),
                              subtitle: Text(acct['type'] as String? ?? '', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                              trailing: Text('₹${bal.toStringAsFixed(2)}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                              onTap: () {
                                Navigator.pop(ctx);
                                _showAccountEditDialog(acct);
                              },
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: TextStyle(color: cs.onSurfaceVariant))),
                  TextButton(
                    onPressed: () { Navigator.pop(ctx); _showAccountEditDialog(null); },
                    child: Text('+ Add', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAccountEditDialog(Map<String, dynamic>? account) {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: account?['name'] as String? ?? '');
    final balCtrl = TextEditingController(text: account?['balance']?.toString() ?? '');
    String type = account?['type'] as String? ?? 'Bank Account';
    int color = account?['color'] as int? ?? 0xFF60A5FA;
    final isEdit = account != null;
    final types = ['Cash', 'Bank Account', 'UPI', 'Credit Card', 'Savings Account', 'Other'];
    final colorOptions = [0xFF60A5FA, 0xFF34D399, 0xFFFBBF24, 0xFFFB7185, 0xFFA78BFA, 0xFF22D3EE, 0xFFF472B6, 0xFF818CF8];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cs.surface,
          title: Text(isEdit ? 'Edit Account' : 'Add Account', style: TextStyle(color: cs.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Account Name', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  dropdownColor: cs.surfaceContainerHighest,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Type', labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true, fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: balCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      prefixText: '₹ ', labelText: 'Initial Balance',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      filled: true, fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text('Color', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colorOptions.map((c) => GestureDetector(
                    onTap: () => setDialogState(() => color = c),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: color == c ? cs.onSurface : Colors.transparent, width: 2),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            if (isEdit)
              TextButton(
                onPressed: () async {
                  final srv = context.read<AuthProvider>().authService;
                  if (srv != null) await srv.database.deleteAccount(account['id'] as String);
                  Navigator.pop(ctx);
                  _showAccountsDialog();
                },
                child: Text('Delete', style: TextStyle(color: cs.error)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant))),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                final srv = context.read<AuthProvider>().authService;
                if (srv == null) return;
                final data = {
                  'id': account?['id'] ?? const Uuid().v4(),
                  'name': nameCtrl.text,
                  'type': type,
                  'balance': double.tryParse(balCtrl.text) ?? 0,
                  'currency': 'INR',
                  'color': color,
                  'isActive': true,
                };
                if (isEdit) {
                  await srv.database.updateAccount(account['id'] as String, data);
                } else {
                  await srv.database.createAccount(data);
                }
                Navigator.pop(ctx);
                _showAccountsDialog();
              },
              child: Text(isEdit ? 'Save' : 'Add', style: TextStyle(color: cs.primary)),
            ),
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
      final now = DateTime.now();
      final startDate = DateTime(2020, 1, 1);
      final endDate = now;

      final reportService = ReportService(srv.database);
      final data = await reportService.generateReport(
        startDate: startDate,
        endDate: endDate,
        userId: authProvider.currentUserId ?? '',
      );

      final excelService = ExcelReportService();
      final bytes = excelService.generateWorkbook(data, options: const ExportOptions(
        fullWorkbook: true,
        includeRawTransactions: true,
        includeMetadata: false,
      ));
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final fileName = 'SJsaver_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        excel_pkg.Excel.decodeBytes(bytes!).save(fileName: fileName);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
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
        content: Text(
          'Select an Excel file (.xlsx) exported from SJsaver.\n\nThe file must contain sheets: Expenses, Income, Loans, Investments, Recurring, Accounts.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickAndImportFile();
            },
            child: Text('Select File', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportFile() async {
    final cs = Theme.of(context).colorScheme;

    try {
      FilePickerResult? result;
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file'), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      await _parseAndPreviewImport(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection error: $e'), backgroundColor: cs.error),
        );
      }
    }
  }

  Future<void> _parseAndPreviewImport(Uint8List bytes) async {
    final cs = Theme.of(context).colorScheme;

    try {
      final excel = excel_pkg.Excel.decodeBytes(bytes);
      final sheets = ['Expenses', 'Income', 'Loans', 'Investments', 'Recurring', 'Accounts'];

      // Parse rows from each sheet
      final Map<String, List<Map<String, String>>> parsed = {};
      int totalRows = 0;

      for (final sheetName in sheets) {
        final sheet = excel[sheetName];
        if (sheet == null || sheet.rows.length < 2) {
          parsed[sheetName] = [];
          continue;
        }

        final rows = sheet.rows;
        final header = rows.first.map((c) => c?.value?.toString().trim() ?? '').toList();
        final dataRows = rows.skip(1).where((r) => r.isNotEmpty && r.any((c) => c?.value?.toString().trim().isNotEmpty == true)).toList();

        final records = <Map<String, String>>[];
        for (final row in dataRows) {
          final record = <String, String>{};
          for (int i = 0; i < header.length && i < row.length; i++) {
            final val = row[i]?.value?.toString().trim() ?? '';
            if (val.isNotEmpty) record[header[i]] = val;
          }
          records.add(record);
        }
        parsed[sheetName] = records;
        totalRows += records.length;
      }

      if (totalRows == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid data found in file'), backgroundColor: AppColors.warning),
          );
        }
        return;
      }

      // Show preview dialog
      if (!mounted) return;
      _showImportPreview(parsed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse file: $e'), backgroundColor: cs.error),
        );
      }
    }
  }

  void _showImportPreview(Map<String, List<Map<String, String>>> parsed) {
    final cs = Theme.of(context).colorScheme;
    final total = parsed.values.fold(0, (s, l) => s + l.length);
    final uuid = const Uuid();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Import Preview', style: TextStyle(color: cs.onSurface)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Found $total records to import:', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...parsed.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(e.key, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value.length} rows', style: TextStyle(color: cs.onSurface)),
                    if (e.value.isEmpty) Text(' (empty)', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              Text(
                'Existing records with the same ID will be skipped.\nNew IDs will be generated for rows without one.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeImport(parsed);
            },
            child: Text('Import $total Records', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeImport(Map<String, List<Map<String, String>>> parsed) async {
    final srv = context.read<AuthProvider>().authService;
    if (srv == null) return;
    final cs = Theme.of(context).colorScheme;
    final uuid = const Uuid();
    final now = DateTime.now().toIso8601String();

    int imported = 0;
    int skipped = 0;
    int errors = 0;

    // Loading overlay
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Importing...'), backgroundColor: AppColors.info),
    );

    for (final entry in parsed.entries) {
      final sheetName = entry.key;
      final records = entry.value;

      for (final row in records) {
        try {
          final id = row['id']?.isNotEmpty == true ? row['id']! : '${sheetName.toLowerCase()}_${uuid.v4()}';

          // Check if already exists
          final exists = id.isNotEmpty ? await _recordExists(srv.database, sheetName, id) : false;
          if (exists) {
            skipped++;
            continue;
          }

          switch (sheetName) {
            case 'Expenses': {
              final dt = _parseDate(row['Date']);
              await srv.database.createExpense({
                'id': id,
                'description': row['Description'] ?? row['description'] ?? '',
                'amount': double.tryParse(row['Amount'] ?? '0') ?? 0,
                'category': row['Category'] ?? row['category'] ?? 'Other',
                'tag': row['Tag'] ?? row['tag'],
                'dateTime': dt?.toIso8601String() ?? now,
                'metadata': row['metadata'] ?? '',
                'createdAt': now,
                'updatedAt': now,
              });
              imported++;
              break;
            }
            case 'Income': {
              final dt = _parseDate(row['Date']);
              await srv.database.createIncome({
                'id': id,
                'source': row['Source'] ?? row['source'] ?? '',
                'amount': double.tryParse(row['Amount'] ?? '0') ?? 0,
                'frequency': row['Frequency'] ?? row['frequency'] ?? 'one-time',
                'category': row['Category'] ?? row['category'] ?? '',
                'dateTime': dt?.toIso8601String() ?? now,
                'metadata': row['metadata'] ?? '',
                'createdAt': now,
                'updatedAt': now,
              });
              imported++;
              break;
            }
            case 'Loans': {
              final dt = _parseDate(row['Date']);
              await srv.database.createLoan({
                'id': id,
                'personName': row['Person'] ?? row['personName'] ?? '',
                'amount': double.tryParse(row['Amount'] ?? '0') ?? 0,
                'loanType': row['Type'] ?? row['loanType'] ?? 'To Receive',
                'category': row['Category'] ?? row['category'] ?? '',
                'dateTime': dt?.toIso8601String() ?? now,
                'metadata': row['metadata'] ?? '',
                'createdAt': now,
                'updatedAt': now,
              });
              imported++;
              break;
            }
            case 'Investments': {
              final dt = _parseDate(row['Date']);
              await srv.database.createInvestment({
                'id': id,
                'name': row['Name'] ?? row['name'] ?? '',
                'type': row['Type'] ?? row['type'] ?? 'equity',
                'units': double.tryParse(row['Units'] ?? '0') ?? 0,
                'pricePerUnit': double.tryParse(row['Price/Unit'] ?? row['pricePerUnit'] ?? '0') ?? 0,
                'category': row['Category'] ?? row['category'] ?? '',
                'dateTime': dt?.toIso8601String() ?? now,
                'metadata': row['metadata'] ?? '',
                'createdAt': now,
                'updatedAt': now,
              });
              imported++;
              break;
            }
            case 'Recurring': {
              final start = _parseDate(row['Start Date']);
              final end = _parseDate(row['End Date']);
              final next = _parseDate(row['Next Due']);
              final freq = row['Frequency']?.toLowerCase() ?? 'monthly';
              await srv.database.createRecurringRule({
                'id': id,
                'type': row['Type']?.toLowerCase() ?? 'expense',
                'amount': double.tryParse(row['Amount'] ?? '0') ?? 0,
                'description': row['Description'] ?? '',
                'category': row['Category'] ?? '',
                'frequency': freq,
                'interval': int.tryParse(row['Interval'] ?? '1') ?? 1,
                'status': row['Status']?.toLowerCase() == 'paused' ? 'paused' : 'active',
                'startDate': start?.toIso8601String() ?? now,
                'endDate': end?.toIso8601String() ?? '',
                'nextDueDate': next?.toIso8601String() ?? now,
                'metadata': row['metadata'] ?? '',
                'createdAt': now,
                'updatedAt': now,
              });
              imported++;
              break;
            }
            case 'Accounts': {
              await srv.database.createAccount({
                'id': id,
                'name': row['Name'] ?? '',
                'type': row['Type'] ?? 'Bank Account',
                'balance': double.tryParse(row['Balance'] ?? '0') ?? 0,
                'currency': row['Currency'] ?? 'INR',
                'color': int.tryParse(row['Color'] ?? '0') ?? 0xFF60A5FA,
                'isActive': true,
                'createdAt': now,
                'updatedAt': now,
              });
              imported++;
              break;
            }
          }
        } catch (_) {
          errors++;
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported $imported · Skipped $skipped · Errors $errors'),
        backgroundColor: errors == 0 && skipped <= imported ? AppColors.success : AppColors.warning,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Try common formats
    for (final fmt in ['yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy', 'dd MMM yyyy', 'yyyy-MM-ddTHH:mm:ss']) {
      try { return DateFormat(fmt).parse(raw); } catch (_) {}
    }
    // Try Excel serial number
    final serial = int.tryParse(raw);
    if (serial != null && serial > 40000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial));
    }
    return null;
  }

  Future<bool> _recordExists(dynamic db, String sheetName, String id) async {
    try {
      switch (sheetName) {
        case 'Expenses': return (await db.readExpense(id)) != null;
        case 'Income': return (await db.readIncome(id)) != null;
        case 'Loans': return (await db.readLoan(id)) != null;
        case 'Investments': return (await db.readInvestment(id)) != null;
        case 'Recurring': return (await db.readRecurringRule(id)) != null;
        case 'Accounts': return (await db.readAccount(id)) != null;
      }
    } catch (_) {}
    return false;
  }

  void _showSyncConfigDialog() {
    final cs = Theme.of(context).colorScheme;
    final authProvider = context.read<AuthProvider>();
    _showGitHubSyncDialog(context, cs, authProvider);
  }

  Future<String?> _resolveToken(String userId) async {
    final oauth = await SecureStorageService.loadGitHubOAuthToken(userId);
    if (oauth != null) {
      final expiry = await SecureStorageService.loadGitHubOAuthExpiry(userId);
      if (expiry == null || expiry.isAfter(DateTime.now())) {
        return oauth;
      }
    }
    return await SecureStorageService.loadGitHubPat(userId);
  }

  void _showGitHubSyncDialog(BuildContext outerContext, ColorScheme cs, AuthProvider authProvider) {
    final ownerCtrl = TextEditingController();
    final repoCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();
    bool tokenVisible = false;
    bool usePat = false;
    String statusText = 'Loading...';
    SyncStatus currentStatus = SyncStatus.unknown;
    DateTime? lastSyncTime;
    bool isTesting = false;
    bool isPushing = false;
    bool isPulling = false;
    bool isOAuthFlow = false;
    String? oauthUserCode;
    String? oauthVerificationUri;
    Timer? oauthPollTimer;
    bool oauthExpired = false;

    Future<void> updateStatusText() async {
      final userId = authProvider.currentUserId ?? '';
      final settings = await SecureStorageService.loadSyncSettings();
      final token = await _resolveToken(userId);
      final meta = await SecureStorageService.loadSyncMetadata(userId);

      if (token == null || settings == null) {
        currentStatus = SyncStatus.notConfigured;
        statusText = 'Not configured';
        lastSyncTime = null;
        return;
      }

      final savedOwner = settings['owner'] as String? ?? '';
      final savedRepo = settings['repoName'] as String? ?? '';
      final savedBranch = settings['branch'] as String? ?? 'main';
      final savedGithubUser = settings['githubUsername'] as String?;
      ownerCtrl.text = savedOwner;
      repoCtrl.text = savedRepo;
      lastSyncTime = meta != null ? DateTime.tryParse(meta['lastSyncTimestamp'] as String? ?? '') : null;

      // Build a display label
      final githubLabel = savedGithubUser != null ? '@$savedGithubUser' : savedOwner;
      statusText = '$githubLabel → $savedOwner/$savedRepo ($savedBranch)';
      currentStatus = SyncStatus.connected;

      final srv = authProvider.authService;
      if (srv == null) { currentStatus = SyncStatus.unknown; statusText = 'Service unavailable'; return; }

      final syncService = GitHubSyncService(
        githubToken: token,
        repoOwner: savedOwner,
        repoName: savedRepo,
        db: srv.database,
        userId: userId,
        deviceId: srv.deviceId,
      );

      final result = await syncService.testConnection();
      currentStatus = result.status;
      if (result.success) {
        statusText = '${savedGithubUser != null ? '@$savedGithubUser ' : ''}$savedOwner/$savedRepo ($savedBranch) • Connected';
      } else {
        statusText = result.message;
      }
    }

    showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Trigger initial status load
          if (statusText == 'Loading...') {
            updateStatusText().then((_) => setDialogState(() {}));
          }

          return AlertDialog(
            backgroundColor: cs.surface,
            title: Row(
              children: [
                Icon(Icons.cloud_sync, color: _statusColor(currentStatus, cs), size: 22),
                const SizedBox(width: 8),
                Text('GitHub Sync', style: TextStyle(color: cs.onSurface, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor(currentStatus, cs).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(_statusIcon(currentStatus), color: _statusColor(currentStatus, cs), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(statusText, style: TextStyle(color: _statusColor(currentStatus, cs), fontSize: 13, fontWeight: FontWeight.w600)),
                                if (lastSyncTime != null)
                                  Text('Last sync: ${DateFormat('dd MMM yyyy HH:mm').format(lastSyncTime!)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OAuth section
                    if (kIsWeb && !isOAuthFlow && !oauthExpired) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: cs.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'OAuth login not available on web. Use PAT below.',
                                style: TextStyle(color: cs.error, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else if (!isOAuthFlow && !oauthExpired) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                setDialogState(() { isOAuthFlow = true; oauthExpired = false; });
                                await _startOAuthFlow(
                                  ctx, setDialogState, cs, authProvider,
                                  ownerCtrl.text.trim(), repoCtrl.text.trim(),
                                  (code, uri) { oauthUserCode = code; oauthVerificationUri = uri; },
                                  (expired) { oauthExpired = expired; },
                                  () { setDialogState(() { usePat = true; oauthExpired = true; }); },
                                );
                              },
                              icon: Icon(Icons.login, size: 18),
                              label: Text('Login with GitHub', style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(foregroundColor: cs.primary),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (isOAuthFlow && !oauthExpired) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text('Authorize GitHub', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            if (oauthUserCode != null) ...[
                              Text('Enter code:', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                              const SizedBox(height: 4),
                              SelectableText(oauthUserCode!, style: TextStyle(color: cs.primary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
                            ],
                            const SizedBox(height: 8),
                            if (oauthVerificationUri != null) ...[
                              TextButton.icon(
                                onPressed: () async {
                                  final uri = Uri.tryParse(oauthVerificationUri!);
                                  if (uri != null && await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                icon: Icon(Icons.open_in_browser, size: 16),
                                label: Text('Open $oauthVerificationUri', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text('Waiting for authorization...', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (oauthExpired) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Device code expired. Tap "Login with GitHub" to restart.', style: TextStyle(color: cs.error, fontSize: 12)),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Connected repo info / Change repo button
                    if (currentStatus == SyncStatus.connected) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final userId = authProvider.currentUserId ?? '';
                                final token = await _resolveToken(userId);
                                if (token == null) return;
                                final srv = authProvider.authService;
                                if (srv == null) return;
                                final result = await _showRepoPickerDialog(ctx, cs, token, authProvider, null);
                                if (result != null) {
                                  await SecureStorageService.saveSyncSettings(owner: result.$1, repoName: result.$2, branch: result.$3);
                                  setDialogState(() { statusText = 'Loading...'; });
                                }
                              },
                              icon: Icon(Icons.swap_horiz, size: 18),
                              label: Text('Change Repository', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: cs.primary),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Owner / Repo fields (manual entry fallback)
                      TextField(
                        controller: ownerCtrl,
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Repo Owner (username)',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          filled: true, fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: repoCtrl,
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Repo Name',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          filled: true, fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => setDialogState(() { usePat = !usePat; }),
                            icon: Icon(usePat ? Icons.expand_less : Icons.expand_more, size: 16),
                            label: Text(usePat ? 'Hide PAT input' : 'Use PAT instead', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),

                    if (usePat) ...[
                      TextField(
                        controller: tokenCtrl,
                        obscureText: !tokenVisible,
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Personal Access Token',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          filled: true, fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          suffixIcon: IconButton(
                            icon: Icon(tokenVisible ? Icons.visibility : Icons.visibility_off, color: cs.onSurfaceVariant, size: 20),
                            onPressed: () => setDialogState(() => tokenVisible = !tokenVisible),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Fine-grained PAT with Contents read/write access. Expires after 30 days.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
                      const SizedBox(height: 10),
                    ],

                    // Action buttons
                    const Divider(height: 16),
                    if (isTesting || isPushing || isPulling)
                      const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                setDialogState(() { isTesting = true; });
                                try {
                                  final userId = authProvider.currentUserId ?? '';
                                  final token = await _resolveToken(userId);
                                  if (token == null) {
                                    statusText = 'No token. Login with GitHub or enter PAT.';
                                    currentStatus = SyncStatus.notConfigured;
                                    setDialogState(() {});
                                    return;
                                  }
                                  final srv = authProvider.authService;
                                  if (srv == null) { setDialogState(() { isTesting = false; }); return; }
                                  final syncService = GitHubSyncService(
                                    githubToken: token,
                                    repoOwner: ownerCtrl.text.trim(),
                                    repoName: repoCtrl.text.trim(),
                                    db: srv.database,
                                    userId: userId,
                                    deviceId: srv.deviceId,
                                  );
                                  final result = await syncService.testConnection();
                                  statusText = result.message;
                                  currentStatus = result.status;
                                } catch (e) {
                                  statusText = 'Test failed: $e';
                                  currentStatus = SyncStatus.unknown;
                                }
                                setDialogState(() { isTesting = false; });
                              },
                              style: OutlinedButton.styleFrom(foregroundColor: cs.primary, padding: const EdgeInsets.symmetric(vertical: 10)),
                              child: Text('Test Connection', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: currentStatus != SyncStatus.connected ? null : () async {
                                setDialogState(() { isPushing = true; });
                                await _doSync(ctx, setDialogState, authProvider, ownerCtrl.text.trim(), repoCtrl.text.trim(), 'push',
                                  (s, t) { statusText = s; currentStatus = t; });
                                setDialogState(() { isPushing = false; });
                              },
                              style: TextButton.styleFrom(foregroundColor: cs.primary, padding: const EdgeInsets.symmetric(vertical: 10)),
                              child: Text('Push', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton(
                              onPressed: currentStatus != SyncStatus.connected ? null : () async {
                                setDialogState(() { isPulling = true; });
                                await _doSync(ctx, setDialogState, authProvider, ownerCtrl.text.trim(), repoCtrl.text.trim(), 'pull',
                                  (s, t) { statusText = s; currentStatus = t; });
                                setDialogState(() { isPulling = false; });
                              },
                              style: TextButton.styleFrom(foregroundColor: cs.primary, padding: const EdgeInsets.symmetric(vertical: 10)),
                              child: Text('Pull', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton(
                              onPressed: currentStatus != SyncStatus.connected ? null : () async {
                                setDialogState(() { isPushing = true; });
                                await _doSync(ctx, setDialogState, authProvider, ownerCtrl.text.trim(), repoCtrl.text.trim(), 'full',
                                  (s, t) { statusText = s; currentStatus = t; });
                                setDialogState(() { isPushing = false; });
                              },
                              style: TextButton.styleFrom(foregroundColor: cs.primary, padding: const EdgeInsets.symmetric(vertical: 10)),
                              child: Text('Full Sync', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final userId = authProvider.currentUserId ?? '';
                  await SecureStorageService.deleteGitHubCredentials(userId);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      const SnackBar(content: Text('GitHub credentials cleared'), backgroundColor: AppColors.success),
                    );
                  }
                },
                child: Text('Clear Credentials', style: TextStyle(color: cs.error, fontSize: 12)),
              ),
              TextButton(
                onPressed: () async {
                  // Save settings on close
                  final userId = authProvider.currentUserId ?? '';
                  if (ownerCtrl.text.trim().isNotEmpty && repoCtrl.text.trim().isNotEmpty) {
                    await SecureStorageService.saveSyncSettings(owner: ownerCtrl.text.trim(), repoName: repoCtrl.text.trim());
                  }
                  if (tokenCtrl.text.trim().isNotEmpty && usePat) {
                    await SecureStorageService.saveGitHubPat(userId: userId, encryptedPat: tokenCtrl.text.trim());
                  }
                  oauthPollTimer?.cancel();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text('Close', style: TextStyle(color: cs.primary)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startOAuthFlow(
    BuildContext ctx,
    void Function(VoidCallback) setDialogState,
    ColorScheme cs,
    AuthProvider authProvider,
    String owner,
    String repoName,
    void Function(String, String) setCodes,
    void Function(bool) setExpired,
    VoidCallback onUsePat,
  ) async {
    try {
      final srv = authProvider.authService;
      if (srv == null) { setExpired(true); setDialogState(() {}); return; }

      if (kIsWeb) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Text('OAuth not available on web. Use PAT instead.'),
              backgroundColor: cs.error,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Use PAT',
                textColor: Colors.white,
                onPressed: () {
                  setExpired(true);
                  onUsePat();
                },
              ),
            ),
          );
        }
        setExpired(true);
        setDialogState(() {});
        return;
      }

      const oauthClientId = 'Iv23li0VnDhVh0ITNcNP';

      final syncService = GitHubSyncService(
        githubToken: null,
        repoOwner: owner,
        repoName: repoName,
        db: srv.database,
        userId: authProvider.currentUserId ?? '',
        deviceId: srv.deviceId,
        oauthClientId: oauthClientId,
      );

      final deviceFlow = await syncService.startDeviceFlow();
      setCodes(deviceFlow.userCode, deviceFlow.verificationUri);
      setDialogState(() {});

      final uri = Uri.tryParse(deviceFlow.verificationUri);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      final deadline = DateTime.now().add(Duration(seconds: deviceFlow.expiresIn));
      int pollInterval = deviceFlow.interval;

      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(Duration(seconds: pollInterval));
        try {
          final tokenResponse = await syncService.pollForToken(deviceFlow.deviceCode);
          if (tokenResponse != null) {
            final userId = authProvider.currentUserId ?? '';
            final token = tokenResponse.accessToken;
            await SecureStorageService.saveGitHubOAuthToken(userId: userId, token: token);
            if (tokenResponse.expiresIn != null) {
              await SecureStorageService.saveGitHubOAuthExpiry(
                userId: userId,
                expiry: DateTime.now().add(Duration(seconds: tokenResponse.expiresIn!)),
              );
            }

            final authedService = syncService.withOAuthToken(token);
            final githubUser = await authedService.getCurrentUser();

            if (ctx.mounted) {
              final repoResult = await _showRepoPickerDialog(
                ctx,
                cs,
                token,
                authProvider,
                githubUser,
              );

              if (repoResult != null) {
                await SecureStorageService.saveSyncSettings(
                  owner: repoResult.$1,
                  repoName: repoResult.$2,
                  branch: repoResult.$3,
                  githubUsername: githubUser,
                );
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('GitHub sync ready: ${repoResult.$1}/${repoResult.$2}'), backgroundColor: AppColors.success),
                  );
                }
              } else {
                await SecureStorageService.deleteGitHubCredentials(userId);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Sync repo not configured. You can set it up later.'), backgroundColor: AppColors.warning),
                );
              }
            }
            setDialogState(() {});
            return;
          }
        } catch (e) {
          if (e.toString().contains('expired') || e.toString().contains('denied')) {
            setExpired(true);
            setDialogState(() {});
            return;
          }
          // On web, Dio connection errors from OAuth polling should show a clear message
          if (kIsWeb && e is DioException &&
              (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: const Text('OAuth failed because browser blocked the GitHub request. Use PAT or backend OAuth.'),
                  backgroundColor: cs.error,
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(
                    label: 'Use PAT',
                    textColor: Colors.white,
                    onPressed: () {
                      setExpired(true);
                      onUsePat();
                    },
                  ),
                ),
              );
            }
            setExpired(true);
            setDialogState(() {});
            return;
          }
          pollInterval = (pollInterval * 1.5).round();
        }
      }

      setExpired(true);
      setDialogState(() {});
    } on UnsupportedError catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: cs.error,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Use PAT',
              textColor: Colors.white,
              onPressed: () {
                setExpired(true);
                onUsePat();
              },
            ),
          ),
        );
      }
      setExpired(true);
      setDialogState(() {});
    } on DioException catch (e) {
      if (ctx.mounted) {
        String msg;
        if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
          msg = 'Network error: Check your internet connection.';
        } else if (e.response?.statusCode == 401) {
          msg = 'OAuth failed: Invalid client configuration.';
        } else {
          msg = 'OAuth request failed. Use PAT instead.';
        }
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: cs.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Use PAT',
              textColor: Colors.white,
              onPressed: () {
                setExpired(true);
                onUsePat();
              },
            ),
          ),
        );
      }
      setExpired(true);
      setDialogState(() {});
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('OAuth failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: cs.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Use PAT',
              textColor: Colors.white,
              onPressed: () {
                setExpired(true);
                onUsePat();
              },
            ),
          ),
        );
      }
      setExpired(true);
      setDialogState(() {});
    }
  }

  /// Show a repo picker dialog after GitHub OAuth succeeds.
  /// Returns (owner, repoName, branch) or null if cancelled.
  Future<(String, String, String)?> _showRepoPickerDialog(
    BuildContext ctx,
    ColorScheme cs,
    String token,
    AuthProvider authProvider,
    String? githubUser,
  ) async {
    final srv = authProvider.authService;
    if (srv == null) return null;

    final baseService = GitHubSyncService(
      githubToken: token,
      repoOwner: githubUser ?? '',
      repoName: 'sjsaver-sync',
      db: srv.database,
      userId: authProvider.currentUserId ?? '',
      deviceId: srv.deviceId,
    );

    // Phase 1: Check default repo sjsaver-sync
    final defaultExists = await baseService.repoExists(githubUser ?? '', 'sjsaver-sync');
    List<RepositoryInfo>? userRepos;

    return showDialog<(String, String, String)>(
      context: ctx,
      barrierDismissible: false,
      builder: (pickerCtx) => StatefulBuilder(
        builder: (pickerCtx, setPickerState) {
          String? selectedOption;
          String manualOwner = githubUser ?? '';
          String manualRepo = '';
          String manualBranch = 'main';
          List<RepositoryInfo> repoList = userRepos ?? [];
          bool isLoadingRepos = false;
          bool isCreating = false;
          String? errorMsg;

          return AlertDialog(
            backgroundColor: cs.surface,
            title: Row(
              children: [
                Icon(Icons.storage, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Text('Sync Repository', style: TextStyle(color: cs.onSurface, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (githubUser != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('GitHub: @$githubUser', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                          ],
                        ),
                      ),

                    Text('Choose where to store encrypted sync data:', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 12),

                    // Option 1: Default repo
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: selectedOption == 'default' ? cs.primary : cs.surfaceContainerHighest),
                        borderRadius: BorderRadius.circular(12),
                        color: selectedOption == 'default' ? cs.primaryContainer.withValues(alpha: 0.2) : Colors.transparent,
                      ),
                      child: RadioListTile<String>(
                        title: Text('Create / use default', style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('sjsaver-sync', style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('Private repo under your account', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                        value: 'default',
                        groupValue: selectedOption,
                        onChanged: (v) => setPickerState(() { selectedOption = v; errorMsg = null; }),
                        activeColor: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Option 2: Existing private repo
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: selectedOption == 'existing' ? cs.primary : cs.surfaceContainerHighest),
                        borderRadius: BorderRadius.circular(12),
                        color: selectedOption == 'existing' ? cs.primaryContainer.withValues(alpha: 0.2) : Colors.transparent,
                      ),
                      child: RadioListTile<String>(
                        title: Text('Select existing repo', style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('Pick from your private repos', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                        value: 'existing',
                        groupValue: selectedOption,
                        onChanged: (v) {
                          setPickerState(() { selectedOption = v; errorMsg = null; });
                          if (userRepos == null) {
                            setPickerState(() { isLoadingRepos = true; });
                            baseService.listRepos(type: 'private').then((repos) {
                              setPickerState(() { userRepos = repos; repoList = repos; isLoadingRepos = false; });
                            });
                          }
                        },
                        activeColor: cs.primary,
                      ),
                    ),

                    if (selectedOption == 'existing') ...[
                      const SizedBox(height: 8),
                      if (isLoadingRepos)
                        const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                      else if (repoList.isEmpty)
                        Text('No private repos found', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))
                      else
                        SizedBox(
                          height: 140,
                          child: ListView(
                            children: repoList.map((repo) => RadioListTile<String>(
                              title: Text('${repo.owner}/$repo.name', style: TextStyle(color: cs.onSurface, fontSize: 13)),
                              subtitle: Text(repo.isPrivate ? 'Private' : 'Public', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                              value: '${repo.owner}/${repo.name}',
                              groupValue: 'existing',
                              onChanged: (v) {
                                final parts = v!.split('/');
                                setPickerState(() { manualOwner = parts[0]; manualRepo = parts[1]; });
                              },
                              activeColor: cs.primary,
                              dense: true,
                            )).toList(),
                          ),
                        ),
                    ],

                    const SizedBox(height: 8),

                    // Option 3: Manual entry
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: selectedOption == 'manual' ? cs.primary : cs.surfaceContainerHighest),
                        borderRadius: BorderRadius.circular(12),
                        color: selectedOption == 'manual' ? cs.primaryContainer.withValues(alpha: 0.2) : Colors.transparent,
                      ),
                      child: RadioListTile<String>(
                        title: Text('Enter manually', style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('Specify owner, repo, and branch', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                        value: 'manual',
                        groupValue: selectedOption,
                        onChanged: (v) => setPickerState(() { selectedOption = v; errorMsg = null; }),
                        activeColor: cs.primary,
                      ),
                    ),

                    if (selectedOption == 'manual') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: manualOwner),
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Repo Owner', labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          filled: true, fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (v) => manualOwner = v.trim(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: manualRepo),
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Repo Name', labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          filled: true, fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (v) => manualRepo = v.trim(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: manualBranch),
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Branch', labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          filled: true, fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (v) => manualBranch = v.trim().isNotEmpty ? v.trim() : 'main',
                      ),
                    ],

                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(errorMsg!, style: TextStyle(color: cs.error, fontSize: 12)),
                    ],

                    if (isCreating) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(height: 4),
                      Center(child: Text('Creating repository...', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(pickerCtx),
                child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              TextButton(
                onPressed: selectedOption == null ? null : () async {
                  if (selectedOption == 'default') {
                    setPickerState(() { isCreating = true; errorMsg = null; });
                    if (defaultExists) {
                      Navigator.pop(pickerCtx, (githubUser ?? '', 'sjsaver-sync', 'main'));
                      return;
                    }
                    final created = await baseService.createRepo('sjsaver-sync');
                    if (created != null) {
                      Navigator.pop(pickerCtx, (created.owner, created.name, 'main'));
                    } else {
                      setPickerState(() {
                        errorMsg = 'Could not create sjsaver-sync. Ensure your token has repo creation permission.';
                        isCreating = false;
                      });
                    }
                    return;
                  }

                  if (selectedOption == 'manual' || selectedOption == 'existing') {
                    if (manualOwner.isEmpty || manualRepo.isEmpty) {
                      setPickerState(() { errorMsg = 'Owner and repo name are required.'; });
                      return;
                    }
                    setPickerState(() { isCreating = true; errorMsg = null; });
                    final exists = await baseService.repoExists(manualOwner, manualRepo);
                    if (exists) {
                      Navigator.pop(pickerCtx, (manualOwner, manualRepo, manualBranch));
                    } else {
                      setPickerState(() {
                        errorMsg = 'Repo $manualOwner/$manualRepo not found or not accessible.';
                        isCreating = false;
                      });
                    }
                    return;
                  }

                  setPickerState(() { errorMsg = 'Please select an option.'; });
                },
                child: Text('Confirm', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _doSync(
    BuildContext ctx,
    void Function(VoidCallback) setDialogState,
    AuthProvider authProvider,
    String owner,
    String repoName,
    String mode,
    void Function(String, SyncStatus) setStatus,
  ) async {
    final userId = authProvider.currentUserId ?? '';
    final token = await _resolveToken(userId);
    if (token == null) { setStatus('No token. Login or enter PAT.', SyncStatus.notConfigured); return; }

    final srv = authProvider.authService;
    if (srv == null) { setStatus('Service unavailable', SyncStatus.unknown); return; }

    final syncService = GitHubSyncService(
      githubToken: token,
      repoOwner: owner,
      repoName: repoName,
      db: srv.database,
      userId: userId,
      deviceId: srv.deviceId,
    );

    SyncResult result;
    if (mode == 'push') {
      result = await syncService.pushChanges(wrappingKey: srv.userMasterKey);
    } else if (mode == 'pull') {
      result = await syncService.pullChanges(wrappingKey: srv.userMasterKey);
    } else {
      result = await syncService.fullSync(wrappingKey: srv.userMasterKey);
    }

    if (result.success) {
      await SecureStorageService.saveSyncMetadata(
        userId: userId,
        lastSyncTimestamp: DateTime.now().toUtc().toIso8601String(),
        syncStatus: 'success',
      );
    }

    setStatus(result.success ? '${mode == 'full' ? 'Full sync' : '${mode} completed'}: ${result.recordsSync} records' : result.message, result.status);

    if (ctx.mounted) {
      final ctxCs = Theme.of(ctx).colorScheme;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(result.error ?? (result.success ? 'Sync successful' : 'Sync failed')),
          backgroundColor: result.success ? AppColors.success : ctxCs.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Color _statusColor(SyncStatus status, ColorScheme cs) {
    switch (status) {
      case SyncStatus.connected: return const Color(0xFF34D399);
      case SyncStatus.notConfigured: return cs.onSurfaceVariant;
      case SyncStatus.tokenExpired:
      case SyncStatus.tokenRevoked: return cs.error;
      case SyncStatus.repoNotFound: return const Color(0xFFFBBF24);
      case SyncStatus.missingPermission: return const Color(0xFFF97316);
      case SyncStatus.networkUnavailable: return cs.onSurfaceVariant;
      case SyncStatus.unknown: return cs.onSurfaceVariant;
    }
  }

  IconData _statusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.connected: return Icons.check_circle;
      case SyncStatus.notConfigured: return Icons.cloud_off;
      case SyncStatus.tokenExpired:
      case SyncStatus.tokenRevoked: return Icons.error;
      case SyncStatus.repoNotFound: return Icons.search_off;
      case SyncStatus.missingPermission: return Icons.lock;
      case SyncStatus.networkUnavailable: return Icons.wifi_off;
      case SyncStatus.unknown: return Icons.help;
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

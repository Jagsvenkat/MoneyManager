import 'package:flutter/material.dart';
import 'package:money_manager/config/app_colors.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  bool _isConfigured = false;
  final _tokenController = TextEditingController();
  final _repoController = TextEditingController();
  final _ownerController = TextEditingController();
  bool _tokenVisible = false;
  String? _lastSyncStatus;

  @override
  void dispose() {
    _tokenController.dispose();
    _repoController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sync', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isConfigured) _buildGitHubConfig(),
            if (_isConfigured) _buildSyncControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildGitHubConfig() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud, color: AppColors.primary),
              const SizedBox(width: 12),
              const Text('GitHub Backup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Configure GitHub to back up your encrypted data', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          TextField(
            controller: _tokenController,
            obscureText: !_tokenVisible,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'GitHub Personal Access Token',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true, fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: Icon(_tokenVisible ? Icons.visibility : Icons.visibility_off, color: AppColors.textSecondary),
                onPressed: () => setState(() => _tokenVisible = !_tokenVisible),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _ownerController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Repository Owner',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true, fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _repoController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Repository Name',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true, fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (_tokenController.text.isNotEmpty && _ownerController.text.isNotEmpty && _repoController.text.isNotEmpty) {
                  setState(() => _isConfigured = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('GitHub configured'), backgroundColor: AppColors.success),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GitHub Connected', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        Text('Your data is backed up securely', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.textTertiary),
                    onPressed: () => setState(() => _isConfigured = false),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _syncButton('Push', Icons.upload, AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _syncButton('Pull', Icons.download, AppColors.info),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _fullSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                      : const Icon(Icons.sync),
                  label: Text(_isSyncing ? 'Syncing...' : 'Full Sync'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: AppColors.background,
                    disabledBackgroundColor: AppColors.textTertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_lastSyncStatus != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 8),
                Text(_lastSyncStatus!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sync History', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('No sync history yet', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _syncButton(String label, IconData icon, Color color) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label started'), backgroundColor: color),
          );
        },
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _fullSync() async {
    setState(() {
      _isSyncing = true;
      _lastSyncStatus = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isSyncing = false;
      _lastSyncStatus = 'Last sync: ${DateTime.now().toLocal().toString().split('.')[0]}';
    });
  }
}

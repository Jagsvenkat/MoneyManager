import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:money_manager/config/app_colors.dart';
import 'package:money_manager/providers/auth_provider.dart';

class CategoriesScreen extends StatefulWidget {
  final String type;
  const CategoriesScreen({super.key, this.type = 'expense'});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    try {
      final cats = await authService.database.listCategories(type: widget.type);
      if (mounted) setState(() { _categories = cats; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${_typeLabel()} Categories', style: const TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: _showAddEditDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category, size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text('No ${widget.type} categories', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Tap + to add one', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) => _buildCategoryCard(index),
                ),
    );
  }

  String _typeLabel() {
    switch (widget.type) {
      case 'expense': return 'Expense';
      case 'income': return 'Income';
      case 'loan': return 'Loan';
      case 'investment': return 'Investment';
      default: return widget.type;
    }
  }

  Widget _buildCategoryCard(int index) {
    final cat = _categories[index];
    final color = Color(cat['color'] as int? ?? AppColors.chartColors[0].toARGB32());
    final tags = (cat['tags'] as List?)?.cast<String>() ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        backgroundColor: AppColors.surface,
        collapsedBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.category, color: color, size: 18),
        ),
        title: Text(cat['name'] as String? ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
              onPressed: () => _showAddTagDialog(cat['id'] as String, tags),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.textTertiary, size: 18),
              onPressed: () => _showAddEditDialog(category: cat),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              onPressed: () => _confirmDelete(cat['id'] as String),
            ),
          ],
        ),
        children: [
          if (tags.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No tags', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                  backgroundColor: color.withValues(alpha: 0.15),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.textTertiary),
                  onDeleted: () => _removeTag(cat['id'] as String, tags, tag),
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? category}) {
    final nameCtrl = TextEditingController(text: category?['name'] as String? ?? '');
    int selectedColor = category?['color'] as int? ?? AppColors.chartColors[0].toARGB32();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(category != null ? 'Edit Category' : 'Add Category', style: const TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Category name',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true, fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppColors.categoryColors.map((c) {
                  final isSelected = selectedColor == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c.toARGB32()),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final authService = context.read<AuthProvider>().authService;
                if (authService == null) return;
                final data = {
                  'id': category?['id'] ?? const Uuid().v4(),
                  'name': nameCtrl.text.trim(),
                  'type': widget.type,
                  'color': selectedColor,
                  'tags': category?['tags'] ?? [],
                };
                if (category != null) {
                  await authService.database.updateCategory(category['id'] as String, data);
                } else {
                  await authService.database.createCategory(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadCategories();
              },
              child: const Text('Save', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog(String catId, List<String> currentTags) {
    final tagCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Tag', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: tagCtrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Meals, Snacks, Popcorns',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true, fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              if (tagCtrl.text.trim().isEmpty) return;
              final authService = context.read<AuthProvider>().authService;
              if (authService == null) return;
              final updated = [...currentTags, tagCtrl.text.trim()];
              await authService.database.updateCategory(catId, {
                'tags': updated,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadCategories();
            },
            child: const Text('Add', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _removeTag(String catId, List<String> currentTags, String tag) async {
    final authService = context.read<AuthProvider>().authService;
    if (authService == null) return;
    await authService.database.updateCategory(catId, {
      'tags': currentTags.where((t) => t != tag).toList(),
    });
    await _loadCategories();
  }

  void _confirmDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Category?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This cannot be undone. Existing entries are not affected.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final authService = context.read<AuthProvider>().authService;
      if (authService == null) return;
      await authService.database.deleteCategory(id);
      await _loadCategories();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:money_manager/config/app_colors.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Food & Dining', 'color': AppColors.chartColors[0], 'icon': Icons.restaurant},
    {'name': 'Transport', 'color': AppColors.chartColors[1], 'icon': Icons.directions_car},
    {'name': 'Bills & Utilities', 'color': AppColors.chartColors[2], 'icon': Icons.receipt},
    {'name': 'Shopping', 'color': AppColors.chartColors[3], 'icon': Icons.shopping_bag},
    {'name': 'Entertainment', 'color': AppColors.chartColors[4], 'icon': Icons.movie},
    {'name': 'Health', 'color': AppColors.chartColors[5], 'icon': Icons.local_hospital},
    {'name': 'Education', 'color': AppColors.chartColors[6], 'icon': Icons.school},
    {'name': 'Other', 'color': AppColors.chartColors[7], 'icon': Icons.more_horiz},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Categories', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: () => _showAddCategoryDialog()),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (cat['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(cat['name'] as String, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.textTertiary, size: 18),
                  onPressed: () {},
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    Color selectedColor = AppColors.chartColors[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Add Category', style: TextStyle(color: AppColors.textPrimary)),
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
                children: AppColors.categoryColors.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = color),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: color,
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
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    _categories.add({'name': nameCtrl.text, 'color': selectedColor, 'icon': Icons.category});
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

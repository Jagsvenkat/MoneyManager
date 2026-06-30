import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:money_manager/config/category_extra_fields.dart';

/// Renders extra fields for a selected category.
/// Fields are defined in [categoryExtraFields] config.
/// [metadata] is a mutable map that stores field values.
/// [onChanged] is called when any field value changes.
Widget buildCategoryFields({
  required BuildContext context,
  required String category,
  required Map<String, dynamic> metadata,
  required VoidCallback onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  final fields = categoryExtraFields[category];
  if (fields == null || fields.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text('Details', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      ...fields.map((f) {
        final key = f['key'] as String;
        final label = f['label'] as String;
        final type = f['type'] as String;
        final options = f['options'] as List<String>?;

        if (type == 'select' && options != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<String>(
              value: metadata[key] as String?,
              dropdownColor: cs.surfaceContainerHighest,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: cs.onSurfaceVariant),
                filled: true, fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) { metadata[key] = v; onChanged(); },
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            initialValue: metadata[key] as String? ?? '',
            keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
            style: TextStyle(color: cs.onSurface, fontSize: 14),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: cs.onSurfaceVariant),
              filled: true, fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (v) { metadata[key] = v; },
          ),
        );
      }),
    ],
  );
}

/// Encode metadata map to JSON string for storage
String encodeMetadata(Map<String, dynamic> metadata) {
  if (metadata.isEmpty) return '';
  return jsonEncode(metadata);
}

/// Decode metadata JSON string from storage
Map<String, dynamic> decodeMetadata(String? json) {
  if (json == null || json.isEmpty) return {};
  try { return jsonDecode(json) as Map<String, dynamic>; } catch (_) { return {}; }
}

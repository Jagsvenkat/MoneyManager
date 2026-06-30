import 'validation_result.dart';

class Category {
  final String id;
  final String name;
  final String type;
  final int color;
  final List<String> tags;
  final String? createdAt;
  final String? updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.color = 0xFF60A5FA,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'expense',
      color: (json['color'] as int?) ?? 0xFF60A5FA,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'color': color,
    'tags': tags,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  ValidationResult validate({List<String>? existingNames}) {
    final errors = <String, String>{};
    if (id.isEmpty) errors['id'] = 'ID is required';
    if (name.trim().isEmpty) errors['name'] = 'Category name is required';
    if (existingNames != null && existingNames.any((n) => n.toLowerCase() == name.trim().toLowerCase())) {
      errors['name'] = 'A category with this name already exists';
    }
    if (type.trim().isEmpty) errors['type'] = 'Type is required';
    return errors.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  Category copyWith({String? id, String? name, String? type, int? color, List<String>? tags,
    String? createdAt, String? updatedAt}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

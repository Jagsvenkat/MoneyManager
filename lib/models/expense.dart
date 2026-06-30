import 'validation_result.dart';

class Expense {
  final String id;
  final String description;
  final double amount;
  final String category;
  final String? tag;
  final DateTime dateTime;
  final String? metadata;
  final String? accountId;
  final String? createdAt;
  final String? updatedAt;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    this.tag,
    required this.dateTime,
    this.metadata,
    this.accountId,
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      tag: json['tag'] as String?,
      dateTime: DateTime.tryParse(json['dateTime'] as String? ?? '') ?? DateTime.now(),
      metadata: json['metadata'] as String?,
      accountId: json['accountId'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'category': category,
    if (tag != null) 'tag': tag,
    'dateTime': dateTime.toIso8601String(),
    if (metadata != null) 'metadata': metadata,
    if (accountId != null) 'accountId': accountId,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  ValidationResult validate() {
    final errors = <String, String>{};
    if (id.isEmpty) errors['id'] = 'ID is required';
    if (description.trim().isEmpty) errors['description'] = 'Description is required';
    if (amount <= 0) errors['amount'] = 'Amount must be greater than zero';
    if (category.trim().isEmpty) errors['category'] = 'Category is required';
    return errors.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  Expense copyWith({String? id, String? description, double? amount, String? category, String? tag,
    DateTime? dateTime, String? metadata, String? accountId, String? createdAt, String? updatedAt}) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      tag: tag ?? this.tag,
      dateTime: dateTime ?? this.dateTime,
      metadata: metadata ?? this.metadata,
      accountId: accountId ?? this.accountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

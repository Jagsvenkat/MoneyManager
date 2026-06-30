import 'validation_result.dart';

class Income {
  final String id;
  final String source;
  final double amount;
  final String? category;
  final String? frequency;
  final DateTime dateTime;
  final String? metadata;
  final String? accountId;
  final String? createdAt;
  final String? updatedAt;

  Income({
    required this.id,
    required this.source,
    required this.amount,
    this.category,
    this.frequency,
    required this.dateTime,
    this.metadata,
    this.accountId,
    this.createdAt,
    this.updatedAt,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String?,
      frequency: json['frequency'] as String?,
      dateTime: DateTime.tryParse(json['dateTime'] as String? ?? '') ?? DateTime.now(),
      metadata: json['metadata'] as String?,
      accountId: json['accountId'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'amount': amount,
    if (category != null) 'category': category,
    if (frequency != null) 'frequency': frequency,
    'dateTime': dateTime.toIso8601String(),
    if (metadata != null) 'metadata': metadata,
    if (accountId != null) 'accountId': accountId,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  ValidationResult validate() {
    final errors = <String, String>{};
    if (id.isEmpty) errors['id'] = 'ID is required';
    if (source.trim().isEmpty) errors['source'] = 'Source is required';
    if (amount <= 0) errors['amount'] = 'Amount must be greater than zero';
    return errors.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  Income copyWith({String? id, String? source, double? amount, String? category, String? frequency,
    DateTime? dateTime, String? metadata, String? accountId, String? createdAt, String? updatedAt}) {
    return Income(
      id: id ?? this.id,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      dateTime: dateTime ?? this.dateTime,
      metadata: metadata ?? this.metadata,
      accountId: accountId ?? this.accountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

import 'validation_result.dart';

class Budget {
  final String category;
  final double amount;
  final String month; // format: "YYYY_MM"

  const Budget({
    required this.category,
    required this.amount,
    required this.month,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      category: json['category'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      month: json['month'] as String? ?? '${DateTime.now().year}_${DateTime.now().month}',
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'amount': amount,
    'month': month,
  };

  ValidationResult validate() {
    final errors = <String, String>{};
    if (category.trim().isEmpty) errors['category'] = 'Category is required';
    if (amount <= 0) errors['amount'] = 'Budget must be greater than zero';
    return errors.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  Budget copyWith({String? category, double? amount, String? month}) {
    return Budget(
      category: category ?? this.category,
      amount: amount ?? this.amount,
      month: month ?? this.month,
    );
  }
}

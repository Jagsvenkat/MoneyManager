import 'validation_result.dart';

class Loan {
  final String id;
  final String personName;
  final double amount;
  final double principal;
  final double interestRate;
  final double emiAmount;
  final double outstandingBalance;
  final String? category;
  final String? loanType;
  final String? direction; // 'lent' or 'borrowed'
  final String? lenderBorrower;
  final String? status; // 'active', 'closed', 'defaulted'
  final DateTime? dateTime;
  final DateTime? dueDate;
  final List<Map<String, dynamic>> repaymentHistory;
  final String? metadata;
  final String? createdAt;
  final String? updatedAt;

  Loan({
    required this.id,
    this.personName = '',
    this.amount = 0,
    this.principal = 0,
    this.interestRate = 0,
    this.emiAmount = 0,
    this.outstandingBalance = 0,
    this.category,
    this.loanType,
    this.direction,
    this.lenderBorrower,
    this.status,
    this.dateTime,
    this.dueDate,
    this.repaymentHistory = const [],
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'] as String? ?? '',
      personName: json['personName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      principal: (json['principal'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? 0,
      interestRate: (json['interestRate'] as num?)?.toDouble() ?? 0,
      emiAmount: (json['emiAmount'] as num?)?.toDouble() ?? 0,
      outstandingBalance: (json['outstandingBalance'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String?,
      loanType: json['loanType'] as String?,
      direction: json['direction'] as String?,
      lenderBorrower: json['lenderBorrower'] as String?,
      status: json['status'] as String?,
      dateTime: DateTime.tryParse(json['dateTime'] as String? ?? ''),
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
      repaymentHistory: (json['repaymentHistory'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      metadata: json['metadata'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'personName': personName,
    'amount': amount,
    'principal': principal,
    'interestRate': interestRate,
    'emiAmount': emiAmount,
    'outstandingBalance': outstandingBalance,
    if (category != null) 'category': category,
    if (loanType != null) 'loanType': loanType,
    if (direction != null) 'direction': direction,
    if (lenderBorrower != null) 'lenderBorrower': lenderBorrower,
    if (status != null) 'status': status,
    if (dateTime != null) 'dateTime': dateTime!.toIso8601String(),
    if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
    'repaymentHistory': repaymentHistory,
    if (metadata != null) 'metadata': metadata,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  ValidationResult validate() {
    final errors = <String, String>{};
    if (id.isEmpty) errors['id'] = 'ID is required';
    if (personName.trim().isEmpty && (lenderBorrower == null || lenderBorrower!.trim().isEmpty)) {
      errors['personName'] = 'Person name is required';
    }
    if (amount <= 0 && principal <= 0) errors['amount'] = 'Amount must be greater than zero';
    return errors.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  Loan copyWith({String? id, String? personName, double? amount, double? principal, double? interestRate,
    double? emiAmount, double? outstandingBalance, String? category, String? loanType, String? direction,
    String? lenderBorrower, String? status, DateTime? dateTime, DateTime? dueDate,
    List<Map<String, dynamic>>? repaymentHistory, String? metadata, String? createdAt, String? updatedAt}) {
    return Loan(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      principal: principal ?? this.principal,
      interestRate: interestRate ?? this.interestRate,
      emiAmount: emiAmount ?? this.emiAmount,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      category: category ?? this.category,
      loanType: loanType ?? this.loanType,
      direction: direction ?? this.direction,
      lenderBorrower: lenderBorrower ?? this.lenderBorrower,
      status: status ?? this.status,
      dateTime: dateTime ?? this.dateTime,
      dueDate: dueDate ?? this.dueDate,
      repaymentHistory: repaymentHistory ?? this.repaymentHistory,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

import 'package:hive_ce/hive_ce.dart';

part 'models.g.dart'; // This connects to the background generator we downloaded

@HiveType(typeId: 0)
class TransactionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String type; // Income, Expense, Investment

  @HiveField(4)
  final String category;

  @HiveField(5)
  final DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.timestamp,
  });
}

@HiveType(typeId: 1)
class LoanModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String personName; // Lender or Borrower

  @HiveField(2)
  final double totalAmount;

  @HiveField(3)
  final double remainingAmount;

  @HiveField(4)
  final String loanType; // 'To Pay' or 'To Receive'

  @HiveField(5)
  final DateTime dueDate;

  LoanModel({
    required this.id,
    required this.personName,
    required this.totalAmount,
    required this.remainingAmount,
    required this.loanType,
    required this.dueDate,
  });
}

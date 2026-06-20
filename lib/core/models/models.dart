// Core data models for Money Manager
// All models include version metadata for migrations

import 'package:hive_ce/hive.dart';

part 'models.g.dart';

/// Expense record
@HiveType(typeId: 0)
class Expense extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late double amount;
  
  @HiveField(3)
  late String currency;
  
  @HiveField(4)
  late String category;
  
  @HiveField(5)
  late String? subcategory;
  
  @HiveField(6)
  late DateTime dateTime;
  
  @HiveField(7)
  late String? merchant;
  
  @HiveField(8)
  late String? notes;
  
  @HiveField(9)
  late String? paymentMethod;
  
  @HiveField(10)
  late List<String>? tags;
  
  @HiveField(11)
  late DateTime createdAt;
  
  @HiveField(12)
  late DateTime updatedAt;
  
  @HiveField(13)
  late String deviceId;
  
  @HiveField(14)
  late String syncStatus; // 'pending', 'synced', 'conflict'
  
  @HiveField(15)
  late String version;
  
  @HiveField(16)
  late bool isReconciled; // Marked as reconciled with bank statement
}

/// Income record
@HiveType(typeId: 1)
class Income extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late double amount;
  
  @HiveField(3)
  late String currency;
  
  @HiveField(4)
  late String source; // Salary, Freelance, Investment, etc.
  
  @HiveField(5)
  late DateTime dateTime;
  
  @HiveField(6)
  late String? frequency; // 'one-time', 'monthly', 'yearly'
  
  @HiveField(7)
  late String? notes;
  
  @HiveField(8)
  late DateTime createdAt;
  
  @HiveField(9)
  late DateTime updatedAt;
  
  @HiveField(10)
  late String deviceId;
  
  @HiveField(11)
  late String syncStatus;
  
  @HiveField(12)
  late String version;
}

/// Balance adjustment
@HiveType(typeId: 2)
class Balance extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late double balanceAmount;
  
  @HiveField(3)
  late String currency;
  
  @HiveField(4)
  late DateTime effectiveDate;
  
  @HiveField(5)
  late String? source; // 'bank statement', 'manual entry', etc.
  
  @HiveField(6)
  late String? notes;
  
  @HiveField(7)
  late DateTime createdAt;
  
  @HiveField(8)
  late DateTime updatedAt;
  
  @HiveField(9)
  late String version;
}

/// Loan record with repayment tracking
@HiveType(typeId: 3)
class Loan extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late double principalAmount;
  
  @HiveField(3)
  late double outstandingAmount;
  
  @HiveField(4)
  late String currency;
  
  @HiveField(5)
  late String lender; // Bank, Friend, etc.
  
  @HiveField(6)
  late DateTime startDate;
  
  @HiveField(7)
  late DateTime? dueDate;
  
  @HiveField(8)
  late double? interestRate; // Annual percentage
  
  @HiveField(9)
  late String? repaymentSchedule; // JSON serialized schedule
  
  @HiveField(10)
  late String? notes;
  
  @HiveField(11)
  late DateTime createdAt;
  
  @HiveField(12)
  late DateTime updatedAt;
  
  @HiveField(13)
  late String deviceId;
  
  @HiveField(14)
  late String syncStatus;
  
  @HiveField(15)
  late String version;
}

/// Investment holding
@HiveType(typeId: 4)
class Investment extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late String instrument; // Stock, Mutual Fund, etc.
  
  @HiveField(3)
  late String type; // 'equity', 'debt', 'commodity', etc.
  
  @HiveField(4)
  late double units;
  
  @HiveField(5)
  late double purchasePrice;
  
  @HiveField(6)
  late double currentPrice;
  
  @HiveField(7)
  late String currency;
  
  @HiveField(8)
  late DateTime purchaseDate;
  
  @HiveField(9)
  late String? notes;
  
  @HiveField(10)
  late DateTime createdAt;
  
  @HiveField(11)
  late DateTime updatedAt;
  
  @HiveField(12)
  late String deviceId;
  
  @HiveField(13)
  late String syncStatus;
  
  @HiveField(14)
  late String version;
}

/// Expense category with customization
@HiveType(typeId: 5)
class Category extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late String name;
  
  @HiveField(3)
  late String? color; // HEX format
  
  @HiveField(4)
  late String? icon; // Icon name or emoji
  
  @HiveField(5)
  late List<String>? defaultSubcategories;
  
  @HiveField(6)
  late DateTime createdAt;
  
  @HiveField(7)
  late DateTime updatedAt;
  
  @HiveField(8)
  late String version;
}

/// Sync conflict record
@HiveType(typeId: 6)
class SyncConflict extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late String recordId;
  
  @HiveField(3)
  late String recordType; // 'expense', 'income', etc.
  
  @HiveField(4)
  late String localVersion; // JSON encoded encrypted envelope
  
  @HiveField(5)
  late String remoteVersion; // JSON encoded encrypted envelope
  
  @HiveField(6)
  late DateTime conflictTimestamp;
  
  @HiveField(7)
  late String status; // 'pending', 'resolved'
}

/// User session metadata
@HiveType(typeId: 7)
class UserSession extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late String deviceId;
  
  @HiveField(3)
  late DateTime lastActive;
  
  @HiveField(4)
  late String? lastSyncTimestamp;
  
  @HiveField(5)
  late String syncStatus; // 'offline', 'syncing', 'synced'
}

class SyncPayload {
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> income;
  final List<Map<String, dynamic>> balances;
  final List<Map<String, dynamic>> loans;
  final List<Map<String, dynamic>> investments;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> recurringRules;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transfers;
  final List<Map<String, dynamic>> tombstones;
  final String syncedAt;
  final String userId;
  final String deviceId;

  SyncPayload({
    this.expenses = const [],
    this.income = const [],
    this.balances = const [],
    this.loans = const [],
    this.investments = const [],
    this.categories = const [],
    this.recurringRules = const [],
    this.accounts = const [],
    this.transfers = const [],
    this.tombstones = const [],
    String? syncedAt,
    this.userId = '',
    this.deviceId = '',
  }) : syncedAt = syncedAt ?? DateTime.now().toUtc().toIso8601String();

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    return SyncPayload(
      expenses: (json['expenses'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      income: (json['income'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      balances: (json['balances'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      loans: (json['loans'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      investments: (json['investments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      categories: (json['categories'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      recurringRules: (json['recurring_rules'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      accounts: (json['accounts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      transfers: (json['transfers'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      tombstones: (json['tombstones'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      syncedAt: json['syncedAt'] as String?,
      userId: json['userId'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'expenses': expenses,
    'income': income,
    'balances': balances,
    'loans': loans,
    'investments': investments,
    'categories': categories,
    'recurring_rules': recurringRules,
    'accounts': accounts,
    'transfers': transfers,
    'tombstones': tombstones,
    'syncedAt': syncedAt,
    'userId': userId,
    'deviceId': deviceId,
  };
}

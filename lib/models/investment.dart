import 'validation_result.dart';

class Investment {
  final String id;
  final String name;
  final double units;
  final double buyPrice;
  final double currentPrice;
  final double pricePerUnit;
  final String? type;
  final String? category;
  final String? symbol;
  final String? notes;
  final DateTime? dateTime;
  final DateTime? purchaseDate;
  final String? metadata;
  final String? createdAt;
  final String? updatedAt;

  Investment({
    required this.id,
    required this.name,
    this.units = 0,
    this.buyPrice = 0,
    this.currentPrice = 0,
    this.pricePerUnit = 0,
    this.type,
    this.category,
    this.symbol,
    this.notes,
    this.dateTime,
    this.purchaseDate,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  double get currentValue => units * (currentPrice > 0 ? currentPrice : buyPrice);
  double get investedValue => units * buyPrice;
  double get gainLoss => currentValue - investedValue;
  double get gainLossPercent => investedValue > 0 ? (gainLoss / investedValue) * 100 : 0;

  factory Investment.fromJson(Map<String, dynamic> json) {
    final buyPrice = (json['buyPrice'] as num?)?.toDouble() ?? (json['pricePerUnit'] as num?)?.toDouble() ?? 0;
    return Investment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      units: (json['units'] as num?)?.toDouble() ?? 0,
      buyPrice: buyPrice,
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? buyPrice,
      pricePerUnit: (json['pricePerUnit'] as num?)?.toDouble() ?? buyPrice,
      type: json['type'] as String?,
      category: json['category'] as String?,
      symbol: json['symbol'] as String?,
      notes: json['notes'] as String?,
      dateTime: DateTime.tryParse(json['dateTime'] as String? ?? ''),
      purchaseDate: DateTime.tryParse(json['purchaseDate'] as String? ?? ''),
      metadata: json['metadata'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'units': units,
    'buyPrice': buyPrice,
    'currentPrice': currentPrice,
    'pricePerUnit': pricePerUnit,
    if (type != null) 'type': type,
    if (category != null) 'category': category,
    if (symbol != null) 'symbol': symbol,
    if (notes != null) 'notes': notes,
    if (dateTime != null) 'dateTime': dateTime!.toIso8601String(),
    if (purchaseDate != null) 'purchaseDate': purchaseDate!.toIso8601String(),
    if (metadata != null) 'metadata': metadata,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  ValidationResult validate() {
    final errors = <String, String>{};
    if (id.isEmpty) errors['id'] = 'ID is required';
    if (name.trim().isEmpty) errors['name'] = 'Name is required';
    if (units <= 0) errors['units'] = 'Units must be greater than zero';
    if (buyPrice <= 0) errors['buyPrice'] = 'Buy price must be greater than zero';
    return errors.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  Investment copyWith({String? id, String? name, double? units, double? buyPrice, double? currentPrice,
    double? pricePerUnit, String? type, String? category, String? symbol, String? notes,
    DateTime? dateTime, DateTime? purchaseDate, String? metadata, String? createdAt, String? updatedAt}) {
    return Investment(
      id: id ?? this.id,
      name: name ?? this.name,
      units: units ?? this.units,
      buyPrice: buyPrice ?? this.buyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      type: type ?? this.type,
      category: category ?? this.category,
      symbol: symbol ?? this.symbol,
      notes: notes ?? this.notes,
      dateTime: dateTime ?? this.dateTime,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

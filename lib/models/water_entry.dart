import 'dart:convert';

/// Represents a single recorded beverage or water intake.
class WaterEntry {
  final String id;
  final int amountMl;
  final DateTime timestamp;
  final String beverageType; // e.g., 'Water', 'Tea', 'Coffee', 'Juice'

  const WaterEntry({
    required this.id,
    required this.amountMl,
    required this.timestamp,
    this.beverageType = 'Water',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amountMl': amountMl,
      'timestamp': timestamp.toIso8601String(),
      'beverageType': beverageType,
    };
  }

  factory WaterEntry.fromMap(Map<String, dynamic> map) {
    return WaterEntry(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      amountMl: (map['amountMl'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      beverageType: map['beverageType'] as String? ?? 'Water',
    );
  }

  String toJson() => json.encode(toMap());

  factory WaterEntry.fromJson(String source) =>
      WaterEntry.fromMap(json.decode(source) as Map<String, dynamic>);

  WaterEntry copyWith({
    String? id,
    int? amountMl,
    DateTime? timestamp,
    String? beverageType,
  }) {
    return WaterEntry(
      id: id ?? this.id,
      amountMl: amountMl ?? this.amountMl,
      timestamp: timestamp ?? this.timestamp,
      beverageType: beverageType ?? this.beverageType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaterEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

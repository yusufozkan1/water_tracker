import 'dart:convert';
import 'water_entry.dart';

/// Aggregates all water entries for a specific day.
class DailyLog {
  final String date; // YYYY-MM-DD
  final int goalMl;
  final List<WaterEntry> entries;

  const DailyLog({
    required this.date,
    required this.goalMl,
    this.entries = const [],
  });

  /// Total intake in milliliters for this day.
  int get totalIntakeMl =>
      entries.fold<int>(0, (sum, entry) => sum + entry.amountMl);

  /// Progress fraction clamped between 0.0 and 1.0 (or >1.0 if exceeded).
  double get progress =>
      goalMl > 0 ? (totalIntakeMl / goalMl).clamp(0.0, 1.0) : 0.0;

  /// Whether the user achieved or exceeded their daily goal.
  bool get isGoalMet => totalIntakeMl >= goalMl && goalMl > 0;

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'goalMl': goalMl,
      'entries': entries.map((e) => e.toMap()).toList(),
    };
  }

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    final rawEntries = map['entries'] as List<dynamic>? ?? [];
    return DailyLog(
      date: map['date'] as String? ?? '',
      goalMl: (map['goalMl'] as num?)?.toInt() ?? 3000,
      entries: rawEntries
          .map((item) => WaterEntry.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory DailyLog.fromJson(String source) =>
      DailyLog.fromMap(json.decode(source) as Map<String, dynamic>);

  DailyLog copyWith({
    String? date,
    int? goalMl,
    List<WaterEntry>? entries,
  }) {
    return DailyLog(
      date: date ?? this.date,
      goalMl: goalMl ?? this.goalMl,
      entries: entries ?? this.entries,
    );
  }
}

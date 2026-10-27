import 'package:flutter_test/flutter_test.dart';
import 'package:water_tracker/models/daily_log.dart';
import 'package:water_tracker/models/water_entry.dart';

void main() {
  group('WaterEntry & DailyLog Model Tests', () {
    test('WaterEntry serialization and deserialization roundtrip', () {
      final now = DateTime(2026, 10, 27, 14, 30);
      final entry = WaterEntry(
        id: 'entry_1',
        amountMl: 250,
        timestamp: now,
        beverageType: 'Tea',
      );

      final jsonStr = entry.toJson();
      final decoded = WaterEntry.fromJson(jsonStr);

      expect(decoded.id, 'entry_1');
      expect(decoded.amountMl, 250);
      expect(decoded.beverageType, 'Tea');
      expect(decoded.timestamp, now);
    });

    test('DailyLog calculates total intake and progress correctly', () {
      final entries = [
        WaterEntry(
          id: '1',
          amountMl: 250,
          timestamp: DateTime.now(),
          beverageType: 'Water',
        ),
        WaterEntry(
          id: '2',
          amountMl: 500,
          timestamp: DateTime.now(),
          beverageType: 'Water',
        ),
      ];

      final log = DailyLog(
        date: '2026-10-27',
        goalMl: 1500,
        entries: entries,
      );

      expect(log.totalIntakeMl, 750);
      expect(log.progress, 0.5);
      expect(log.isGoalMet, isFalse);

      final completedLog = log.copyWith(
        entries: [
          ...entries,
          WaterEntry(
            id: '3',
            amountMl: 750,
            timestamp: DateTime.now(),
            beverageType: 'Water',
          ),
        ],
      );

      expect(completedLog.totalIntakeMl, 1500);
      expect(completedLog.progress, 1.0);
      expect(completedLog.isGoalMet, isTrue);
    });

    test('DailyLog serialization and deserialization roundtrip', () {
      final log = DailyLog(
        date: '2026-10-27',
        goalMl: 3000,
        entries: [
          WaterEntry(
            id: 'id_123',
            amountMl: 500,
            timestamp: DateTime(2026, 10, 27, 10, 0),
            beverageType: 'Coffee',
          ),
        ],
      );

      final jsonStr = log.toJson();
      final decoded = DailyLog.fromJson(jsonStr);

      expect(decoded.date, '2026-10-27');
      expect(decoded.goalMl, 3000);
      expect(decoded.entries.length, 1);
      expect(decoded.entries.first.amountMl, 500);
      expect(decoded.entries.first.beverageType, 'Coffee');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_tracker/models/daily_log.dart';
import 'package:water_tracker/models/water_entry.dart';
import 'package:water_tracker/services/preferences_manager.dart';
import 'package:water_tracker/services/water_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesManager().resetForTesting();
    await PreferencesManager().init();
  });

  group('WaterHistoryService Tests', () {
    test('addWaterEntry creates and updates today\'s log', () async {
      final service = WaterHistoryService();

      final log1 = await service.addWaterEntry(
        amountMl: 250,
        beverageType: 'Water',
      );
      expect(log1.entries.length, 1);
      expect(log1.totalIntakeMl, 250);

      final log2 = await service.addWaterEntry(
        amountMl: 500,
        beverageType: 'Tea',
      );
      expect(log2.entries.length, 2);
      expect(log2.totalIntakeMl, 750);

      final retrieved = await service.getDailyLog(WaterHistoryService.today());
      expect(retrieved?.totalIntakeMl, 750);
      expect(retrieved?.entries.last.beverageType, 'Tea');
    });

    test('removeWaterEntry removes the specified entry', () async {
      final service = WaterHistoryService();

      final log = await service.addWaterEntry(amountMl: 300);
      final entryId = log.entries.first.id;

      final updated = await service.removeWaterEntry(entryId);
      expect(updated?.entries.isEmpty, isTrue);
      expect(updated?.totalIntakeMl, 0);
    });

    test('resetToday clears entries for the current day', () async {
      final service = WaterHistoryService();

      await service.addWaterEntry(amountMl: 500);
      await service.addWaterEntry(amountMl: 500);

      var log = await service.getDailyLog(WaterHistoryService.today());
      expect(log?.totalIntakeMl, 1000);

      await service.resetToday();

      log = await service.getDailyLog(WaterHistoryService.today());
      expect(log?.totalIntakeMl, 0);
      expect(log?.entries.isEmpty, isTrue);
    });

    test('calculateCurrentStreak accurately counts consecutive achieved days',
        () async {
      final service = WaterHistoryService();
      final now = DateTime.now();

      // Today - met
      final todayStr = WaterHistoryService.formatDate(now);
      await service.saveDailyLog(DailyLog(
        date: todayStr,
        goalMl: 2000,
        entries: [
          WaterEntry(
            id: 't1',
            amountMl: 2000,
            timestamp: now,
            beverageType: 'Water',
          ),
        ],
      ));

      // Yesterday - met
      final yesterdayStr =
          WaterHistoryService.formatDate(now.subtract(const Duration(days: 1)));
      await service.saveDailyLog(DailyLog(
        date: yesterdayStr,
        goalMl: 2000,
        entries: [
          WaterEntry(
            id: 'y1',
            amountMl: 2200,
            timestamp: now.subtract(const Duration(days: 1)),
            beverageType: 'Water',
          ),
        ],
      ));

      // 2 days ago - met
      final twoDaysAgoStr =
          WaterHistoryService.formatDate(now.subtract(const Duration(days: 2)));
      await service.saveDailyLog(DailyLog(
        date: twoDaysAgoStr,
        goalMl: 2000,
        entries: [
          WaterEntry(
            id: 'd1',
            amountMl: 2000,
            timestamp: now.subtract(const Duration(days: 2)),
            beverageType: 'Water',
          ),
        ],
      ));

      // 3 days ago - not met (break streak)
      final threeDaysAgoStr =
          WaterHistoryService.formatDate(now.subtract(const Duration(days: 3)));
      await service.saveDailyLog(DailyLog(
        date: threeDaysAgoStr,
        goalMl: 2000,
        entries: [
          WaterEntry(
            id: 'd2',
            amountMl: 500,
            timestamp: now.subtract(const Duration(days: 3)),
            beverageType: 'Water',
          ),
        ],
      ));

      final streak = await service.calculateCurrentStreak();
      expect(streak, 3);
    });
  });
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/daily_log.dart';
import '../models/water_entry.dart';
import 'preferences_manager.dart';

/// Service managing persistent hydration history, daily logs, and streak metrics.
class WaterHistoryService {
  static final WaterHistoryService _instance = WaterHistoryService._internal();
  factory WaterHistoryService() => _instance;
  WaterHistoryService._internal();

  static const String _dailyLogPrefix = 'daily_log_';
  static const String _allLoggedDatesKey = 'all_logged_dates';
  static const String _dailyGoalKey = 'daily_goal';
  static const String _legacyWaterAmountKey = 'water_amount';
  static const String _legacyLastTrackedDateKey = 'last_tracked_date';

  /// Returns YYYY-MM-DD for the given DateTime.
  static String formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Returns today's date formatted as YYYY-MM-DD.
  static String today() => formatDate(DateTime.now());

  /// Returns the current daily goal.
  Future<int> getDailyGoal() async {
    final goal = await PreferencesManager().get<int>(_dailyGoalKey, 3000);
    return goal ?? 3000;
  }

  /// Sets a new daily goal.
  Future<void> setDailyGoal(int newGoal) async {
    await PreferencesManager().set<int>(_dailyGoalKey, newGoal);
    // Also update today's log goal if present
    final todayLog = await getDailyLog(today());
    if (todayLog != null) {
      await saveDailyLog(todayLog.copyWith(goalMl: newGoal));
    }
  }

  /// Retrieves the DailyLog for a given date formatted as YYYY-MM-DD.
  Future<DailyLog?> getDailyLog(String dateKey) async {
    final rawJson =
        await PreferencesManager().get<String>('$_dailyLogPrefix$dateKey');
    if (rawJson == null || rawJson.isEmpty) {
      // Check legacy fallback for today
      if (dateKey == today()) {
        final legacyDate = await PreferencesManager()
            .get<String>(_legacyLastTrackedDateKey, '');
        if (legacyDate == today()) {
          final legacyAmount =
              await PreferencesManager().get<int>(_legacyWaterAmountKey, 0) ?? 0;
          final goal = await getDailyGoal();
          if (legacyAmount > 0) {
            final entry = WaterEntry(
              id: 'legacy_${DateTime.now().millisecondsSinceEpoch}',
              amountMl: legacyAmount,
              timestamp: DateTime.now(),
              beverageType: 'Water',
            );
            final log = DailyLog(date: today(), goalMl: goal, entries: [entry]);
            await saveDailyLog(log);
            return log;
          }
        }
      }
      return null;
    }

    try {
      return DailyLog.fromJson(rawJson);
    } catch (e) {
      debugPrint('Error parsing DailyLog for $dateKey: $e');
      return null;
    }
  }

  /// Saves a DailyLog to persistent storage and tracks the date in the index.
  Future<void> saveDailyLog(DailyLog log) async {
    await PreferencesManager().set<String>(
      '$_dailyLogPrefix${log.date}',
      log.toJson(),
    );

    // Keep legacy keys updated for compatibility
    if (log.date == today()) {
      await PreferencesManager().set<int>(_legacyWaterAmountKey, log.totalIntakeMl);
      await PreferencesManager().set<String>(_legacyLastTrackedDateKey, log.date);
    }

    // Maintain date index
    await _recordDateKey(log.date);
  }

  /// Adds a new water entry for today.
  Future<DailyLog> addWaterEntry({
    required int amountMl,
    String beverageType = 'Water',
    DateTime? timestamp,
  }) async {
    final date = today();
    final goal = await getDailyGoal();
    final currentLog = (await getDailyLog(date)) ??
        DailyLog(date: date, goalMl: goal, entries: []);

    final newEntry = WaterEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${currentLog.entries.length}',
      amountMl: amountMl,
      timestamp: timestamp ?? DateTime.now(),
      beverageType: beverageType,
    );

    final updatedEntries = List<WaterEntry>.from(currentLog.entries)..add(newEntry);
    final updatedLog = currentLog.copyWith(
      goalMl: goal,
      entries: updatedEntries,
    );

    await saveDailyLog(updatedLog);
    return updatedLog;
  }

  /// Removes an entry by ID from today's log.
  Future<DailyLog?> removeWaterEntry(String entryId) async {
    final date = today();
    final currentLog = await getDailyLog(date);
    if (currentLog == null) return null;

    final updatedEntries =
        currentLog.entries.where((e) => e.id != entryId).toList();
    final updatedLog = currentLog.copyWith(entries: updatedEntries);

    await saveDailyLog(updatedLog);
    return updatedLog;
  }

  /// Resets today's intake to zero.
  Future<void> resetToday() async {
    final date = today();
    final goal = await getDailyGoal();
    final emptyLog = DailyLog(date: date, goalMl: goal, entries: []);
    await saveDailyLog(emptyLog);
  }

  /// Records a date in the set of known tracked dates.
  Future<void> _recordDateKey(String dateKey) async {
    final datesJson =
        await PreferencesManager().get<String>(_allLoggedDatesKey, '[]');
    List<String> dates = [];
    try {
      dates = List<String>.from(json.decode(datesJson ?? '[]') as List<dynamic>);
    } catch (_) {
      dates = [];
    }

    if (!dates.contains(dateKey)) {
      dates.add(dateKey);
      await PreferencesManager()
          .set<String>(_allLoggedDatesKey, json.encode(dates));
    }
  }

  /// Retrieves the past [daysCount] daily logs up to today.
  Future<List<DailyLog>> getRecentLogs({int daysCount = 7}) async {
    final List<DailyLog> results = [];
    final now = DateTime.now();
    final defaultGoal = await getDailyGoal();

    for (int i = daysCount - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = formatDate(date);
      final log = await getDailyLog(dateStr);
      results.add(
        log ?? DailyLog(date: dateStr, goalMl: defaultGoal, entries: const []),
      );
    }

    return results;
  }

  /// Calculates the current consecutive day streak where the water goal was met.
  Future<int> calculateCurrentStreak() async {
    final now = DateTime.now();
    final todayStr = formatDate(now);
    final todayLog = await getDailyLog(todayStr);

    int streak = 0;

    // If today's goal is met, count today and check backwards
    DateTime checkDate;
    if (todayLog != null && todayLog.isGoalMet) {
      streak = 1;
      checkDate = now.subtract(const Duration(days: 1));
    } else {
      // Today isn't met yet (in progress), check if yesterday was met
      checkDate = now.subtract(const Duration(days: 1));
    }

    // Iterate backwards consecutively
    for (int i = 0; i < 365; i++) {
      final dateStr = formatDate(checkDate);
      final log = await getDailyLog(dateStr);
      if (log != null && log.isGoalMet) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }
}

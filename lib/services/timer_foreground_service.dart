import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_tracker/services/preferences_manager.dart';

/// Production-grade foreground service for background timer.
///
/// KEY FEATURES:
/// - Runs independently of Flutter UI
/// - Updates notification every second in background
/// - Survives app being minimized or killed
/// - Persists timer state across app restarts
class TimerForegroundService {
  static const String _endTimeKey = 'timer_end_time';

  /// Initialize the foreground task configuration
  /// Call this once in main() before runApp()
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'timer_foreground_channel',
        channelName: 'Timer Service',
        channelDescription: 'Shows countdown timer progress in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000), // Every 1 second
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Starts the foreground timer service
  /// [endTime] - When the timer should finish
  static Future<ServiceRequestResult> startTimer(DateTime endTime) async {
    // Save endTime via PreferencesManager for thread-safe persistence and cache update
    await PreferencesManager().set<String>(_endTimeKey, endTime.toIso8601String());

    // Request necessary permissions
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Check if service is already running
    if (await FlutterForegroundTask.isRunningService) {
      // Restart with new endTime
      return FlutterForegroundTask.restartService();
    }

    // Start the foreground service
    return FlutterForegroundTask.startService(
      notificationTitle: '⏱️ Timer Running',
      notificationText: 'Calculating...',
      callback: _startCallback,
    );
  }

  /// Stops the foreground timer service
  static Future<ServiceRequestResult> stopTimer() async {
    // Clear persisted endTime via PreferencesManager
    await PreferencesManager().remove(_endTimeKey);

    return FlutterForegroundTask.stopService();
  }

  /// Check if timer service is running
  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Get remaining time from persisted endTime
  static Future<Duration?> getRemainingTime() async {
    final endTimeStr = await PreferencesManager().get<String>(_endTimeKey);
    if (endTimeStr == null || endTimeStr.isEmpty) return null;

    final endTime = DateTime.tryParse(endTimeStr);
    if (endTime == null) return null;

    final remaining = endTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Entry point for the foreground task isolate
/// This function runs in a separate isolate (background thread)
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}

/// Task handler that runs in the background isolate
/// Updates notification every second with remaining time
class TimerTaskHandler extends TaskHandler {
  DateTime? _endTime;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('TimerTaskHandler: onStart called');

    // Load endTime from SharedPreferences in background isolate
    final prefs = await SharedPreferences.getInstance();
    final endTimeStr = prefs.getString('timer_end_time');
    if (endTimeStr != null) {
      _endTime = DateTime.tryParse(endTimeStr);
      debugPrint('TimerTaskHandler: Loaded endTime = $_endTime');
    }
  }

  /// Called every second (as configured in foregroundTaskOptions)
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_endTime == null) {
      debugPrint('TimerTaskHandler: No endTime set');
      return;
    }

    final remaining = _endTime!.difference(DateTime.now());

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      // Timer completed!
      debugPrint('TimerTaskHandler: Timer completed!');

      // Update notification to show completion
      FlutterForegroundTask.updateService(
        notificationTitle: '✅ Timer Finished',
        notificationText: "Time's up!",
      );

      // Send completion event to Flutter UI (if listening)
      FlutterForegroundTask.sendDataToMain({'event': 'timer_complete'});

      // Stop the service after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        FlutterForegroundTask.stopService();
      });
    } else {
      // Update notification with remaining time
      final formatted = _formatDuration(remaining);
      FlutterForegroundTask.updateService(
        notificationTitle: '⏱️ Timer Running',
        notificationText: 'Remaining: $formatted',
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('TimerTaskHandler: onDestroy called');
  }

  @override
  void onReceiveData(Object data) {
    debugPrint('TimerTaskHandler: Received data: $data');
  }

  /// Formats duration as MM:SS
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

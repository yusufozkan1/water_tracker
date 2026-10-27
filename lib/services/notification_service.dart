import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:water_tracker/services/preferences_manager.dart';

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Notification IDs - unique IDs to update/cancel specific notifications
  static const int _waterNotificationId = 0;
  static const int _timerCompletionId = 1;
  static const int _scheduledTimerCompletionId = 2;
  static const int _ongoingTimerId = 100;
  static const int _hydrationReminderBaseId = 1000;
  static const int _maxHydrationReminderSlots = 50;

  // SharedPreferences Keys for Reminders
  static const String keyRemindersEnabled = 'hydration_reminders_enabled';
  static const String keyReminderIntervalMinutes = 'hydration_reminder_interval_mins';
  static const String keyReminderStartHour = 'hydration_reminder_start_hour';
  static const String keyReminderEndHour = 'hydration_reminder_end_hour';

  Future<void> init() async {
    if (_isInitialized) return;

    // CRITICAL: Initialize timezone database and set local timezone
    await _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );
    _isInitialized = true;

    try {
      await syncReminderScheduleFromPreferences();
    } catch (e) {
      debugPrint('Error syncing reminder schedule during init: $e');
    }
  }

  /// CRITICAL: Configure timezone for zonedSchedule to work!
  /// This MUST be called before any zonedSchedule calls.
  Future<void> _configureLocalTimeZone() async {
    // Initialize all timezone data
    tz_data.initializeTimeZones();

    // Get device's current timezone name
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    debugPrint('NotificationService: Device timezone is $timeZoneName');

    // Set the local timezone location
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      // Request exact alarm permission for scheduled notifications (Android 12+)
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> showNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'water_channel_id',
      'Su Hatırlatıcı',
      channelDescription: 'Su içme hatırlatmaları',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      _waterNotificationId,
      'Su Vakti! 💧',
      'Bir bardak su içerek hedefine yaklaşabilirsin.',
      platformChannelSpecifics,
    );
  }

  /// Shows immediate "Time's up" notification (for foreground completion)
  Future<void> showTimerNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timer_channel_id',
      'Timer Alerts',
      channelDescription: 'Countdown timer completion alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Timer finished',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      _timerCompletionId,
      'Timer Finished',
      "Time's up! Stay productive 💧",
      platformChannelSpecifics,
    );
  }

  /// SCHEDULES "Time's up" notification at exact endTime
  /// This is delivered by the OS even if app is in background/killed!
  Future<void> scheduleTimerCompletionNotification(DateTime endTime) async {
    // Ensure timezone is configured
    if (!_isInitialized) {
      await init();
    }

    // Convert to TZDateTime using properly configured local timezone
    final tz.TZDateTime tzEndTime = tz.TZDateTime.from(endTime, tz.local);

    debugPrint('NotificationService: Scheduling notification for $tzEndTime');
    debugPrint(
        'NotificationService: Current time is ${tz.TZDateTime.now(tz.local)}');

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timer_channel_id',
      'Timer Alerts',
      channelDescription: 'Countdown timer completion alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Timer finished',
      fullScreenIntent: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      _scheduledTimerCompletionId,
      'Timer Finished ⏰',
      "Time's up! Stay productive 💧",
      tzEndTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('NotificationService: Notification scheduled successfully!');
  }

  /// Cancels the scheduled timer completion notification
  Future<void> cancelScheduledTimerNotification() async {
    await flutterLocalNotificationsPlugin.cancel(_scheduledTimerCompletionId);
    debugPrint('NotificationService: Scheduled notification cancelled');
  }

  /// Shows/updates ONGOING notification with remaining time
  Future<void> showOngoingTimerNotification(String remainingTime) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timer_ongoing_channel',
      'Timer Progress',
      channelDescription: 'Shows countdown timer progress',
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      _ongoingTimerId,
      '⏱️ Timer Running',
      'Remaining: $remainingTime',
      platformChannelSpecifics,
    );
  }

  /// Cancels the ongoing timer notification
  Future<void> cancelOngoingNotification() async {
    await flutterLocalNotificationsPlugin.cancel(_ongoingTimerId);
  }

  /// Cancels all timer-related notifications (ongoing + scheduled)
  Future<void> cancelAllTimerNotifications() async {
    await cancelOngoingNotification();
    await cancelScheduledTimerNotification();
  }

  /// Cancels all scheduled periodic hydration reminders
  Future<void> cancelAllHydrationReminders() async {
    for (int i = 0; i < _maxHydrationReminderSlots; i++) {
      await flutterLocalNotificationsPlugin.cancel(_hydrationReminderBaseId + i);
    }
    debugPrint('NotificationService: All hydration reminders cancelled');
  }

  /// Schedules daily periodic hydration reminders between startHour and endHour
  Future<void> scheduleHydrationReminders({
    required int intervalMinutes,
    required int startHour,
    required int endHour,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    await cancelAllHydrationReminders();

    if (intervalMinutes <= 0 || startHour >= endHour) {
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    int slotIndex = 0;

    int currentMinuteTotal = startHour * 60;
    final endMinuteTotal = endHour * 60;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'hydration_reminders_channel',
      'Hydration Reminders',
      channelDescription:
          'Regular periodic reminders to stay hydrated throughout the day',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'Drink water',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    while (currentMinuteTotal <= endMinuteTotal &&
        slotIndex < _maxHydrationReminderSlots) {
      final hour = currentMinuteTotal ~/ 60;
      final minute = currentMinuteTotal % 60;

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If this time has already passed today, start from tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          _hydrationReminderBaseId + slotIndex,
          'Time to Drink Water 💧',
          'Take a moment to hydrate and replenish your energy!',
          scheduledDate,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint('Error scheduling reminder slot $slotIndex: $e');
      }

      slotIndex++;
      currentMinuteTotal += intervalMinutes;
    }
    debugPrint('NotificationService: Successfully scheduled $slotIndex hydration reminder slots');
  }

  /// Synchronizes scheduled hydration reminders with persisted preferences
  Future<void> syncReminderScheduleFromPreferences() async {
    final enabled =
        await PreferencesManager().get<bool>(keyRemindersEnabled, true) ?? true;

    if (!enabled) {
      await cancelAllHydrationReminders();
      return;
    }

    final interval = await PreferencesManager()
            .get<int>(keyReminderIntervalMinutes, 90) ??
        90;
    final startHour =
        await PreferencesManager().get<int>(keyReminderStartHour, 8) ?? 8;
    final endHour =
        await PreferencesManager().get<int>(keyReminderEndHour, 22) ?? 22;

    await scheduleHydrationReminders(
      intervalMinutes: interval,
      startHour: startHour,
      endHour: endHour,
    );
  }
}

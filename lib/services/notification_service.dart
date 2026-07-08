import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Handles ReadAlert local streak reminder notifications.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static Future<void>? _initializing;
  static bool _initialized = false;

  static const int dailyStreakReminderId = 3108;
  static const String _channelId = 'readalert_streak_reminder';
  static const String _channelName = 'Reading Streak Reminder';
  static const String _channelDescription =
      'Daily reminder to keep your ReadAlert streak active.';
  static const String _androidNotificationIcon = 'notification_icon';

  static Future<void> initialize() {
    if (_initialized) return Future.value();
    final Future<void>? currentInitialization = _initializing;
    if (currentInitialization != null) return currentInitialization;
    _initializing = _doInitialize();
    return _initializing!;
  }

  static Future<void> _doInitialize() async {
    try {
      tzdata.initializeTimeZones();
      final TimezoneInfo localTimezone =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings(_androidNotificationIcon);

      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: androidSettings,
            iOS: darwinSettings,
            macOS: darwinSettings,
          );

      await _plugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {},
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  static Future<bool> requestPermission() async {
    await initialize();

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final bool? granted = await androidPlugin
          ?.requestNotificationsPermission();

      return granted ?? true;
    }

    if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      final bool? granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      return granted ?? false;
    }

    return true;
  }

  static Future<bool> scheduleDailyStreakReminder({
    int hour = 20,
    int minute = 0,
  }) async {
    await initialize();

    final bool allowed = await requestPermission();
    if (!allowed) return false;

    await cancelDailyStreakReminder();

    await _plugin.zonedSchedule(
      id: dailyStreakReminderId,
      title: "Don't lose your streak!",
      body: 'Read a few pages today to keep your ReadAlert streak alive!',
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: _androidNotificationIcon,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_streak_reminder',
    );

    return true;
  }

  static Future<void> cancelDailyStreakReminder() async {
    await initialize();

    await _plugin.cancel(id: dailyStreakReminderId);
  }

  static Future<bool> showTestReminder() async {
    await initialize();

    final bool allowed = await requestPermission();
    if (!allowed) return false;

    await _plugin.show(
      id: dailyStreakReminderId + 1,
      title: "Don't lose your streak!",
      body: 'Read a few pages today to keep your ReadAlert streak alive!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: _androidNotificationIcon,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'test_streak_reminder',
    );

    return true;
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CookingRuntime {
  CookingRuntime._();

  static final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();
  static bool initialized = false;

  static Future<void> initialize() async {
    if (initialized) return;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await notifications.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: const DarwinInitializationSettings(),
        ),
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        await notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    }
    initialized = true;
  }

  static Future<void> enableKeepScreenOn() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Browsers and platforms without wake-lock support fail silently.
    }
  }

  static Future<void> disableKeepScreenOn() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // No additional action is possible on unsupported platforms.
    }
  }

  static Future<void> showTimerNotification(int step) async {
    await initialize();
    try {
      await notifications.show(
        id: 1000 + step,
        title: 'Koch-Timer beendet',
        body: 'Schritt ${step + 1} ist fertig.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'kochmaster_cooking_timer',
            'Koch-Timer',
            channelDescription: 'Benachrichtigungen laufender Koch-Timer',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {
      // In-app notification remains the reliable fallback.
    }
  }
}

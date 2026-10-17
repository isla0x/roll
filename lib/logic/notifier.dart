import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// "현상이 끝났어요" 알림. 실패해도 앱은 계속 돌아간다.
class Notifier {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifier init failed: $e');
    }
  }

  /// 처음 롤을 맡길 때 알림 권한을 물어본다.
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('notification permission failed: $e');
    }
  }

  Future<void> scheduleDeveloped(int rollNo, DateTime when, String rollTitle) async {
    if (!_ready) return;
    await requestPermission();
    try {
      await _plugin.zonedSchedule(
        rollNo,
        '현상이 끝났어요',
        '$rollTitle 롤이 다 현상됐어요. 지금 열어 보세요.',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'develop',
            '현상 완료',
            channelDescription: '필름 롤 현상이 끝나면 알려줘요',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: false, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('schedule failed: $e');
    }
  }

  Future<void> cancel(int rollNo) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(rollNo);
    } catch (_) {}
  }
}

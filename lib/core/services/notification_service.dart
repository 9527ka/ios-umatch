import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'statistical_service.dart';

/// 真实本地通知调度服务 (iOS UNUserNotificationCenter via flutter_local_notifications)。
///
/// 调用链:
///   main.dart → NotificationService.shared.init()
///   ReminderSheet 确认 → scheduleMatchReminder() (内部按需申请权限)
///   ReminderSheet 关闭提醒 / 取消 → cancelMatchReminder()
class NotificationService {
  NotificationService._();
  static final NotificationService shared = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // 时区名查询失败时退回 UTC，调度仍按绝对时间触发
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(iOS: darwinInit);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// 首次调度时按 iOS HIG 申请通知权限。返回是否授权。
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    HyStatistical.shared.track('push_permission_resp', {'granted': granted ?? false});
    return granted ?? false;
  }

  /// 为某场比赛调度提醒。fireAt 为本地触发时间 (开赛时间 - 提前量)。
  /// 返回 true 表示已成功调度；false 表示时间已过或权限被拒。
  Future<bool> scheduleMatchReminder({
    required String matchId,
    required String title,
    required String body,
    required DateTime fireAt,
    bool playSound = true,
  }) async {
    await init();
    if (!fireAt.isAfter(DateTime.now())) return false;
    final granted = await requestPermission();
    if (!granted) return false;

    final tzTime = tz.TZDateTime.from(fireAt, tz.local);
    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
      ),
    );

    // 同一比赛重复调度时覆盖旧通知 (相同 id)
    await _plugin.zonedSchedule(
      _idFor(matchId),
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    return true;
  }

  Future<void> cancelMatchReminder(String matchId) async {
    await init();
    await _plugin.cancel(_idFor(matchId));
  }

  // String matchId → 稳定的 32 位正整数通知 id
  int _idFor(String matchId) => matchId.hashCode & 0x7fffffff;
}

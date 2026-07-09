import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import '../models/trigger.dart' hide Importance;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String generateUuid() {
    return const Uuid().v4();
  }

  Future<void> init() async {
    tz.initializeTimeZones();
    // Default local timezone to Asia/Taipei
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
    } catch (_) {
      // Fallback
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
    );

    // Request permissions on Android 13+ and iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  List<Duration> calculateWarningOffsets(Duration totalDuration) {
    final warningRatios = [0.5, 0.1, 0.05];
    return warningRatios.map((ratio) {
      return Duration(seconds: (totalDuration.inSeconds * ratio).round());
    }).toList();
  }

  Future<void> scheduleWarningNotifications(Trigger trigger) async {
    // First, cancel any existing notifications for this trigger
    await cancelScheduledNotifications(trigger.id);

    if (!trigger.isActive) return;

    DateTime? deadline;
    if (trigger.mode == TriggerMode.scheduledDate) {
      deadline = trigger.scheduledDeadline;
    } else if (trigger.intervalDuration != null) {
      deadline = trigger.lastConfirmedAt.add(trigger.intervalDuration!);
    }

    if (deadline == null) return;

    final now = DateTime.now();
    final totalDuration = trigger.mode == TriggerMode.scheduledDate
        ? trigger.scheduledDeadline!.difference(trigger.lastConfirmedAt)
        : trigger.intervalDuration!;

    if (totalDuration.inSeconds <= 0) return;

    final warningOffsets = calculateWarningOffsets(totalDuration);
    final baseId = trigger.id.hashCode;

    for (int i = 0; i < warningOffsets.length; i++) {
      final offset = warningOffsets[i];
      final warningTime = deadline.subtract(offset);

      // Schedule only if the warning time is in the future
      if (warningTime.isAfter(now)) {
        final tzTime = tz.TZDateTime.from(warningTime, tz.local);
        final remainingText = _formatRemainingTime(offset);

        const androidDetails = AndroidNotificationDetails(
          'warning_channel',
          '安心交代通知',
          channelDescription: '防呆警告通知',
          importance: Importance.max,
          priority: Priority.high,
        );

        const iosDetails = DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        );

        const notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _notificationsPlugin.zonedSchedule(
          baseId + i,
          '安心交代通知',
          '距離下一次確認還有 $remainingText，請開啟App確認一切都好',
          tzTime,
          notificationDetails,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> cancelScheduledNotifications(String triggerId) async {
    final baseId = triggerId.hashCode;
    await _notificationsPlugin.cancel(baseId);
    await _notificationsPlugin.cancel(baseId + 1);
    await _notificationsPlugin.cancel(baseId + 2);
  }

  String _formatRemainingTime(Duration duration) {
    if (duration.inDays > 0) {
      final remainingHours = duration.inHours % 24;
      if (remainingHours > 0) {
        return '${duration.inDays}天${remainingHours}小時';
      }
      return '${duration.inDays}天';
    } else if (duration.inHours > 0) {
      final remainingMinutes = duration.inMinutes % 60;
      if (remainingMinutes > 0) {
        return '${duration.inHours}小時${remainingMinutes}分鐘';
      }
      return '${duration.inHours}小時';
    } else {
      return '${duration.inMinutes}分鐘';
    }
  }
}

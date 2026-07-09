import 'package:flutter_test/flutter_test.dart';
import 'package:life_trigger/services/notification_service.dart';

void main() {
  group('NotificationService Warning Calculations', () {
    final notificationService = NotificationService();

    test('6 Hours Total Duration Warning points', () {
      const totalDuration = Duration(hours: 6);
      final offsets = notificationService.calculateWarningOffsets(totalDuration);

      expect(offsets.length, 3);
      // 50% = 3 hours
      expect(offsets[0], const Duration(hours: 3));
      // 10% = 36 minutes
      expect(offsets[1], const Duration(minutes: 36));
      // 5% = 18 minutes
      expect(offsets[2], const Duration(minutes: 18));
    });

    test('7 Days Total Duration Warning points', () {
      const totalDuration = Duration(days: 7);
      final offsets = notificationService.calculateWarningOffsets(totalDuration);

      expect(offsets.length, 3);
      // 50% = 3.5 days = 84 hours
      expect(offsets[0], const Duration(hours: 84));
      // 10% = 16.8 hours = 1008 minutes
      expect(offsets[1], const Duration(minutes: 1008));
      // 5% = 8.4 hours = 504 minutes
      expect(offsets[2], const Duration(minutes: 504));
    });
  });
}

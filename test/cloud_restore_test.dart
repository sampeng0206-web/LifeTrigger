import 'package:flutter_test/flutter_test.dart';
import 'package:life_trigger/models/recipient.dart';
import 'package:life_trigger/models/trigger.dart';

void main() {
  group('Cloud Restore Data Parsing and Simulation Tests', () {
    test('Simulate restoring real cloud trigger with message, shared_memory, multiple recipients', () {
      final mockCloudResponse = [
        {
          'id': 'cloud-trigger-sea-001',
          'user_id': 'user_sea_123',
          'recipient_emails': 'sea1@example.com, sea2@example.com',
          'deadline': '2026-07-26T12:00:00.000Z',
          'is_active': 1,
          'requires_cloud': 1,
          'status': 'waiting',
          'payload': {
            'message': '對象:海，這是剩餘約6天的真實守護訊息。',
            'shared_memory': '我們第一次去看海的日期',
            'user_email': 'guardian@example.com',
            'recipient_names': '海1, 海2'
          }
        }
      ];

      expect(mockCloudResponse.isNotEmpty, true);
      final triggerJson = mockCloudResponse.first;

      // 1. 安全解析收件者
      final emailsStr = (triggerJson['recipient_emails'] ?? '').toString();
      final emails = emailsStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      expect(emails.length, 2);
      expect(emails[0], 'sea1@example.com');
      expect(emails[1], 'sea2@example.com');

      final recipientList = <Recipient>[];
      for (var email in emails) {
        final recipient = Recipient(
          id: 'rec_${email.hashCode}',
          name: email.split('@').first,
          email: email,
          relationship: Relationship.friend,
        );
        recipientList.add(recipient);
      }
      expect(recipientList.length, 2);
      expect(recipientList[0].name, 'sea1');

      // 2. 安全解析 Payload 欄位
      final payloadRaw = triggerJson['payload'];
      Map<String, dynamic> payload = {};
      if (payloadRaw is Map<String, dynamic>) {
        payload = payloadRaw;
      }
      final message = (payload['message'] ?? '').toString();
      final sharedMemory = (payload['shared_memory'] ?? '').toString();

      expect(message, '對象:海，這是剩餘約6天的真實守護訊息。');
      expect(sharedMemory, '我們第一次去看海的日期');

      // 3. 安全解析 Deadline
      final deadlineStr = (triggerJson['deadline'] ?? '').toString();
      final deadlineUtc = DateTime.parse(deadlineStr);
      expect(deadlineUtc.year, 2026);

      // 4. 建立 Trigger 物件
      final restoredTrigger = Trigger(
        id: (triggerJson['id'] ?? '').toString(),
        mode: TriggerMode.quick,
        scheduledDeadline: deadlineUtc.toLocal(),
        autoRenewOnConfirm: true,
        requiresCloud: triggerJson['requires_cloud'] == 1,
        recipientIds: recipientList.map((r) => r.id).toList(),
        deliveryMethod: DeliveryMethod.email,
        message: message,
        sharedMemoryPrompt: sharedMemory,
        importance: Importance.normal,
        status: TriggerStatus.waiting,
        lastConfirmedAt: DateTime.now(),
        isActive: true,
      );

      expect(restoredTrigger.id, 'cloud-trigger-sea-001');
      expect(restoredTrigger.requiresCloud, true);
      expect(restoredTrigger.message, contains('對象:海'));
      expect(restoredTrigger.sharedMemoryPrompt, '我們第一次去看海的日期');
    });

    test('Defensive handling of incomplete/null payload cloud response', () {
      final mockFaultyResponse = [
        {
          'id': 'cloud-trigger-null-test',
          'recipient_emails': null,
          'deadline': 'invalid-date-string',
          'requires_cloud': 0,
          'payload': {
            'message': null,
            'shared_memory': null,
          }
        }
      ];

      final triggerJson = mockFaultyResponse.first;
      final emailsStr = (triggerJson['recipient_emails'] ?? '').toString();
      final emails = emailsStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      expect(emails, isEmpty);

      final payloadRaw = triggerJson['payload'];
      Map<String, dynamic> payload = {};
      if (payloadRaw is Map<String, dynamic>) {
        payload = payloadRaw;
      }

      final message = (payload['message'] ?? '').toString();
      final sharedMemory = (payload['shared_memory'] ?? '').toString();
      expect(message, '');
      expect(sharedMemory, '');

      final deadlineStr = (triggerJson['deadline'] ?? '').toString();
      DateTime localDeadline;
      try {
        localDeadline = DateTime.parse(deadlineStr).toLocal();
      } catch (_) {
        localDeadline = DateTime.now().add(const Duration(days: 7));
      }
      expect(localDeadline.isAfter(DateTime.now()), true);
    });
  });
}

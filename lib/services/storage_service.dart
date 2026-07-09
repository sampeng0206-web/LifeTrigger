import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trigger.dart';
import '../models/recipient.dart';
import '../models/user_quota.dart';
import 'notification_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref);
});

class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 9;

  @override
  Duration read(BinaryReader reader) {
    return Duration(microseconds: reader.readInt());
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}

enum CreateTriggerStatus {
  success,
  quotaExceeded,
}

class CreateTriggerResult {
  final CreateTriggerStatus status;
  final Trigger? trigger;

  CreateTriggerResult(this.status, this.trigger);
}

class StorageService {
  final Ref _ref;
  late Box<Trigger> _triggerBox;
  late Box<Recipient> _recipientBox;
  late Box<UserQuota> _quotaBox;
  
  // Callback for retract handover UI animation
  VoidCallback? onRetractHandoverAnimation;

  StorageService(this._ref);

  Future<void> init() async {
    await Hive.initFlutter();

    // Register TypeAdapters
    _registerAdapterSafe(TriggerModeAdapter());
    _registerAdapterSafe(DeliveryMethodAdapter());
    _registerAdapterSafe(ImportanceAdapter());
    _registerAdapterSafe(TriggerStatusAdapter());
    _registerAdapterSafe(FailureReasonAdapter());
    _registerAdapterSafe(TriggerAdapter());
    _registerAdapterSafe(RelationshipAdapter());
    _registerAdapterSafe(RecipientAdapter());
    _registerAdapterSafe(UserQuotaAdapter());
    _registerAdapterSafe(DurationAdapter());

    _triggerBox = await Hive.openBox<Trigger>('triggers');
    _recipientBox = await Hive.openBox<Recipient>('recipients');
    _quotaBox = await Hive.openBox<UserQuota>('user_quotas');

    // Initialize default UserQuota if empty
    if (_quotaBox.isEmpty) {
      await _quotaBox.put('default', UserQuota(freeTriggersRemaining: 3));
    }
  }

  void _registerAdapterSafe<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  UserQuota getUserQuota() {
    return _quotaBox.get('default') ?? UserQuota(freeTriggersRemaining: 3);
  }

  Future<void> saveUserQuota(UserQuota quota) async {
    await _quotaBox.put('default', quota);
  }

  Future<void> saveTrigger(Trigger trigger) async {
    await _triggerBox.put(trigger.id, trigger);
  }

  Future<void> saveRecipient(Recipient recipient) async {
    await _recipientBox.put(recipient.id, recipient);
  }

  Recipient? getRecipient(String id) {
    return _recipientBox.get(id);
  }

  List<Trigger> getActiveTriggers() {
    return _triggerBox.values
        .where((t) => t.isActive && (t.status == TriggerStatus.waiting || t.status == TriggerStatus.reminderSent))
        .toList();
  }

  List<Trigger> getAllTriggers() {
    return _triggerBox.values.toList();
  }

  Future<CreateTriggerResult> createNewTrigger({
    required TriggerMode mode,
    Duration? intervalDuration,
    DateTime? scheduledDeadline,
    required bool autoRenewOnConfirm,
    required List<String> recipientIds,
    required String message,
    required String sharedMemoryPrompt,
  }) async {
    final quota = getUserQuota();
    final hasQuota = quota.freeTriggersRemaining > 0 ||
        quota.isLocalUnlimited ||
        quota.isCloudGuardianActive;

    if (!hasQuota) {
      return CreateTriggerResult(CreateTriggerStatus.quotaExceeded, null);
    }

    // Deduct quota for free tier only
    if (quota.freeTriggersRemaining > 0 &&
        !quota.isLocalUnlimited &&
        !quota.isCloudGuardianActive) {
      quota.freeTriggersRemaining -= 1;
      await saveUserQuota(quota);
    }

    // Determine if it requires cloud (more than 7 days)
    bool requiresCloud = false;
    if (intervalDuration != null && intervalDuration > const Duration(days: 7)) {
      requiresCloud = true;
    }
    if (scheduledDeadline != null &&
        scheduledDeadline.difference(DateTime.now()) > const Duration(days: 7)) {
      requiresCloud = true;
    }

    final id = _ref.read(notificationServiceProvider).generateUuid();
    final newTrigger = Trigger(
      id: id,
      mode: mode,
      intervalDuration: intervalDuration,
      scheduledDeadline: scheduledDeadline,
      autoRenewOnConfirm: autoRenewOnConfirm,
      requiresCloud: requiresCloud,
      recipientIds: recipientIds,
      deliveryMethod: DeliveryMethod.email,
      message: message,
      sharedMemoryPrompt: sharedMemoryPrompt,
      importance: Importance.normal,
      status: TriggerStatus.waiting,
      lastConfirmedAt: DateTime.now(),
      isActive: true,
    );

    await saveTrigger(newTrigger);

    // Schedule notifications
    await _ref.read(notificationServiceProvider).scheduleWarningNotifications(newTrigger);

    return CreateTriggerResult(CreateTriggerStatus.success, newTrigger);
  }

  Future<void> confirmSafe(String triggerId) async {
    final trigger = _triggerBox.get(triggerId);
    if (trigger == null) return;

    trigger.lastConfirmedAt = DateTime.now();

    final isCountingDown = trigger.status == TriggerStatus.waiting ||
        trigger.status == TriggerStatus.reminderSent;

    if (isCountingDown && trigger.autoRenewOnConfirm) {
      trigger.status = TriggerStatus.waiting;
      await saveTrigger(trigger);
      
      // Reschedule notifications
      await _ref.read(notificationServiceProvider).scheduleWarningNotifications(trigger);
    } else if (!trigger.autoRenewOnConfirm) {
      trigger.status = TriggerStatus.cancelled;
      trigger.failureReason = FailureReason.cancelledByUser;
      trigger.isActive = false;
      await saveTrigger(trigger);

      // Cancel notifications
      await _ref.read(notificationServiceProvider).cancelScheduledNotifications(triggerId);

      // Trigger "retract handover" callback
      if (onRetractHandoverAnimation != null) {
        onRetractHandoverAnimation!();
      }
    }
  }

  Future<void> checkOverdueTriggers() async {
    final now = DateTime.now();
    for (var trigger in _triggerBox.values) {
      if (!trigger.isActive) continue;
      
      final isCountingDown = trigger.status == TriggerStatus.waiting ||
          trigger.status == TriggerStatus.reminderSent;
      
      if (!isCountingDown) continue;

      // Calculate deadline
      DateTime? deadline;
      if (trigger.mode == TriggerMode.scheduledDate) {
        deadline = trigger.scheduledDeadline;
      } else if (trigger.intervalDuration != null) {
        deadline = trigger.lastConfirmedAt.add(trigger.intervalDuration!);
      }

      if (deadline != null && now.isAfter(deadline)) {
        trigger.status = TriggerStatus.triggered;
        trigger.triggeredAt = now;
        await saveTrigger(trigger);

        debugPrint('LOG: Trigger ${trigger.id} 應觸發但尚未串接寄送');

        if (trigger.requiresCloud) {
          debugPrint('WARNING: Trigger ${trigger.id} 為長天期任務（requiresCloud=true），但在地端被標記逾期，跳過處理。');
        }
      }
    }
  }
}

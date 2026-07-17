import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trigger.dart';
import '../models/recipient.dart';
import '../models/user_quota.dart';
import 'notification_service.dart';
import 'cloud_sync_service.dart';

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
  cloudSyncFailed,
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
  late Box<String> _settingsBox;
  
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
    _settingsBox = await Hive.openBox<String>('settings');

    // Initialize default UserQuota if empty
    if (_quotaBox.isEmpty) {
      await _quotaBox.put('default', UserQuota(freeTriggersRemaining: 1));
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

  Trigger? getTrigger(String id) {
    return _triggerBox.get(id);
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

    // Sync to cloud if needed
    if (requiresCloud) {
      final success = await _ref.read(cloudSyncServiceProvider).uploadCloudTrigger(newTrigger);
      if (!success) {
        newTrigger.status = TriggerStatus.failed;
        newTrigger.failureReason = FailureReason.cloudSyncFailed;
        newTrigger.isActive = false;
        await saveTrigger(newTrigger);
        return CreateTriggerResult(CreateTriggerStatus.cloudSyncFailed, newTrigger);
      }
    }

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

      // Sync to cloud
      if (trigger.requiresCloud) {
        await _ref.read(cloudSyncServiceProvider).uploadCloudTrigger(trigger);
      }
    } else if (!trigger.autoRenewOnConfirm) {
      trigger.status = TriggerStatus.cancelled;
      trigger.failureReason = FailureReason.cancelledByUser;
      trigger.isActive = false;
      await saveTrigger(trigger);

      // Cancel notifications
      await _ref.read(notificationServiceProvider).cancelScheduledNotifications(triggerId);

      // Sync to cloud (cancellation)
      if (trigger.requiresCloud) {
        await _ref.read(cloudSyncServiceProvider).uploadCloudTrigger(trigger);
      }

      // Trigger "retract handover" callback
      if (onRetractHandoverAnimation != null) {
        onRetractHandoverAnimation!();
      }
    }
  }

  String? getUserEmail() {
    return _settingsBox.get('user_email');
  }

  Future<void> saveUserEmail(String email) async {
    await _settingsBox.put('user_email', email);
  }

  String? getLastError() {
    return _settingsBox.get('last_error');
  }

  Future<void> saveLastError(String error) async {
    await _settingsBox.put('last_error', error);
  }

  Future<void> clearLastError() async {
    await _settingsBox.delete('last_error');
  }

  Future<void> checkOverdueTriggers() async {
    final now = DateTime.now();
    final cloudSync = _ref.read(cloudSyncServiceProvider);
    final userEmail = getUserEmail();

    for (var trigger in _triggerBox.values) {
      if (!trigger.isActive) continue;
      
      // 冪等性防護：只處理狀態為 waiting 或 reminderSent 且已超時的 Trigger
      final isCountingDown = trigger.status == TriggerStatus.waiting ||
          trigger.status == TriggerStatus.reminderSent;
      
      if (!isCountingDown) continue;

      // 計算截止期限
      DateTime? deadline;
      if (trigger.mode == TriggerMode.scheduledDate) {
        deadline = trigger.scheduledDeadline;
      } else if (trigger.intervalDuration != null) {
        deadline = trigger.lastConfirmedAt.add(trigger.intervalDuration!);
      }

      if (deadline != null && now.isAfter(deadline)) {
        if (trigger.requiresCloud) {
          // 雲端排程任務由 Cloudflare Worker Cron 處理，本地僅標記為已觸發
          trigger.status = TriggerStatus.triggered;
          trigger.triggeredAt = now;
          await saveTrigger(trigger);
          debugPrint('LOG: Cloud Trigger ${trigger.id} is overdue. Status marked to triggered locally.');
        } else {
          // 純地端任務：立即啟動補寄信件流程
          final emails = <String>[];
          final names = <String>[];
          for (var rId in trigger.recipientIds) {
            final recipient = getRecipient(rId);
            if (recipient != null && recipient.email.isNotEmpty) {
              emails.add(recipient.email.trim());
              names.add(recipient.name.trim());
            }
          }

          if (emails.isNotEmpty) {
            debugPrint('LOG: Local Trigger ${trigger.id} is overdue. Sending email.');
            
            // 立即變更狀態為 triggered 並存入 Hive 鎖定，防止非同步二次重入重複寄信
            final originalStatus = trigger.status;
            trigger.status = TriggerStatus.triggered;
            trigger.triggeredAt = now;
            await saveTrigger(trigger);

            final success = await cloudSync.sendLocalTriggerEmail(
              triggerId: trigger.id,
              recipientEmails: emails.join(','),
              message: trigger.message,
              sharedMemory: trigger.sharedMemoryPrompt,
              userEmail: userEmail,
              recipientNames: names.join(', '),
            );

            if (success) {
              trigger.status = TriggerStatus.delivered;
              trigger.isActive = false; // 任務結束
              await saveTrigger(trigger);
              debugPrint('LOG: Local Trigger ${trigger.id} email delivered successfully.');
            } else {
              // 寄信失敗，還原狀態與觸發時間，保持任務為 Active 以供後續自動/手動重試
              trigger.status = originalStatus;
              trigger.triggeredAt = null;
              await saveTrigger(trigger);
              debugPrint('ERROR: Local Trigger ${trigger.id} email sending failed. Reverted status to $originalStatus.');
            }
          }
 else {
            // 無收件人信箱
            trigger.status = TriggerStatus.failed;
            trigger.failureReason = FailureReason.sendFailed;
            trigger.isActive = false;
            await saveTrigger(trigger);
            debugPrint('ERROR: Local Trigger ${trigger.id} has no recipient emails.');
          }
        }
      }
    }
  }

  Future<void> cancelTrigger(String triggerId) async {
    final trigger = getTrigger(triggerId);
    if (trigger == null) return;

    trigger.status = TriggerStatus.cancelled;
    trigger.isActive = false;
    await saveTrigger(trigger);
    debugPrint('LOG: Trigger $triggerId has been cancelled.');

    // 額度退還規則：建立後 5 分鐘內刪除，退還 1 次免費額度（僅限免費版使用者）
    final quota = getUserQuota();
    final isFreeUser = !quota.isLocalUnlimited && !quota.isCloudGuardianActive;
    if (isFreeUser) {
      final now = DateTime.now();
      final difference = now.difference(trigger.lastConfirmedAt);
      if (difference.inMinutes < 5) {
        quota.freeTriggersRemaining += 1;
        if (quota.freeTriggersRemaining > 1) {
          quota.freeTriggersRemaining = 1; // 限制免費額度上限為 1
        }
        await _quotaBox.put('default', quota);
        debugPrint('LOG: Trigger cancelled within 5 minutes. 1 free trigger quota refunded.');
      } else {
        debugPrint('LOG: Trigger cancelled after 5 minutes. No quota refund.');
      }
    }

    // 若為雲端模式，同步通知 Worker 更新狀態為 cancelled
    if (trigger.requiresCloud) {
      final cloudSync = _ref.read(cloudSyncServiceProvider);
      await cloudSync.cancelCloudTrigger(triggerId);
    }
  }
}

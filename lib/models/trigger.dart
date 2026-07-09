import 'package:hive/hive.dart';

part 'trigger.g.dart';

@HiveType(typeId: 0)
enum TriggerMode {
  @HiveField(0)
  quick,
  @HiveField(1)
  scheduledDate,
  @HiveField(2)
  recurring,
  @HiveField(3)
  untilCancel,
}

@HiveType(typeId: 1)
enum DeliveryMethod {
  @HiveField(0)
  email,
  @HiveField(1)
  line,
  @HiveField(2)
  sms,
  @HiveField(3)
  webhook,
}

@HiveType(typeId: 2)
enum Importance {
  @HiveField(0)
  normal,
  @HiveField(1)
  important,
  @HiveField(2)
  critical,
}

@HiveType(typeId: 3)
enum TriggerStatus {
  @HiveField(0)
  draft,
  @HiveField(1)
  waiting,
  @HiveField(2)
  reminderSent,
  @HiveField(3)
  triggered,
  @HiveField(4)
  delivered,
  @HiveField(5)
  cancelled,
  @HiveField(6)
  expired,
  @HiveField(7)
  failed,
}

@HiveType(typeId: 4)
enum FailureReason {
  @HiveField(0)
  cancelledByUser,
  @HiveField(1)
  quotaExceeded,
  @HiveField(2)
  cloudSyncFailed,
  @HiveField(3)
  sendFailed,
}

@HiveType(typeId: 5)
class Trigger extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  TriggerMode mode;

  @HiveField(2)
  Duration? intervalDuration;

  @HiveField(3)
  DateTime? scheduledDeadline;

  @HiveField(4)
  bool autoRenewOnConfirm;

  @HiveField(5)
  bool requiresCloud;

  @HiveField(6)
  List<String> recipientIds;

  @HiveField(7)
  DeliveryMethod deliveryMethod;

  @HiveField(8)
  String message;

  @HiveField(9)
  String sharedMemoryPrompt;

  @HiveField(10)
  Importance importance;

  @HiveField(11)
  TriggerStatus status;

  @HiveField(12)
  FailureReason? failureReason;

  @HiveField(13)
  DateTime lastConfirmedAt;

  @HiveField(14)
  DateTime? triggeredAt;

  @HiveField(15)
  bool isActive;

  Trigger({
    required this.id,
    required this.mode,
    this.intervalDuration,
    this.scheduledDeadline,
    required this.autoRenewOnConfirm,
    required this.requiresCloud,
    required this.recipientIds,
    required this.deliveryMethod,
    required this.message,
    required this.sharedMemoryPrompt,
    this.importance = Importance.normal,
    this.status = TriggerStatus.draft,
    this.failureReason,
    required this.lastConfirmedAt,
    this.triggeredAt,
    this.isActive = false,
  });
}

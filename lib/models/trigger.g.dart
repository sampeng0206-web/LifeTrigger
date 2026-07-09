// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trigger.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TriggerAdapter extends TypeAdapter<Trigger> {
  @override
  final int typeId = 5;

  @override
  Trigger read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Trigger(
      id: fields[0] as String,
      mode: fields[1] as TriggerMode,
      intervalDuration: fields[2] as Duration?,
      scheduledDeadline: fields[3] as DateTime?,
      autoRenewOnConfirm: fields[4] as bool,
      requiresCloud: fields[5] as bool,
      recipientIds: (fields[6] as List).cast<String>(),
      deliveryMethod: fields[7] as DeliveryMethod,
      message: fields[8] as String,
      sharedMemoryPrompt: fields[9] as String,
      importance: fields[10] as Importance,
      status: fields[11] as TriggerStatus,
      failureReason: fields[12] as FailureReason?,
      lastConfirmedAt: fields[13] as DateTime,
      triggeredAt: fields[14] as DateTime?,
      isActive: fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Trigger obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mode)
      ..writeByte(2)
      ..write(obj.intervalDuration)
      ..writeByte(3)
      ..write(obj.scheduledDeadline)
      ..writeByte(4)
      ..write(obj.autoRenewOnConfirm)
      ..writeByte(5)
      ..write(obj.requiresCloud)
      ..writeByte(6)
      ..write(obj.recipientIds)
      ..writeByte(7)
      ..write(obj.deliveryMethod)
      ..writeByte(8)
      ..write(obj.message)
      ..writeByte(9)
      ..write(obj.sharedMemoryPrompt)
      ..writeByte(10)
      ..write(obj.importance)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.failureReason)
      ..writeByte(13)
      ..write(obj.lastConfirmedAt)
      ..writeByte(14)
      ..write(obj.triggeredAt)
      ..writeByte(15)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TriggerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TriggerModeAdapter extends TypeAdapter<TriggerMode> {
  @override
  final int typeId = 0;

  @override
  TriggerMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TriggerMode.quick;
      case 1:
        return TriggerMode.scheduledDate;
      case 2:
        return TriggerMode.recurring;
      case 3:
        return TriggerMode.untilCancel;
      default:
        return TriggerMode.quick;
    }
  }

  @override
  void write(BinaryWriter writer, TriggerMode obj) {
    switch (obj) {
      case TriggerMode.quick:
        writer.writeByte(0);
        break;
      case TriggerMode.scheduledDate:
        writer.writeByte(1);
        break;
      case TriggerMode.recurring:
        writer.writeByte(2);
        break;
      case TriggerMode.untilCancel:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TriggerModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DeliveryMethodAdapter extends TypeAdapter<DeliveryMethod> {
  @override
  final int typeId = 1;

  @override
  DeliveryMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DeliveryMethod.email;
      case 1:
        return DeliveryMethod.line;
      case 2:
        return DeliveryMethod.sms;
      case 3:
        return DeliveryMethod.webhook;
      default:
        return DeliveryMethod.email;
    }
  }

  @override
  void write(BinaryWriter writer, DeliveryMethod obj) {
    switch (obj) {
      case DeliveryMethod.email:
        writer.writeByte(0);
        break;
      case DeliveryMethod.line:
        writer.writeByte(1);
        break;
      case DeliveryMethod.sms:
        writer.writeByte(2);
        break;
      case DeliveryMethod.webhook:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ImportanceAdapter extends TypeAdapter<Importance> {
  @override
  final int typeId = 2;

  @override
  Importance read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Importance.normal;
      case 1:
        return Importance.important;
      case 2:
        return Importance.critical;
      default:
        return Importance.normal;
    }
  }

  @override
  void write(BinaryWriter writer, Importance obj) {
    switch (obj) {
      case Importance.normal:
        writer.writeByte(0);
        break;
      case Importance.important:
        writer.writeByte(1);
        break;
      case Importance.critical:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TriggerStatusAdapter extends TypeAdapter<TriggerStatus> {
  @override
  final int typeId = 3;

  @override
  TriggerStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TriggerStatus.draft;
      case 1:
        return TriggerStatus.waiting;
      case 2:
        return TriggerStatus.reminderSent;
      case 3:
        return TriggerStatus.triggered;
      case 4:
        return TriggerStatus.delivered;
      case 5:
        return TriggerStatus.cancelled;
      case 6:
        return TriggerStatus.expired;
      case 7:
        return TriggerStatus.failed;
      default:
        return TriggerStatus.draft;
    }
  }

  @override
  void write(BinaryWriter writer, TriggerStatus obj) {
    switch (obj) {
      case TriggerStatus.draft:
        writer.writeByte(0);
        break;
      case TriggerStatus.waiting:
        writer.writeByte(1);
        break;
      case TriggerStatus.reminderSent:
        writer.writeByte(2);
        break;
      case TriggerStatus.triggered:
        writer.writeByte(3);
        break;
      case TriggerStatus.delivered:
        writer.writeByte(4);
        break;
      case TriggerStatus.cancelled:
        writer.writeByte(5);
        break;
      case TriggerStatus.expired:
        writer.writeByte(6);
        break;
      case TriggerStatus.failed:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TriggerStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FailureReasonAdapter extends TypeAdapter<FailureReason> {
  @override
  final int typeId = 4;

  @override
  FailureReason read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FailureReason.cancelledByUser;
      case 1:
        return FailureReason.quotaExceeded;
      case 2:
        return FailureReason.cloudSyncFailed;
      case 3:
        return FailureReason.sendFailed;
      default:
        return FailureReason.cancelledByUser;
    }
  }

  @override
  void write(BinaryWriter writer, FailureReason obj) {
    switch (obj) {
      case FailureReason.cancelledByUser:
        writer.writeByte(0);
        break;
      case FailureReason.quotaExceeded:
        writer.writeByte(1);
        break;
      case FailureReason.cloudSyncFailed:
        writer.writeByte(2);
        break;
      case FailureReason.sendFailed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureReasonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

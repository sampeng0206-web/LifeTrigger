// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_quota.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserQuotaAdapter extends TypeAdapter<UserQuota> {
  @override
  final int typeId = 8;

  @override
  UserQuota read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserQuota(
      freeTriggersRemaining: fields[0] as int,
      isLocalUnlimited: fields[1] as bool,
      isCloudGuardianActive: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserQuota obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.freeTriggersRemaining)
      ..writeByte(1)
      ..write(obj.isLocalUnlimited)
      ..writeByte(2)
      ..write(obj.isCloudGuardianActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserQuotaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

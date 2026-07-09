// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipient.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipientAdapter extends TypeAdapter<Recipient> {
  @override
  final int typeId = 7;

  @override
  Recipient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipient(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      relationship: fields[3] as Relationship,
    );
  }

  @override
  void write(BinaryWriter writer, Recipient obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.relationship);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RelationshipAdapter extends TypeAdapter<Relationship> {
  @override
  final int typeId = 6;

  @override
  Relationship read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Relationship.family;
      case 1:
        return Relationship.spouse;
      case 2:
        return Relationship.friend;
      case 3:
        return Relationship.lawyer;
      case 4:
        return Relationship.colleague;
      case 5:
        return Relationship.other;
      default:
        return Relationship.family;
    }
  }

  @override
  void write(BinaryWriter writer, Relationship obj) {
    switch (obj) {
      case Relationship.family:
        writer.writeByte(0);
        break;
      case Relationship.spouse:
        writer.writeByte(1);
        break;
      case Relationship.friend:
        writer.writeByte(2);
        break;
      case Relationship.lawyer:
        writer.writeByte(3);
        break;
      case Relationship.colleague:
        writer.writeByte(4);
        break;
      case Relationship.other:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

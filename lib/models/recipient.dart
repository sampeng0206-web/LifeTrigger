import 'package:hive/hive.dart';

part 'recipient.g.dart';

@HiveType(typeId: 6)
enum Relationship {
  @HiveField(0)
  family,
  @HiveField(1)
  spouse,
  @HiveField(2)
  friend,
  @HiveField(3)
  lawyer,
  @HiveField(4)
  colleague,
  @HiveField(5)
  other,
}

@HiveType(typeId: 7)
class Recipient extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String email;

  @HiveField(3)
  Relationship relationship;

  Recipient({
    required this.id,
    required this.name,
    required this.email,
    required this.relationship,
  });
}

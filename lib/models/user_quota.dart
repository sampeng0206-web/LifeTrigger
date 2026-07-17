import 'package:hive/hive.dart';

part 'user_quota.g.dart';

@HiveType(typeId: 8)
class UserQuota extends HiveObject {
  @HiveField(0)
  int freeTriggersRemaining;

  @HiveField(1)
  bool isLocalUnlimited;

  @HiveField(2)
  bool isCloudGuardianActive;

  UserQuota({
    this.freeTriggersRemaining = 1,
    this.isLocalUnlimited = false,
    this.isCloudGuardianActive = false,
  });
}

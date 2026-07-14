// ============================================================================
// 手動診斷工具 (Manual Diagnostic Tool)
// ============================================================================
// 本檔案僅作為開發與測試期間手動驗證 Hive 資料庫內容之用途，不屬於常態單元測試。
// 檔名特意命名為 verify_hive_manual.dart（非 _test.dart 結尾），
// 以避免自動化測試套件（flutter test）在常態執行時自動載入此檔案而導致失敗。
//
// 手動執行指令：
// flutter test test/verify_hive_manual.dart
// ============================================================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_trigger/models/trigger.dart';
import 'package:life_trigger/models/recipient.dart';
import 'package:life_trigger/models/user_quota.dart';
import 'package:life_trigger/services/storage_service.dart';

void main() {
  test('Verify Hive Database Contents', () async {
    final path = Directory('scratch/hive_boxes').absolute.path;
    Hive.init(path);

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TriggerModeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(DeliveryMethodAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ImportanceAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TriggerStatusAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(FailureReasonAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(TriggerAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(RelationshipAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(RecipientAdapter());
    if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(UserQuotaAdapter());
    if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(DurationAdapter());

    final triggerBox = await Hive.openBox<Trigger>('triggers');
    final recipientBox = await Hive.openBox<Recipient>('recipients');
    final quotaBox = await Hive.openBox<UserQuota>('user_quotas');

    print('=== RECIPIENTS ===');
    for (var key in recipientBox.keys) {
      final val = recipientBox.get(key);
      if (val != null) {
        print('Key: $key');
        print('  ID: ${val.id}');
        print('  Name: ${val.name}');
        print('  Email: ${val.email}');
        print('  Relationship: ${val.relationship}');
      }
    }

    print('\n=== TRIGGERS ===');
    for (var key in triggerBox.keys) {
      final val = triggerBox.get(key);
      if (val != null) {
        print('Key: $key');
        print('  ID: ${val.id}');
        print('  Mode: ${val.mode}');
        print('  Interval: ${val.intervalDuration}');
        print('  AutoRenew: ${val.autoRenewOnConfirm}');
        print('  RequiresCloud: ${val.requiresCloud}');
        print('  Recipient IDs: ${val.recipientIds}');
        print('  Message: ${val.message}');
        print('  Shared Memory Prompt: ${val.sharedMemoryPrompt}');
        print('  Status: ${val.status}');
        print('  Last Confirmed: ${val.lastConfirmedAt}');
        print('  IsActive: ${val.isActive}');
      }
    }

    print('\n=== USER QUOTA ===');
    for (var key in quotaBox.keys) {
      final val = quotaBox.get(key);
      if (val != null) {
        print('Key: $key');
        print('  Before - Free Triggers: ${val.freeTriggersRemaining}, IsLocalUnlimited: ${val.isLocalUnlimited}, IsCloudGuardianActive: ${val.isCloudGuardianActive}');
        val.isLocalUnlimited = false;
        val.isCloudGuardianActive = false;
        await quotaBox.put(key, val);
        print('  After - Free Triggers: ${val.freeTriggersRemaining}, IsLocalUnlimited: ${val.isLocalUnlimited}, IsCloudGuardianActive: ${val.isCloudGuardianActive}');
      }
    }

    await triggerBox.close();
    await recipientBox.close();
    await quotaBox.close();
  });
}

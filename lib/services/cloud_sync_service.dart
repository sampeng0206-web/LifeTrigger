import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/trigger.dart';
import 'storage_service.dart';

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return CloudSyncService(ref);
});

class CloudSyncService {
  final Ref _ref;

  // ============================================================================
  // Cloudflare Worker API 設定 (供使用者在編輯器中修改)
  // ============================================================================
  static const String baseUrl = 'https://life-trigger-scheduler.sampeng-lifetrigger.workers.dev'; 
  static const String apiAuthKey = 'dQGrkEhXPkRoOohHC0L/uJXFgENT2LUiXQ1GRCjRm70=';


  CloudSyncService(this._ref);

  bool get isConfigured =>
      baseUrl.isNotEmpty &&
      !baseUrl.contains('YOUR_CLOUDFLARE_WORKER_URL_HERE');

  /// 上傳 / 更新雲端上的 Trigger 資料
  Future<bool> uploadCloudTrigger(Trigger trigger) async {
    if (!isConfigured) {
      debugPrint('WARNING: CloudSyncService: baseUrl is not configured. Bypassing upload.');
      // 如果未設定，且處於除錯模式下，為了便於本地測試，回傳 true。正式部署必須設定。
      if (kDebugMode) {
        return true;
      }
      return false;
    }

    final client = HttpClient();
    // 預防連線超時
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      // 1. 取得 RevenueCat App User ID
      final customerInfo = await Purchases.getCustomerInfo();
      final userId = customerInfo.originalAppUserId;
      if (userId.isEmpty) {
        debugPrint('ERROR: CloudSyncService: RevenueCat User ID is empty.');
        return false;
      }

      // 2. 彙整收件人 Email (多個以逗號隔開) 與姓名
      final storage = _ref.read(storageServiceProvider);
      final emails = <String>[];
      final names = <String>[];
      for (var rId in trigger.recipientIds) {
        final recipient = storage.getRecipient(rId);
        if (recipient != null) {
          if (recipient.email.isNotEmpty) {
            emails.add(recipient.email.trim());
          }
          names.add(recipient.name.trim());
        }
      }

      if (emails.isEmpty) {
        debugPrint('ERROR: CloudSyncService: No recipient emails found.');
        return false;
      }

      final userEmail = storage.getUserEmail();

      // 3. 計算截止期限
      DateTime deadline;
      if (trigger.mode == TriggerMode.scheduledDate && trigger.scheduledDeadline != null) {
        deadline = trigger.scheduledDeadline!;
      } else if (trigger.intervalDuration != null) {
        deadline = trigger.lastConfirmedAt.add(trigger.intervalDuration!);
      } else {
        deadline = DateTime.now().add(const Duration(days: 7));
      }

      // 4. 映射狀態
      String statusStr = 'waiting';
      if (trigger.status == TriggerStatus.triggered) {
        statusStr = 'triggered';
      } else if (trigger.status == TriggerStatus.delivered) {
        statusStr = 'delivered';
      } else if (trigger.status == TriggerStatus.cancelled) {
        statusStr = 'cancelled';
      } else if (trigger.status == TriggerStatus.failed) {
        statusStr = 'failed';
      }

      // 5. 組合 Request Body
      final body = {
        'id': trigger.id,
        'user_id': userId,
        'recipient_emails': emails.join(','),
        'deadline': deadline.toUtc().toIso8601String(),
        'is_active': trigger.isActive ? 1 : 0,
        'requires_cloud': trigger.requiresCloud ? 1 : 0,
        'status': statusStr,
        'payload': {
          'message': trigger.message,
          'shared_memory': trigger.sharedMemoryPrompt,
          'user_email': userEmail,
          'recipient_names': names.join(', '),
        }
      };

      // 6. 發送 HTTPS 請求
      final uri = Uri.parse('$baseUrl/api/triggers');
      final request = await client.postUrl(uri);
      
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('X-API-Key', apiAuthKey);
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      debugPrint('LOG: CloudSyncService upload response status: ${response.statusCode}, body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resJson = jsonDecode(responseBody);
        return resJson['success'] == true;
      } else {
        debugPrint('ERROR: CloudSyncService upload failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('ERROR: CloudSyncService upload failed: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// 從雲端下載並還原該使用者的 Trigger 資料
  Future<List<Map<String, dynamic>>?> restoreCloudTriggers() async {
    if (!isConfigured) {
      debugPrint('WARNING: CloudSyncService: baseUrl is not configured. Bypassing restore.');
      return null;
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      // 1. 取得 RevenueCat App User ID
      final customerInfo = await Purchases.getCustomerInfo();
      final userId = customerInfo.originalAppUserId;
      if (userId.isEmpty) {
        debugPrint('ERROR: CloudSyncService: RevenueCat User ID is empty for restore.');
        return null;
      }

      // 2. 發送 HTTPS GET 請求
      final uri = Uri.parse('$baseUrl/api/triggers/restore?user_id=${Uri.encodeComponent(userId)}');
      final request = await client.getUrl(uri);
      
      request.headers.set('X-API-Key', apiAuthKey);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      debugPrint('LOG: CloudSyncService restore response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final resJson = jsonDecode(responseBody);
        if (resJson['success'] == true && resJson['triggers'] != null) {
          final list = List<Map<String, dynamic>>.from(resJson['triggers']);
          return list;
        }
      }
      return null;
    } catch (e) {
      debugPrint('ERROR: CloudSyncService restore failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// 地端觸發逾期時，發送 API 請求給 Cloudflare Worker 以寄信
  Future<bool> sendLocalTriggerEmail({
    required String triggerId,
    required String recipientEmails,
    required String message,
    required String sharedMemory,
    String? userEmail,
    required String recipientNames,
  }) async {
    if (!isConfigured) {
      debugPrint('WARNING: CloudSyncService: baseUrl is not configured. Bypassing sendLocalTriggerEmail.');
      return false;
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final body = {
        'recipient_emails': recipientEmails,
        'message': message,
        'shared_memory': sharedMemory,
        'user_email': userEmail,
        'recipient_names': recipientNames,
      };

      final uri = Uri.parse('$baseUrl/api/triggers/send-local');
      final request = await client.postUrl(uri);
      
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('X-API-Key', apiAuthKey);
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      debugPrint('LOG: sendLocalTriggerEmail response status: ${response.statusCode}, body: $responseBody');

      if (response.statusCode == 200) {
        final resJson = jsonDecode(responseBody);
        return resJson['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('ERROR: sendLocalTriggerEmail failed: $e');
      return false;
    } finally {
      client.close();
    }
  }
}

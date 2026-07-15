import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../models/trigger.dart';
import '../models/recipient.dart';
import '../widgets/countdown_display.dart';

final activeTriggersProvider = StateNotifierProvider<ActiveTriggersNotifier, List<Trigger>>((ref) {
  return ActiveTriggersNotifier(ref.read(storageServiceProvider));
});

final restoreCheckedProvider = StateProvider<bool>((ref) => false);

class ActiveTriggersNotifier extends StateNotifier<List<Trigger>> {
  final StorageService _storageService;

  ActiveTriggersNotifier(this._storageService) : super([]) {
    refresh();
  }

  void refresh() {
    state = _storageService.getActiveTriggers();
  }

  Future<void> confirmSafe(String id) async {
    await _storageService.confirmSafe(id);
    refresh();
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTriggers = ref.watch(activeTriggersProvider);
    final hasActive = activeTriggers.isNotEmpty;
    final primaryTrigger = hasActive ? activeTriggers.first : null;

    // 自動偵測空資料庫與訂閱狀態以提示還原
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final checked = ref.read(restoreCheckedProvider);
      if (!checked) {
        ref.read(restoreCheckedProvider.notifier).state = true;
        
        final storage = ref.read(storageServiceProvider);
        if (storage.getAllTriggers().isEmpty) {
          final quota = storage.getUserQuota();
          if (quota.isCloudGuardianActive) {
            _showRestoreDialog(context, ref);
          }
        }
      }
    });

    // 計算 deadline (若已啟動)
    DateTime? deadline;
    if (primaryTrigger != null) {
      if (primaryTrigger.mode == TriggerMode.scheduledDate) {
        deadline = primaryTrigger.scheduledDeadline;
      } else if (primaryTrigger.intervalDuration != null) {
        deadline = primaryTrigger.lastConfirmedAt.add(primaryTrigger.intervalDuration!);
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[950],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Colors.grey[400]),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SimpleDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text('設定與說明', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/help');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                        child: Row(
                          children: const [
                            Icon(Icons.help_outline, color: Colors.blueAccent),
                            SizedBox(width: 12),
                            Text('使用說明與條款', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: Colors.grey[800], height: 1),
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/purchase');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                        child: Row(
                          children: const [
                            Icon(Icons.star_outline, color: Colors.amber),
                            SizedBox(width: 12),
                            Text('方案升級與恢復', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: Colors.grey[800], height: 1),
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(context);
                        _triggerManualRestore(context, ref);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                        child: Row(
                          children: const [
                            Icon(Icons.cloud_download_outlined, color: Colors.blueAccent),
                            SizedBox(width: 12),
                            Text('從雲端還原守護', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: Colors.grey[800], height: 1),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('關閉', style: TextStyle(color: Colors.grey)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. 頂部狀態文字
              Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    hasActive ? '守護中' : '今天一切都好嗎？',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: hasActive ? Colors.greenAccent[400] : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasActive ? '安心守護通知已啟用' : '目前尚未安排任何安心守護',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),

              // 2. 中央倒數計時器
              if (hasActive && deadline != null)
                CountdownDisplay(deadline: deadline)
              else
                const SizedBox(height: 100),

              // 3. 大型主按鈕
              Center(
                child: hasActive
                    ? _buildHugePresenceButton(context, ref, primaryTrigger!)
                    : _buildCreateButton(context),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHugePresenceButton(BuildContext context, WidgetRef ref, Trigger trigger) {
    return GestureDetector(
      onTap: () async {
        // A. 播放信封收回動畫對話框
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.85),
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, anim1, anim2) {
            return const RetractHandoverDialog();
          },
        );

        // B. 動畫播放完畢後，正式呼叫 confirmSafe 寫入資料庫
        await ref.read(activeTriggersProvider.notifier).confirmSafe(trigger.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('守護狀態已更新，防呆提醒已安全重置！'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Colors.blueAccent, Colors.tealAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: Colors.white,
              ),
              SizedBox(height: 12),
              Text(
                '我還在',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 8,
      ),
      onPressed: () {
        context.push('/create');
      },
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 24),
          SizedBox(width: 8),
          Text(
            '＋ 開始安排',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('雲端資料還原', style: TextStyle(color: Colors.white)),
        content: const Text(
          '系統偵測到此裝置本地尚未設定守護，且您擁有「交代守護版」資格。是否要從雲端搜尋並還原您的守護紀錄？',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('暫時不要', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performRestore(context, ref);
            },
            child: const Text('立即還原', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerManualRestore(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await ref.read(purchaseServiceProvider).checkEntitlements();
    } catch (e) {
      debugPrint('Error checking entitlements: $e');
    } finally {
      if (context.mounted) {
        Navigator.pop(context); // 關閉 loading
      }
    }

    final quota = ref.read(storageServiceProvider).getUserQuota();
    if (!quota.isCloudGuardianActive) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('權限不足', style: TextStyle(color: Colors.white)),
          content: const Text('從雲端還原守護資料為「交代守護版」專屬功能。請先升級您的訂閱方案。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('確認'),
            ),
          ],
        ),
      );
      return;
    }

    _performRestore(context, ref);
  }

  Future<void> _performRestore(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: SimpleDialog(
          backgroundColor: Colors.transparent,
          children: [
            Center(
              child: CircularProgressIndicator(),
            ),
            SizedBox(height: 16),
            Center(
              child: Text('正在從雲端載入守護資料...', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    final syncService = ref.read(cloudSyncServiceProvider);
    final cloudTriggers = await syncService.restoreCloudTriggers();

    if (context.mounted) {
      Navigator.pop(context); // 關閉 loading
    }

    if (cloudTriggers == null) {
      _showResultDialog(context, '讀取失敗', '無法連線至雲端伺服器，請檢查網路連線。');
      return;
    }

    if (cloudTriggers.isEmpty) {
      _showResultDialog(context, '無雲端資料', '您的帳號目前沒有任何儲存於雲端的守護紀錄。');
      return;
    }

    // 顯示雲端 Trigger 列表供使用者選擇
    _showSelectTriggersDialog(context, ref, cloudTriggers);
  }

  void _showResultDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  void _showSelectTriggersDialog(
      BuildContext context, WidgetRef ref, List<Map<String, dynamic>> cloudTriggers) {
    final selectedStates = List<bool>.generate(cloudTriggers.length, (index) => true);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('選擇要還原的守護', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cloudTriggers.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey[800]),
                itemBuilder: (context, index) {
                  final trigger = cloudTriggers[index];
                  final emails = trigger['recipient_emails'] ?? '';
                  final payload = trigger['payload'] ?? {};
                  final msg = payload['message'] ?? '';
                  final deadlineStr = trigger['deadline'] ?? '';
                  
                  String timeLabel = '';
                  try {
                    final deadline = DateTime.parse(deadlineStr).toLocal();
                    timeLabel = '到期: ${deadline.month}/${deadline.day} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
                  } catch (e) {
                    timeLabel = '到期日格式錯誤';
                  }

                  return CheckboxListTile(
                    title: Text(
                      emails,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          timeLabel,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    value: selectedStates[index],
                    activeColor: Colors.blueAccent,
                    checkColor: Colors.white,
                    onChanged: (val) {
                      setDialogState(() {
                        selectedStates[index] = val ?? false;
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  int restoreCount = 0;
                  final storage = ref.read(storageServiceProvider);
                  final notificationService = ref.read(notificationServiceProvider);

                  for (int i = 0; i < cloudTriggers.length; i++) {
                    if (selectedStates[i]) {
                      final triggerJson = cloudTriggers[i];
                      final id = triggerJson['id'];
                      final emailsStr = triggerJson['recipient_emails'] as String;
                      final payload = triggerJson['payload'] as Map<String, dynamic>;
                      final message = payload['message'] as String;
                      final sharedMemory = payload['shared_memory'] as String;
                      final deadlineStr = triggerJson['deadline'] as String;

                      final emails = emailsStr.split(',').map((e) => e.trim()).toList();
                      final recipientIds = <String>[];
                      for (var email in emails) {
                        final recipientId = const Uuid().v4();
                        final recipient = Recipient(
                          id: recipientId,
                          name: email.split('@').first,
                          email: email,
                          relationship: Relationship.friend,
                        );
                        await storage.saveRecipient(recipient);
                        recipientIds.add(recipientId);
                      }

                      final deadlineUtc = DateTime.parse(deadlineStr);
                      final localDeadline = deadlineUtc.toLocal();

                      final newTrigger = Trigger(
                        id: id,
                        mode: TriggerMode.quick,
                        scheduledDeadline: localDeadline,
                        autoRenewOnConfirm: true,
                        requiresCloud: triggerJson['requires_cloud'] == 1,
                        recipientIds: recipientIds,
                        deliveryMethod: DeliveryMethod.email,
                        message: message,
                        sharedMemoryPrompt: sharedMemory,
                        importance: Importance.normal,
                        status: TriggerStatus.waiting,
                        lastConfirmedAt: DateTime.now(),
                        isActive: true,
                      );

                      await storage.saveTrigger(newTrigger);

                      await notificationService.scheduleWarningNotifications(newTrigger);

                      restoreCount++;
                    }
                  }

                  if (restoreCount > 0) {
                    ref.read(activeTriggersProvider.notifier).refresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('成功還原 $restoreCount 筆安心守護！'),
                          backgroundColor: Colors.greenAccent[700],
                        ),
                      );
                    }
                  }
                },
                child: const Text('確認還原', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }
}

/// 信封收回微動畫對話框
class RetractHandoverDialog extends StatefulWidget {
  const RetractHandoverDialog({super.key});

  @override
  State<RetractHandoverDialog> createState() => _RetractHandoverDialogState();
}

class _RetractHandoverDialogState extends State<RetractHandoverDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _envelopeSlideY;
  late Animation<double> _envelopeOpacity;
  late Animation<double> _boxScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    // 信封下滑動畫 (前 60% 完成)
    _envelopeSlideY = Tween<double>(begin: -150.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInBack),
      ),
    );

    // 信封漸隱 (0.5 到 0.7 之間)
    _envelopeOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.7, curve: Curves.easeOut),
      ),
    );

    // 安全盒縮放震動 (當信封滑入時震動，約 55% 開始)
    _boxScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 15),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pop(context);
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 300,
              width: 300,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. 安全盒 (下方盾牌圖示)
                      Transform.scale(
                        scale: _boxScale.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[900],
                            border: Border.all(
                              color: Colors.greenAccent.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.15 * _controller.value),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 64,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                      
                      // 2. 信封 (從上方下滑墜入)
                      if (_controller.value < 0.7)
                        Transform.translate(
                          offset: Offset(0, _envelopeSlideY.value),
                          child: Opacity(
                            opacity: _envelopeOpacity.value,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.mail_outline,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '安全收回通知',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '守護狀態更新中，防呆提醒已安全重置...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


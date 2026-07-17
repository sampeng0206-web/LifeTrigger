import 'dart:async';
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
import '../widgets/brand_intro_view.dart';
import '../widgets/trigger_list_view.dart';
import '../widgets/confirm_all_dialog.dart';

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

  Future<void> confirmAllSafe() async {
    final active = _storageService.getActiveTriggers();
    for (var trigger in active) {
      await _storageService.confirmSafe(trigger.id);
    }
    refresh();
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 啟動時立即執行一次逾期檢查，免去 10 秒等待
    _checkOverdueAndRefresh();

    // 每 10 秒自動檢查一次地端逾期狀態，並同步畫面
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkOverdueAndRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkOverdueAndRefresh();
    }
  }

  Future<void> _checkOverdueAndRefresh() async {
    await ref.read(storageServiceProvider).checkOverdueTriggers();
    if (mounted) {
      ref.read(activeTriggersProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTriggers = ref.watch(activeTriggersProvider);
    final hasActive = activeTriggers.isNotEmpty;

    // 自動偵測空資料庫與訂閱狀態以提示還原
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final checked = ref.read(restoreCheckedProvider);
      if (!checked) {
        ref.read(restoreCheckedProvider.notifier).state = true;
        
        final storage = ref.read(storageServiceProvider);
        if (storage.getAllTriggers().isEmpty) {
          final quota = storage.getUserQuota();
          if (quota.isCloudGuardianActive) {
            _showRestoreDialog(context);
          }
        }
      }
    });

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
                        context.push('/settings');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                        child: Row(
                          children: const [
                            Icon(Icons.person_outline, color: Colors.blueAccent),
                            SizedBox(width: 12),
                            Text('個人安全設定', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: Colors.grey[800], height: 1),
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
                        _triggerManualRestore(context);
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
          child: hasActive
              ? TriggerListView(activeTriggers: activeTriggers)
              : const BrandIntroView(),
        ),
      ),
      floatingActionButton: hasActive
          ? _buildFloatingPresenceButton(context, activeTriggers)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFloatingPresenceButton(BuildContext context, List<Trigger> activeTriggers) {
    return Container(
      height: 58,
      width: 200,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(29),
        gradient: const LinearGradient(
          colors: [Colors.blueAccent, Colors.tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(29),
          onTap: () => _handlePresenceConfirmation(context, activeTriggers),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 22,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  '我還在',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePresenceConfirmation(BuildContext context, List<Trigger> activeTriggers) async {
    final storage = ref.read(storageServiceProvider);
    
    // Look up recipient names for all active triggers
    final recipientNames = activeTriggers.map((trigger) {
      return trigger.recipientIds
          .map((id) => storage.getRecipient(id)?.name ?? '未知收件人')
          .join(', ');
    }).toList();

    // Show double confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmAllDialog(recipientNames: recipientNames),
    );

    if (confirmed == true) {
      if (context.mounted) {
        // Play envelope retraction animation
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.85),
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, anim1, anim2) {
            return const RetractHandoverDialog();
          },
        );
      }

      // Execute confirmation database write and notification rescheduling
      await ref.read(activeTriggersProvider.notifier).confirmAllSafe();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('所有守護任務已同步確認，提醒倒數已重置！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showRestoreDialog(BuildContext context) {
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
              _performRestore(context);
            },
            child: const Text('立即還原', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerManualRestore(BuildContext context) async {
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

    _performRestore(context);
  }

  Future<void> _performRestore(BuildContext context) async {
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
    
    // 加入 12 秒連線超時機制
    final cloudTriggers = await syncService.restoreCloudTriggers().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint('TIMEOUT: restoreCloudTriggers timed out.');
        return null;
      },
    );

    if (context.mounted) {
      Navigator.pop(context); // 關閉 loading
    }

    if (cloudTriggers == null) {
      _showResultDialog(context, '還原失敗', '讀取超時或連線失敗。請確認您的網路連線，或稍後再試。');
      return;
    }

    if (cloudTriggers.isEmpty) {
      _showResultDialog(context, '無雲端資料', '目前沒有可還原的雲端守護紀錄。');
      return;
    }

    // 顯示雲端 Trigger 列表供使用者選擇
    _showSelectTriggersDialog(context, cloudTriggers);
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
      BuildContext context, List<Map<String, dynamic>> cloudTriggers) {
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


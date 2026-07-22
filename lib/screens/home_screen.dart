import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';
import '../models/trigger.dart';
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
        child: hasActive
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: TriggerListView(activeTriggers: activeTriggers),
              )
            : const BrandIntroView(),
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


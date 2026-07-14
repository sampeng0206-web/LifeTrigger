import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';
import '../models/trigger.dart';
import '../widgets/countdown_display.dart';

final activeTriggersProvider = StateNotifierProvider<ActiveTriggersNotifier, List<Trigger>>((ref) {
  return ActiveTriggersNotifier(ref.read(storageServiceProvider));
});

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

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

    // Calculate deadline if active
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
              // Open dummy settings placeholder
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text('本服務設定', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    '設定與說明功能排在 W6 實作，目前為預留位置。',
                    style: TextStyle(color: Colors.grey),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
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
              // 1. Top status text
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
                    hasActive ? '安心交代通知已啟用' : '目前尚未安排任何交代通知',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),

              // 2. Center countdown display
              if (hasActive && deadline != null)
                CountdownDisplay(deadline: deadline)
              else
                const SizedBox(height: 100),

              // 3. Huge main button
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
        await ref.read(activeTriggersProvider.notifier).confirmSafe(trigger.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已確認您的狀態，防呆警告通知已重置！'),
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

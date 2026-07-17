import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trigger.dart';
import '../services/storage_service.dart';
import '../screens/home_screen.dart';

class TriggerCard extends ConsumerStatefulWidget {
  final Trigger trigger;

  const TriggerCard({
    super.key,
    required this.trigger,
  });

  @override
  ConsumerState<TriggerCard> createState() => _TriggerCardState();
}

class _TriggerCardState extends ConsumerState<TriggerCard> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateRemaining();
    });
  }

  @override
  void didUpdateWidget(covariant TriggerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRemaining();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    if (!mounted) return;
    
    DateTime? deadline;
    if (widget.trigger.mode == TriggerMode.scheduledDate) {
      deadline = widget.trigger.scheduledDeadline;
    } else if (widget.trigger.intervalDuration != null) {
      deadline = widget.trigger.lastConfirmedAt.add(widget.trigger.intervalDuration!);
    }

    if (deadline == null) {
      setState(() {
        _remaining = Duration.zero;
      });
      return;
    }

    setState(() {
      _remaining = deadline!.difference(DateTime.now());
      if (_remaining.isNegative) {
        _remaining = Duration.zero;
      }
    });
  }

  void _handleCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '取消確認',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '確定要取消這個安心守護任務嗎？取消後將不再寄送通知。',
          style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '確定取消',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = ref.read(storageServiceProvider);
      
      final oldQuota = storage.getUserQuota().freeTriggersRemaining;
      await storage.cancelTrigger(widget.trigger.id);
      
      // 重新整理首頁清單
      ref.read(activeTriggersProvider.notifier).refresh();
      
      final newQuota = storage.getUserQuota().freeTriggersRemaining;
      final refunded = newQuota > oldQuota;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(refunded
                ? '已取消任務，並已退還 1 次免費額度。'
                : '已取消該安心守護任務！'),
            backgroundColor: refunded ? Colors.green[700] : Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    
    // Look up recipient names
    final recipientNames = widget.trigger.recipientIds
        .map((id) => storage.getRecipient(id)?.name ?? '未知收件人')
        .join(', ');

    final isReminderSent = widget.trigger.status == TriggerStatus.reminderSent;
    
    // Guardian color shades configuration
    final cardBgColor = isReminderSent ? const Color(0xFF121B2B) : const Color(0xFF111E16);
    final borderColor = isReminderSent ? Colors.blueAccent.withOpacity(0.5) : Colors.greenAccent.withOpacity(0.4);
    final statusColor = isReminderSent ? Colors.blueAccent[200]! : Colors.greenAccent[400]!;
    final statusText = isReminderSent ? '提醒已發送' : '守護中';
    final iconData = isReminderSent ? Icons.notifications_active_outlined : Icons.shield_outlined;

    // Remaining time label formatting
    String timeLabel;
    if (_remaining == Duration.zero) {
      timeLabel = '待確認';
    } else {
      final days = _remaining.inDays;
      final hours = _remaining.inHours % 24;
      final minutes = _remaining.inMinutes % 60;
      if (days > 0) {
        timeLabel = '剩餘 $days天$hours小時';
      } else if (hours > 0) {
        timeLabel = '剩餘 $hours小時$minutes分鐘';
      } else {
        timeLabel = '剩餘 $minutes分鐘';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isReminderSent ? Colors.blueAccent.withOpacity(0.08) : Colors.greenAccent.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Status Icon with background container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isReminderSent ? Colors.blueAccent.withOpacity(0.12) : Colors.greenAccent.withOpacity(0.1),
              ),
              child: Icon(
                iconData,
                size: 28,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 16),
            
            // Detail layout
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipientNames,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Status Tag & Cancel Button
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                  onPressed: () => _handleCancel(context),
                  tooltip: '取消守護任務',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

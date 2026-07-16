import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/trigger.dart';
import '../services/storage_service.dart';
import 'trigger_card.dart';

class TriggerListView extends ConsumerWidget {
  final List<Trigger> activeTriggers;

  const TriggerListView({
    super.key,
    required this.activeTriggers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title block
        const Padding(
          padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(
            '守護中',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Text(
          '安心守護中，守護通知已啟用',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 24),
        
        // Scrollable card list
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: activeTriggers.length + 1, // Add 1 for the "+ 新增任務" button card at the end
            itemBuilder: (context, index) {
              if (index < activeTriggers.length) {
                return TriggerCard(trigger: activeTriggers[index]);
              } else {
                return _buildAddTriggerCard(context, ref);
              }
            },
          ),
        ),
        const SizedBox(height: 80), // Reserve space for the floating presence button
      ],
    );
  }

  Widget _buildAddTriggerCard(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () {
          final storage = ref.read(storageServiceProvider);
          final quota = storage.getUserQuota();
          final hasQuota = quota.freeTriggersRemaining > 0 ||
              quota.isLocalUnlimited ||
              quota.isCloudGuardianActive;

          if (!hasQuota) {
            context.push('/purchase');
          } else {
            context.push('/create');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[800]!,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 8),
              Text(
                '＋ 新增任務',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

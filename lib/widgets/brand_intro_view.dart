import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';

class BrandIntroView extends ConsumerWidget {
  const BrandIntroView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon header with glowing effect
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.2),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 48,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 32),
            
            // Title
            const Text(
              '有些話不說會遺憾',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Card containing the body copy
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey[800]!.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: const Text(
                '「萬一哪天我聯絡不上你，不一定代表發生了不好的事。\n'
                '也許我只是累了、想暫時遠離圈子安靜一下，或者只是想一個人獨處。\n'
                '但有些話，不說真的會留下遺憾。\n\n'
                '讓這支App把我該說的話，在最需要的時刻，替我交給該知道的人。\n\n'
                '這可能是意外，也可能只是暫時失聯、受困、手術中——不預設任何終點，只為在我無法親自處理的時候，好好地傳達心意。」',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFCCCCCC),
                  height: 1.8,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            
            // CTA Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
                shadowColor: Colors.blueAccent.withOpacity(0.4),
              ),
              onPressed: () {
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '＋ 開始安排',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

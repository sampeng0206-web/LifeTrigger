import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';

class BrandIntroView extends ConsumerWidget {
  const BrandIntroView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFF161312), // 帶有暖色調的深碳黑背景
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon header with glowing effect matching the warm palette
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4A373).withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4A373).withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 48,
                  color: Color(0xFFD4A373),
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              const Text(
                '有些話不說會遺憾',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4A373), // 溫慢的金褐色調
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Card containing the body copy
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF231E1C).withOpacity(0.6), // 暖色調深碳褐底色
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF322A28).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: const Text(
                  '「萬一哪天我們突然失去聯絡或不再連繫，\n'
                  '不一定代表發生了不好的事。\n'
                  '也許我只是累了、\n'
                  '想暫時遠離圈子安靜一下，\n'
                  '或者只是想一個人獨處。\n\n'
                  '但有些話，不說真的會留下遺憾。\n\n'
                  '讓這支App把我該說的話，\n'
                  '在最需要的時刻，\n'
                  '替我交給該知道的人。\n\n'
                  '這可能是意外，\n'
                  '也可能只是暫時失聯、受困、手術中——\n'
                  '不預設任何終點，\n'
                  '只為在我無法親自處理的時候，\n'
                  '好好地傳達心意與交代。」',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFEAE3DB), // 稍微降低對比、帶暖調的米白色
                    height: 1.75, // 行高設為字體大小的 1.75 倍，增加閱讀呼吸感
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              
              // CTA Button (Keep blueAccent as standard App Action/Confirm Color)
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
                      '開始安排',
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
      ),
    );
  }
}

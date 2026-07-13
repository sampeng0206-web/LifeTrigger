import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_trigger/main.dart' as app;
import 'package:life_trigger/screens/lock_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W3 Full UI & Animation Integration Test', (WidgetTester tester) async {
    // 1. 啟動 App
    app.main();
    await tester.pump();
    
    print('TEST_LOG: App started. Waiting for initial screen to load...');
    
    // 等待 LockScreen 或 HomeScreen 出現
    int retry = 0;
    while (find.byType(LockScreen).evaluate().isEmpty && 
           find.text('今天一切都好嗎？').evaluate().isEmpty && 
           retry < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      retry++;
    }
    
    // 動態偵測：如果當前畫面是 LockScreen，則繞過它導航至 /home
    final lockScreenFinder = find.byType(LockScreen);
    if (lockScreenFinder.evaluate().isNotEmpty) {
      print('TEST_LOG: LockScreen detected. Bypassing to home...');
      final BuildContext context = tester.element(lockScreenFinder);
      context.go('/home');
      await tester.pumpAndSettle();
    } else {
      print('TEST_LOG: LockScreen not detected (already on home). Proceeding.');
    }
    
    // 確保 App 順利載入首頁
    expect(find.text('今天一切都好嗎？'), findsOneWidget);
    print('TEST_LOG: Home screen loaded successfully.');

    // 2. 點擊「＋ 開始安排」按鈕
    final startButton = find.text('＋ 開始安排');
    expect(startButton, findsOneWidget);
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    
    // 3. 步驟 1：我要通知誰？
    print('TEST_LOG: Step 1 loaded.');
    expect(find.text('第一步：我要通知誰？'), findsOneWidget);
    
    // 填寫姓名
    await tester.enterText(find.byKey(const Key('name_field')), '王小明');
    await tester.pumpAndSettle();
    
    // 點擊下一步
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    // 4. 步驟 2：怎麼通知？ (測試大於 7 天的防呆限制)
    print('TEST_LOG: Step 2 loaded.');
    expect(find.text('第二步：怎麼通知？'), findsOneWidget);
    
    // 填寫 Email
    await tester.enterText(find.byKey(const Key('email_field')), 'sampeng0206@gmail.com');
    
    // 填寫超過 7 天的時間間隔 (例如 180 小時 = 7.5 天)
    await tester.enterText(find.byKey(const Key('小時_field')), '180');
    await tester.pumpAndSettle();
    
    // 嘗試點擊下一步，觸發防呆對話框
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    
    // 驗證是否出現防呆對話框
    expect(find.text('安全限制提示'), findsOneWidget);
    print('TEST_SCREEN_ALERT_SHOWN'); // 觸發截圖 1
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // 點擊確定關閉彈窗
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    
    // 修改時間為 24 小時
    await tester.enterText(find.byKey(const Key('小時_field')), '24');
    await tester.pumpAndSettle();
    
    // 點擊下一步
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    // 5. 步驟 3：我想說什麼？
    print('TEST_LOG: Step 3 loaded.');
    expect(find.text('第三步：我想說什麼？'), findsOneWidget);
    
    // 填寫信件內容與共同回憶
    await tester.enterText(find.byKey(const Key('message_field')), '這是我的安心守護信件。看到這封信代表我暫時無法回覆安全確認。');
    await tester.enterText(find.byKey(const Key('shared_memory_field')), '我們在大安森林公園野餐過');
    await tester.pumpAndSettle();
    
    // 點擊下一步
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    // 6. 步驟 4：確認預覽
    print('TEST_LOG: Step 4 loaded.');
    expect(find.text('第四步：預覽並啟動守護'), findsOneWidget);
    print('TEST_SCREEN_PREVIEW_SHOWN'); // 觸發截圖 2
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // 點擊啟動安心守護
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    // 7. 回到首頁確認守護啟動
    print('TEST_LOG: Returned to home with active trigger.');
    expect(find.text('守護中'), findsOneWidget);
    print('TEST_SCREEN_HOME_ACTIVE'); // 觸發截圖 3
    await Future.delayed(const Duration(milliseconds: 1000));

    // 8. 點擊「我還在」大按鈕
    final presenceButton = find.text('我還在');
    expect(presenceButton, findsOneWidget);
    
    // 點擊按鈕，啟動信封收回動畫
    await tester.tap(presenceButton);
    // 必須先 pump，讓對話框開始出現
    await tester.pump();
    
    print('TEST_SCREEN_ANIMATION_PLAYING'); // 觸發截圖 4
    await Future.delayed(const Duration(milliseconds: 800)); // 在動畫中段等待
    
    // 繼續播放完畢
    await tester.pumpAndSettle();
    print('TEST_LOG: Reset animation finished.');
    
    // 9. 確認狀態正確重置
    expect(find.text('今天一切都好嗎？'), findsOneWidget);
    print('TEST_SCREEN_HOME_RESET'); // 觸發截圖 5
    await Future.delayed(const Duration(milliseconds: 1000));
    
    print('TEST_LOG: All tests completed successfully.');
  });
}

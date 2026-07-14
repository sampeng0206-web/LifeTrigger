import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_trigger_screen.dart';
import 'screens/purchase_screen.dart';
import 'screens/success_screen.dart';
import 'screens/help_terms_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize a container to read providers before running the app
  final container = ProviderContainer();

  // 1. Initialize Notification Service
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.init();

  // 2. Initialize Storage Service
  final storageService = container.read(storageServiceProvider);
  await storageService.init();

  // 3. Initialize RevenueCat Purchase Service
  final purchaseService = container.read(purchaseServiceProvider);
  await purchaseService.init();

  // 4. Initialize AdMob Ad Service
  final adService = container.read(adServiceProvider);
  await adService.init();

  // 5. Check for overdue triggers upon launch
  await storageService.checkOverdueTriggers();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LockScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => const CreateTriggerScreen(),
    ),
    GoRoute(
      path: '/purchase',
      builder: (context, state) => const PurchaseScreen(),
    ),
    GoRoute(
      path: '/success',
      builder: (context, state) => const SuccessScreen(),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const HelpTermsScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '萬一我消失',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[950],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

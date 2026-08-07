import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_trigger_screen.dart';
import 'screens/purchase_screen.dart';
import 'screens/success_screen.dart';
import 'screens/help_terms_screen.dart';
import 'screens/settings_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/ad_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize a container to read providers before running the app
  final container = ProviderContainer();

  // 1. Initialize Storage Service (foundation for logging/diagnostics)
  final storageService = container.read(storageServiceProvider);
  await storageService.init();

  // 2. Initialize Notification Service
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.init();

  // 3. Initialize RevenueCat Purchase Service
  final purchaseService = container.read(purchaseServiceProvider);
  await purchaseService.init();

  // 4. Initialize Firebase and Remote Config
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.setDefaults(const {
      "ad_banner_enabled": true,
      "ad_banner_image_url": "",
      "ad_banner_target_url": "mailto:sampeng0206@gmail.com",
      "ad_banner_link_type": "mailto",
    });
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    debugPrint('Firebase/RemoteConfig initialization failed: $e');
  }


  // 5. Check for overdue triggers upon launch
  try {
    await storageService.checkOverdueTriggers();
  } catch (e) {
    debugPrint('ERROR: Failed checking overdue triggers on launch: $e');
    try {
      await storageService.saveLastError('CheckOverdueTriggers Error: $e');
    } catch (_) {}
  }

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
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
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

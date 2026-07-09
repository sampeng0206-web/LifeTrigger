import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/trigger.dart';
import 'models/recipient.dart';
import 'models/user_quota.dart';
import 'services/storage_service.dart';

/// Standalone debug app to dump Hive box contents to console.
/// Run via: flutter run -t lib/debug_dump.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters
  void safe<T>(TypeAdapter<T> a) {
    if (!Hive.isAdapterRegistered(a.typeId)) Hive.registerAdapter(a);
  }

  safe(TriggerModeAdapter());
  safe(DeliveryMethodAdapter());
  safe(ImportanceAdapter());
  safe(TriggerStatusAdapter());
  safe(FailureReasonAdapter());
  safe(TriggerAdapter());
  safe(RelationshipAdapter());
  safe(RecipientAdapter());
  safe(UserQuotaAdapter());
  safe(DurationAdapter());

  final triggerBox = await Hive.openBox<Trigger>('triggers');
  final recipientBox = await Hive.openBox<Recipient>('recipients');

  debugPrint('=== HIVE DUMP START ===');
  debugPrint('--- Triggers (${triggerBox.length}) ---');
  for (final t in triggerBox.values) {
    debugPrint('  id:              ${t.id}');
    debugPrint('  mode:            ${t.mode}');
    debugPrint('  intervalDuration:${t.intervalDuration}');
    debugPrint('  message:         ${t.message}');
    debugPrint('  sharedMemory:    ${t.sharedMemoryPrompt}');
    debugPrint('  recipientIds:    ${t.recipientIds}');
    debugPrint('  status:          ${t.status}');
    debugPrint('  isActive:        ${t.isActive}');
    debugPrint('  lastConfirmedAt: ${t.lastConfirmedAt}');
    debugPrint('  ---');
  }
  debugPrint('--- Recipients (${recipientBox.length}) ---');
  for (final r in recipientBox.values) {
    debugPrint('  id:           ${r.id}');
    debugPrint('  name:         ${r.name}');
    debugPrint('  email:        ${r.email}');
    debugPrint('  relationship: ${r.relationship}');
    debugPrint('  ---');
  }
  debugPrint('=== HIVE DUMP END ===');

  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Hive dump complete – check logs')))));
}

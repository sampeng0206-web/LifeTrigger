import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'storage_service.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref);
});

class PurchaseService {
  final Ref _ref;
  bool _isInitialized = false;

  // ============================================================================
  // RevenueCat Public API Key 常數 (常態版控，供使用者在編輯器中修改)
  // ============================================================================
  static const String publicApiKey = 'appl_effyfdKsGHqFTeTCLxZahhrlTqe';

  PurchaseService(this._ref);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      
      PurchasesConfiguration configuration;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        configuration = PurchasesConfiguration(publicApiKey);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        configuration = PurchasesConfiguration(publicApiKey);
      } else {
        return;
      }
      
      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint('LOG: RevenueCat SDK Initialized successfully');
      
      // 啟動時即同步檢查一次本地與線上狀態
      await checkEntitlements();
    } catch (e) {
      debugPrint('ERROR: Failed to initialize RevenueCat: $e');
    }
  }

  Future<Offerings?> fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('LOG: Fetched offerings successfully: ${offerings.current}');
      if (offerings.current != null) {
        for (var p in offerings.current!.availablePackages) {
          debugPrint('LOG: [RevenueCat Package Details] Identifier: ${p.identifier}, StoreProduct: ${p.storeProduct.identifier}, Price: ${p.storeProduct.priceString}');
        }
      }
      return offerings;
    } catch (e) {
      debugPrint('ERROR: Failed to fetch offerings: $e');
      return null;
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      await _updateEntitlements(customerInfo);
      return true;
    } catch (e) {
      debugPrint('ERROR: Failed to purchase package: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      await _updateEntitlements(customerInfo);
      return true;
    } catch (e) {
      debugPrint('ERROR: Failed to restore purchases: $e');
      return false;
    }
  }

  Future<void> checkEntitlements() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Purchases.getCustomerInfo timed out.');
        },
      );
      await _updateEntitlements(customerInfo);
    } catch (e) {
      debugPrint('ERROR: Failed to check entitlements: $e');
      // 離線或連線失敗時，不覆蓋本地已儲存的狀態，維持使用 Hive 快取
    }
  }

  Future<void> _updateEntitlements(CustomerInfo customerInfo) async {
    final localUnlimitedActive = customerInfo.entitlements.all['local_unlimited']?.isActive ?? false;
    final cloudGuardianActive = customerInfo.entitlements.all['cloud_guardian']?.isActive ?? false;

    debugPrint('LOG: Entitlements updated -> local_unlimited: $localUnlimitedActive, cloud_guardian: $cloudGuardianActive');

    final storage = _ref.read(storageServiceProvider);
    final quota = storage.getUserQuota();
    
    // 忠實反映線上 RevenueCat Entitlement 授權狀態：線上為 true 寫入 true，過期/取消為 false 則寫入 false
    quota.isLocalUnlimited = localUnlimitedActive;
    quota.isCloudGuardianActive = cloudGuardianActive;

    await storage.saveUserQuota(quota);
  }
}

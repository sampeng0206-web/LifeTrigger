import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'storage_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService(ref);
});

class AdService {
  final Ref _ref;
  bool _isInitialized = false;

  // ============================================================================
  // AdMob 廣告單元 ID (Banner Unit ID)
  // ============================================================================
  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3755777658581400/3591225793';
    } else {
      // Android版尚未在AdMob後台建立正式App，此為官方測試ID，待未來Android版上線並於AdMob後台建立對應App後再替換
      return 'ca-app-pub-3940256099942544/6300978111';
    }
  }

  AdService(this._ref);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('LOG: AdMob SDK Initialized successfully');
    } catch (e) {
      debugPrint('ERROR: Failed to initialize AdMob: $e');
    }
  }

  /// 判斷使用者是否應顯示廣告（非付費安心版/守護版用戶）
  bool shouldShowAds() {
    final storage = _ref.read(storageServiceProvider);
    final quota = storage.getUserQuota();
    final isPaid = quota.isLocalUnlimited || quota.isCloudGuardianActive;
    return !isPaid;
  }

  /// 建立並載入 BannerAd。如果已購買解鎖，則直接回傳 null 不進行載入。
  BannerAd? createBannerAd({
    required VoidCallback onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    if (!shouldShowAds()) {
      debugPrint('LOG: User is paid, skipping AdMob loading.');
      return null;
    }

    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(
        nonPersonalizedAds: true, // 明確指定：非個人化廣告
      ),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('LOG: Banner ad loaded successfully.');
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('ERROR: Banner ad failed to load: $error');
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    )..load();
  }
}

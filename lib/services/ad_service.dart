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

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  VoidCallback? _onInterstitialAdClosedAction;

  // ============================================================================
  // AdMob 廣告單元 ID (Banner Unit ID)
  // ============================================================================
  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3755777658581400/3591225793';
    } else {
      return 'ca-app-pub-3755777658581400/3798751531';
    }
  }

  // ============================================================================
  // AdMob 廣告單元 ID (Interstitial Unit ID)
  // ============================================================================
  static String get interstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // 目前 iOS 暫無正式 Interstitial ID，回傳測試 ID
      return 'ca-app-pub-3940256099942544/4411468910';
    } else {
      return 'ca-app-pub-3755777658581400/9714523279';
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

  /// 預先載入插頁式廣告（不論是否已購買皆可安全載入，但應由調用端判斷是否付費）
  void loadInterstitialAd() {
    if (!shouldShowAds()) {
      debugPrint('LOG: User is paid, skipping Interstitial Ad loading.');
      return;
    }
    if (_interstitialAd != null || _isInterstitialAdLoading) return;

    _isInterstitialAdLoading = true;
    debugPrint('LOG: Start loading Interstitial Ad...');
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(
        nonPersonalizedAds: true, // 明確指定：非個人化廣告
      ),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('LOG: Interstitial Ad loaded successfully.');
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          _setupInterstitialCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('ERROR: Interstitial Ad failed to load: $error');
          _interstitialAd = null;
          _isInterstitialAdLoading = false;
        },
      ),
    );
  }

  void _setupInterstitialCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('LOG: Interstitial Ad showed full screen.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('LOG: Interstitial Ad dismissed by user.');
        ad.dispose();
        _interstitialAd = null;
        _onInterstitialAdClosedAction?.call();
        _onInterstitialAdClosedAction = null;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('ERROR: Interstitial Ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        _onInterstitialAdClosedAction?.call();
        _onInterstitialAdClosedAction = null;
      },
    );
  }

  /// 顯示插頁式廣告，如果未載入完成或使用者已購買付費方案，則直接執行回呼動作
  void showInterstitialAd({required VoidCallback onAdClosed}) {
    if (!shouldShowAds()) {
      debugPrint('LOG: User is paid, skipping Interstitial Ad show.');
      onAdClosed();
      return;
    }

    if (_interstitialAd != null) {
      _onInterstitialAdClosedAction = onAdClosed;
      _interstitialAd!.show();
    } else {
      debugPrint('LOG: Interstitial Ad not ready, skipping.');
      onAdClosed();
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

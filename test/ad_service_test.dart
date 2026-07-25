import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_trigger/services/ad_service.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('AdService production Banner Ad Unit ID check for iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AdService.bannerAdUnitId, equals('ca-app-pub-3755777658581400/3591225793'));
  });

  test('AdService production Banner Ad Unit ID check for Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AdService.bannerAdUnitId, equals('ca-app-pub-3755777658581400/3798751531'));
  });

  test('AdService production Interstitial Ad Unit ID check for Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AdService.interstitialAdUnitId, equals('ca-app-pub-3755777658581400/9714523279'));
  });
}

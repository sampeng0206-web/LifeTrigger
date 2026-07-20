import 'package:flutter_test/flutter_test.dart';
import 'package:life_trigger/services/ad_service.dart';

void main() {
  test('AdService production Banner Ad Unit ID check', () {
    final adUnitId = AdService.bannerAdUnitId;
    expect(adUnitId, equals('ca-app-pub-3755777658581400/3591225793'));
  });
}

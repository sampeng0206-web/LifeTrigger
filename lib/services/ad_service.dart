import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService(ref);
});

class AdService {
  final Ref _ref;

  AdService(this._ref);

  /// 判斷使用者是否應顯示廣告（非付費安心版/守護版用戶）
  bool shouldShowAds() {
    final storage = _ref.read(storageServiceProvider);
    final quota = storage.getUserQuota();
    final isPaid = quota.isLocalUnlimited || quota.isCloudGuardianActive;
    return !isPaid;
  }
}

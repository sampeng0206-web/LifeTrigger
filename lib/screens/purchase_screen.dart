import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/purchase_service.dart';
import '../services/storage_service.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  bool _isLoading = false;
  Offerings? _offerings;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final purchaseService = ref.read(purchaseServiceProvider);
    final offerings = await purchaseService.fetchOfferings();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (offerings == null || offerings.current == null) {
          _errorMessage = '無法載入方案資訊，請檢查網路連線。';
        } else {
          _offerings = offerings;
        }
      });
    }
  }

  Future<void> _buyPackage(Package package) async {
    setState(() {
      _isLoading = true;
    });

    final success = await ref.read(purchaseServiceProvider).purchasePackage(package);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('感謝您的支持，方案已成功啟用！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('購買失敗，請稍後再試。'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isLoading = true;
    });

    final success = await ref.read(purchaseServiceProvider).restorePurchases();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('購買紀錄已成功恢復！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('恢復失敗，未找到相關購買紀錄。'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  // 模擬開發模式下的本地快速開通
  Future<void> _simulatePurchase(String entitlementId) async {
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 600));

    final storage = ref.read(storageServiceProvider);
    final quota = storage.getUserQuota();

    if (entitlementId == 'local_unlimited') {
      quota.isLocalUnlimited = true;
    } else if (entitlementId == 'cloud_guardian') {
      quota.isCloudGuardianActive = true;
    }
    await storage.saveUserQuota(quota);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('【模擬測試】已成功開通 $entitlementId 權限！'),
          backgroundColor: Colors.blueAccent,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 取得當前 RevenueCat 的 packages（以自訂的 $rc_lifetime 與 $rc_annual ID 為主）
    final currentOffering = _offerings?.current;
    Package? lifetimePackage;
    Package? annualPackage;
    if (currentOffering != null) {
      for (var package in currentOffering.availablePackages) {
        if (package.identifier == '\$rc_lifetime') {
          lifetimePackage = package;
        } else if (package.identifier == '\$rc_annual') {
          annualPackage = package;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('安全守護方案升級', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const Text(
                  '選擇適合您的安心配置，保護最在乎的人',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 30),
                
                // 方案 1: 安心版 (買斷)
                _buildPlanCard(
                  title: '安心版（本機解鎖）',
                  price: lifetimePackage?.storeProduct.priceString ?? 'NT\$ 190',
                  subtitle: '一次性付費・永久買斷',
                  description: '解鎖本機端無限次安心守護排程。防呆確認時間最長支援 7 天，無廣告打擾。',
                  color: Colors.blueAccent,
                  isSubscription: false,
                  onPressed: () {
                    if (lifetimePackage != null) {
                      _buyPackage(lifetimePackage);
                    } else if (kDebugMode) {
                      _simulatePurchase('local_unlimited');
                    }
                  },
                ),
                const SizedBox(height: 20),

                // 方案 2: 守護版 (年費訂閱)
                _buildPlanCard(
                  title: '守護版（雲端備份年訂閱）',
                  price: annualPackage?.storeProduct.priceString ?? 'NT\$ 990 / 年',
                  subtitle: '自動續訂・雲端安心防護',
                  description: '解鎖無限次安心守護排程（最高支援 365 天間隔）。包含安全雲端備份服務與自動化健康檢查，無廣告打擾。',
                  color: Colors.teal,
                  isSubscription: true,
                  onPressed: () {
                    if (annualPackage != null) {
                      _buyPackage(annualPackage);
                    } else if (kDebugMode) {
                      _simulatePurchase('cloud_guardian');
                    }
                  },
                ),
                const SizedBox(height: 30),

                if (_errorMessage != null && !kDebugMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 恢復購買按鈕
                OutlinedButton(
                  onPressed: _isLoading ? null : _restore,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    side: BorderSide(color: Colors.grey[800]!),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('恢復購買項目', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(height: 20),
                const Text(
                  '本購買項目皆經由您的 Apple ID 付費與管理。買斷型商品於購買完成後立即永久生效；訂閱型商品將每年自動續訂，您可隨時於 App Store 帳號設定中取消。',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String subtitle,
    required String description,
    required Color color,
    required bool isSubscription,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[900]!, const Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              if (isSubscription)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '推薦',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            price,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: color),
          ),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 15),
          Text(
            description,
            style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('立即升級方案', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class HelpTermsScreen extends ConsumerStatefulWidget {
  const HelpTermsScreen({super.key});

  @override
  ConsumerState<HelpTermsScreen> createState() => _HelpTermsScreenState();
}

class _HelpTermsScreenState extends ConsumerState<HelpTermsScreen> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final adService = ref.read(adServiceProvider);
    _bannerAd = adService.createBannerAd(
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用說明與條款', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('1. 本 App 核心功能說明'),
                    _buildParagraph(
                      '本服務為一本地安心守護排程系統，旨在協助使用者在特定時間間隔內進行安全確認。'
                      '當您設定了守護排程，必須定期打開 App 點擊「我還在」以完成安全重置。'
                      '若在時間截止前未收到您的重置，系統將會向您預設的聯絡人發送通知信件。'
                    ),
                    const SizedBox(height: 20),
                    
                    _buildSectionTitle('2. 防呆天期與服務'),
                    _buildParagraph(
                      '・安心版（本機解鎖）：支援 1 小時至 7 天的防呆確認時間間隔。所有邏輯及通知在本地處理，免去廣告打擾。\n'
                      '・守護版（備份年訂閱）：支援最高 365 天防呆確認時間間隔。配備自動化狀態檢查與安全備份。'
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('3. 服務限制與免責條款'),
                    _buildParagraph(
                      '・本地通知與排程在部分作業系統背景限制下（例如強制關閉 App），其執行頻率可能會受到系統控制影響。\n'
                      '・本服務非即時救援或生命警報系統，通知信件傳遞可能受網路環境、收件伺服器判斷等不可抗力因素影響，本 App 不對通知發送之延誤或失敗承擔法律責任。'
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('4. 隱私權與資料保護'),
                    _buildParagraph(
                      '您的所有守護訊息、收件人資料與共同記憶皆加密儲存於本地資料庫中，本公司不會在未經授權下調閱您的隱私交代。守護版本僅在您主動啟用並驗證後，方對部分資料進行加密傳輸。'
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            
            // 廣告區塊（僅限免費方案且載入廣告時，放置於最底部）
            if (_bannerAd != null)
              Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: _bannerAd!.size.height.toDouble(),
                color: Colors.grey[950],
                child: _isAdLoaded
                    ? AdWidget(ad: _bannerAd!)
                    : Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: const Text(
                          '載入廣告中...',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildParagraph(String content) {
    return Text(
      content,
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[350],
        height: 1.6,
      ),
    );
  }
}

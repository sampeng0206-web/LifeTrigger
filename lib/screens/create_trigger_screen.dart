import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../services/purchase_service.dart';
import '../models/trigger.dart';
import '../models/recipient.dart';
import 'home_screen.dart';
import 'purchase_screen.dart';

class CreateTriggerScreen extends ConsumerStatefulWidget {
  const CreateTriggerScreen({super.key});

  @override
  ConsumerState<CreateTriggerScreen> createState() => _CreateTriggerScreenState();
}

class _CreateTriggerScreenState extends ConsumerState<CreateTriggerScreen> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  final _pageController = PageController();
  int _currentStep = 0;

  // Time setting state (default 24 hours)
  int _selectedHours = 24;
  int _selectedMinutes = 0;
  int _activeTab = 0; // 0: 短期安排, 1: 長期守護
  bool _isSubmitting = false; // 防重複點擊鎖定旗標

  // Recipient state
  final _recipientNameController = TextEditingController();
  final _recipientEmailController = TextEditingController();
  final _backupEmailController = TextEditingController();
  Relationship _selectedRelationship = Relationship.family;

  // Message and Shared memory
  final _messageController = TextEditingController();
  final _sharedMemoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // 載入並同步通知副本 Email 至設定資料庫
    final storage = ref.read(storageServiceProvider);
    _backupEmailController.text = storage.getUserEmail() ?? '';
    _backupEmailController.addListener(() {
      storage.saveUserEmail(_backupEmailController.text.trim());
    });

    // 異步背景重新整理 entitlements 訂閱狀態，確保方案資訊最新
    ref.read(purchaseServiceProvider).checkEntitlements().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _recipientNameController.dispose();
    _recipientEmailController.dispose();
    _backupEmailController.dispose();
    _messageController.dispose();
    _sharedMemoryController.dispose();
    super.dispose();
  }

  void _applyQuickTime(int hours) {
    setState(() {
      _selectedHours = hours;
      _selectedMinutes = 0;
    });
  }

  Duration _getSelectedDuration() {
    return Duration(hours: _selectedHours, minutes: _selectedMinutes);
  }

  Future<void> _onNextPressed() async {
    if (_currentStep == 0) {
      if (_formKey1.currentState!.validate()) {
        _nextPage();
      }
    } else if (_currentStep == 1) {
      if (_formKey2.currentState!.validate()) {
        final duration = _getSelectedDuration();
        if (duration < const Duration(minutes: 5)) {
          _showErrorDialog('確認時間間隔不得低於 5 分鐘，這是出於安全考量的基本限制。');
          return;
        }

        // 呼叫 checkEntitlements() 同步最新狀態
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          await ref.read(purchaseServiceProvider).checkEntitlements();
        } catch (e) {
          debugPrint('Error checking entitlements: $e');
        } finally {
          if (mounted) {
            Navigator.pop(context); // 關閉 Loading
          }
        }

        final quota = ref.read(storageServiceProvider).getUserQuota();
        final hasCloudGuardian = quota.isCloudGuardianActive;

        if (_activeTab == 1 && !hasCloudGuardian) {
          _showErrorDialog('使用「長期守護」必須啟用守護版權限。');
          return;
        }

        if (_activeTab == 1) {
          if (duration > const Duration(days: 365)) {
            _showErrorDialog('長期守護自訂時間最長不得超過 365 天。');
            return;
          }
        } else {
          if (duration > const Duration(days: 7)) {
            _showErrorDialog('短期安排自訂時間最長不得超過 7 天。');
            return;
          }
        }

        // 當設定時間低於 30 分鐘時彈出警語確認
        if (duration < const Duration(minutes: 30)) {
          final confirmProceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('安全限制確認', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                '此時間相當短，若您在期間內因故無法重新開啟App確認，通知仍可能無法即時送達，請確保您了解此為盡力服務，不保證所有情境下都能即時完成通知。',
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('返回修改', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('我瞭解並確認', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );

          if (confirmProceed != true) return;
        }

        _nextPage();
      }
    } else if (_currentStep == 2) {
      if (_formKey3.currentState!.validate()) {
        _nextPage();
      }
    } else if (_currentStep == 3) {
      _save();
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentStep++;
    });
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentStep--;
    });
  }

  Future<void> _save() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final duration = _getSelectedDuration();
      final storage = ref.read(storageServiceProvider);

      // 0. 保存並鎖定通知副本 Email
      final backupEmail = _backupEmailController.text.trim();
      if (backupEmail.isNotEmpty) {
        await storage.saveUserEmail(backupEmail);
      }

      // 1. Create Recipient
      final recipient = Recipient(
        id: const Uuid().v4(),
        name: _recipientNameController.text.trim(),
        email: _recipientEmailController.text.trim(),
        relationship: _selectedRelationship,
      );

      await storage.saveRecipient(recipient);

      // 2. Create Trigger
      final result = await storage.createNewTrigger(
        mode: TriggerMode.quick,
        intervalDuration: duration,
        autoRenewOnConfirm: true, // 預設為循環確認模式
        recipientIds: [recipient.id],
        message: _messageController.text.trim(),
        sharedMemoryPrompt: _sharedMemoryController.text.trim(),
        userEmail: backupEmail.isNotEmpty ? backupEmail : null,
      );

      if (result.status == CreateTriggerStatus.quotaExceeded) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('額度已達上限', style: TextStyle(color: Colors.white)),
              content: const Text(
                '免費體驗版僅支援 1 次免費安排。若要啟用更多，請升級為安心版（買斷）或守護版（訂閱）。',
                style: TextStyle(color: Colors.grey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/purchase');
                  },
                  child: const Text('去升級', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else if (result.status == CreateTriggerStatus.cloudSyncFailed) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('雲端同步失敗', style: TextStyle(color: Colors.white)),
              content: const Text(
                '無法將此守護上傳至雲端伺服器，請檢查您的網路連線後重試。',
                style: TextStyle(color: Colors.grey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('確定', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        // 成功，重整 triggers 並導向成功畫面
        ref.read(activeTriggersProvider.notifier).refresh();
        if (mounted) {
          context.go('/success');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('安全限制提示', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[950],
      appBar: AppBar(
        title: const Text('安排安心守護', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // 只能透過按鈕滑動
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                ],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(4, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.blueAccent
                        : isCurrent
                            ? Colors.blueAccent.withOpacity(0.2)
                            : Colors.grey[900],
                    border: Border.all(
                      color: isCompleted || isCurrent
                          ? Colors.blueAccent
                          : Colors.grey[800]!,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent ? Colors.blueAccent : Colors.grey[500],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                if (index < 3)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: index < _currentStep ? Colors.blueAccent : Colors.grey[800],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[800]!),
                ),
              ),
              onPressed: _previousPage,
              child: const Text('上一步', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox(),
          Builder(
            builder: (context) {
              final quota = ref.watch(storageServiceProvider).getUserQuota();
              final isNextDisabled = (_currentStep == 1 && _activeTab == 1 && !quota.isCloudGuardianActive) || _isSubmitting;

              return ElevatedButton(
                key: const Key('next_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isNextDisabled
                      ? Colors.grey[800]
                      : (_currentStep == 3 ? Colors.greenAccent[700] : Colors.blueAccent),
                  foregroundColor: isNextDisabled ? Colors.grey[500] : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isNextDisabled ? 0 : 4,
                ),
                onPressed: isNextDisabled ? null : _onNextPressed,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _currentStep == 3 ? '啟動安心守護' : '下一步',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 第 1 步：我要通知誰？
  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '第一步：我要通知誰？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '請設定當您長時間未回報安全時，系統要發送通知信件的聯絡人資訊。',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('name_field'),
              controller: _recipientNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('聯絡人姓名'),
              validator: (val) => (val == null || val.trim().isEmpty) ? '請輸入聯絡人姓名' : null,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<Relationship>(
              key: const Key('relationship_dropdown'),
              value: _selectedRelationship,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('與聯絡人的關係'),
              items: Relationship.values.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(_getRelationshipText(r)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRelationship = val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 第 2 步：怎麼通知？
  Widget _buildStep2() {
    final storage = ref.read(storageServiceProvider);
    final quota = storage.getUserQuota();
    
    String schemeLabel = '';
    Color schemeColor = Colors.grey;
    if (quota.isCloudGuardianActive) {
      schemeLabel = '目前方案：守護版（雲端守護，無限次建立）';
      schemeColor = Colors.tealAccent[400]!;
    } else if (quota.isLocalUnlimited) {
      schemeLabel = '目前方案：安心版（本機解鎖，無限次建立）';
      schemeColor = Colors.blueAccent[200]!;
    } else {
      schemeLabel = '目前方案：免費體驗版（剩餘 ${quota.freeTriggersRemaining}/1 次建立額度）';
      schemeColor = Colors.amberAccent[200]!;
    }

    return Form(
      key: _formKey2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 方案狀態標籤
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: schemeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: schemeColor.withOpacity(0.3), width: 1),
              ),
              child: Text(
                schemeLabel,
                style: TextStyle(
                  color: schemeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Text(
              '第二步：怎麼通知？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '請設定聯絡人的電子信箱，以及系統確認您的安全狀態的時間間隔。',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('email_field'),
              controller: _recipientEmailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: _buildInputDecoration('聯絡人 Email'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return '請輸入聯絡人 Email';
                if (!val.contains('@')) return '請輸入正確的 Email 格式';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('backup_email_field'),
              controller: _backupEmailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: _buildInputDecoration('通知副本 Email (選填)'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return null; // 選填
                if (!val.contains('@')) return '請輸入正確的 Email 格式';
                return null;
              },
            ),
            const SizedBox(height: 28),
            const Text(
              '確認安全狀態時間間隔',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            // 分頁籤
            Row(
              children: [
                Expanded(
                  child: _buildTabButton('短期安排', 0),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('長期守護', 1),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 依分頁籤與權限顯示內容
            if (_activeTab == 0) ...[
              // 短期安排內容
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickTimeButton('24 小時', 24),
                  _buildQuickTimeButton('72 小時', 72),
                  _buildQuickTimeButton('7 天', 168),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInputField(
                      label: '小時',
                      value: _selectedHours,
                      onChanged: (val) => setState(() => _selectedHours = val ?? 0),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeInputField(
                      label: '分鐘',
                      value: _selectedMinutes,
                      onChanged: (val) => setState(() => _selectedMinutes = val ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '※ 短期安排支援最長 7 天（168 小時），下限 5 分鐘。',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ] else ...[
              // 長期守護分頁
              if (quota.isCloudGuardianActive) ...[
                // 已訂閱，可直接使用
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickTimeButton('7 天', 168),
                    _buildQuickTimeButton('30 天', 720),
                    _buildQuickTimeButton('90 天', 2160),
                    _buildQuickTimeButton('365 天', 8760),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeInputField(
                        label: '小時',
                        value: _selectedHours,
                        onChanged: (val) => setState(() => _selectedHours = val ?? 0),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeInputField(
                        label: '分鐘',
                        value: _selectedMinutes,
                        onChanged: (val) => setState(() => _selectedMinutes = val ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '※ 長期守護支援最長 365 天（8760 小時），下限 5 分鐘。',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ] else ...[
                // 未訂閱，顯示方案差異比較卡片
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111E2E), // 深藍底色
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.cloud_queue_outlined, color: Colors.tealAccent, size: 22),
                          SizedBox(width: 8),
                          Text(
                            '「長期守護」專屬服務差異',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildComparisonRow('守護天期', '最長 7 天', '最長 365 天'),
                      const Divider(color: Colors.grey, height: 20, thickness: 0.5),
                      _buildComparisonRow('保管方式', '手機本地資料', '雲端安全備份'),
                      const Divider(color: Colors.grey, height: 20, thickness: 0.5),
                      _buildComparisonRow('手機損毀', '無法發送通知', '雲端排程自動送達'),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PurchaseScreen()),
                            );
                            // 返回後重新整理 entitlements 狀態
                            setState(() {});
                          },
                          child: const Text('立即開通守護版', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // 第 3 步：我想說什麼？
  Widget _buildStep3() {
    return Form(
      key: _formKey3,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '第三步：我想說什麼？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '請輸入您預先配置的通知信件內容，以及兩人才知道的共同記憶。',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('message_field'),
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              maxLength: 300,
              decoration: _buildInputDecoration('請輸入預置通知信件內容（限 300 字）'),
              validator: (val) => (val == null || val.trim().isEmpty) ? '請輸入通知信件內容' : null,
            ),
            const SizedBox(height: 20),
            const Text(
              '共同回憶（身分識別暗語）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '填寫「你」與「這位收件人」之間只有兩人才知道的一件事（例如某段共同經歷）。這段文字會出現在確認信件的最上方，讓收件人立刻確認這是您本人親自設定的。',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('shared_memory_field'),
              controller: _sharedMemoryController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('例如：我們第一次出遊去了哪裡？'),
              validator: (val) => (val == null || val.trim().isEmpty) ? '請填寫共同回憶' : null,
            ),
          ],
        ),
      ),
    );
  }

  // 第 4 步：確認預覽
  Widget _buildStep4() {
    final storage = ref.watch(storageServiceProvider);
    final quota = storage.getUserQuota();

    String quotaText = '免費額度剩餘 ${quota.freeTriggersRemaining} 次';
    if (quota.isLocalUnlimited || quota.isCloudGuardianActive) {
      quotaText = '無限次';
    }

    final duration = _getSelectedDuration();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '第四步：預覽並啟動守護',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '請確認以下資訊正確無誤。啟動後，防呆計時器將開始運作。',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          _buildPreviewContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreviewRow('聯絡對象', '${_recipientNameController.text} (${_getRelationshipText(_selectedRelationship)})'),
                const Divider(color: Colors.grey, height: 24),
                _buildPreviewRow('通知 Email', _recipientEmailController.text),
                const Divider(color: Colors.grey, height: 24),
                _buildPreviewRow('安全確認間隔', '$hours 小時 $minutes 分鐘'),
                const Divider(color: Colors.grey, height: 24),
                _buildPreviewRow('共同回憶暗語', _sharedMemoryController.text),
                const Divider(color: Colors.grey, height: 24),
                const Text('預置信件內容：', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  _messageController.text,
                  style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              quotaText,
              style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: child,
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTimeButton(String text, int hours) {
    final isSelected = _selectedHours == hours && _selectedMinutes == 0;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blueAccent : Colors.grey[900],
        foregroundColor: isSelected ? Colors.white : Colors.grey[300],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.blueAccent : Colors.grey[700]!,
            width: 1,
          ),
        ),
      ),
      onPressed: () => _applyQuickTime(hours),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTimeInputField({
    required String label,
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    return TextFormField(
      key: Key('${label}_field'),
      initialValue: value.toString(),
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: _buildInputDecoration(label),
      onChanged: (val) => onChanged(int.tryParse(val)),
      validator: (val) {
        final parsed = int.tryParse(val ?? '');
        if (parsed == null) return '請輸入數字';
        if (parsed < 0) return '不能低於 0';
        return null;
      },
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blueAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey[900]?.withOpacity(0.5),
    );
  }

  String _getRelationshipText(Relationship r) {
    switch (r) {
      case Relationship.family:
        return '家人';
      case Relationship.spouse:
        return '配偶';
      case Relationship.friend:
        return '朋友';
      case Relationship.lawyer:
        return '律師';
      case Relationship.colleague:
        return '同事';
      case Relationship.other:
        return '其他';
    }
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = index;
          if (index == 0) {
            _selectedHours = 24;
            _selectedMinutes = 0;
          } else {
            _selectedHours = 720; // 30天 (720 小時)
            _selectedMinutes = 0;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey[800]!,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String feature, String localVal, String cloudVal) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            feature,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            '安心版: $localVal',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            '守護版: $cloudVal',
            style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

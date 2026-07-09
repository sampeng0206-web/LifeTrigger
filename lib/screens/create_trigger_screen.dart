import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../models/trigger.dart';
import '../models/recipient.dart';
import 'home_screen.dart';

class CreateTriggerScreen extends ConsumerStatefulWidget {
  const CreateTriggerScreen({super.key});

  @override
  ConsumerState<CreateTriggerScreen> createState() => _CreateTriggerScreenState();
}

class _CreateTriggerScreenState extends ConsumerState<CreateTriggerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Time setting state (default 24 hours)
  int _selectedHours = 24;
  int _selectedMinutes = 0;

  // Recipient state
  final _recipientNameController = TextEditingController();
  final _recipientEmailController = TextEditingController();
  Relationship _selectedRelationship = Relationship.family;

  // Message and Shared memory
  final _messageController = TextEditingController();
  final _sharedMemoryController = TextEditingController();

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientEmailController.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final duration = _getSelectedDuration();
    if (duration < const Duration(hours: 1)) {
      _showErrorDialog('確認時間不得低於 1 小時，這是出於安全考量的基本限制。');
      return;
    }
    if (duration > const Duration(days: 7)) {
      _showErrorDialog('地端確認時間不得高於 7 天。更長的安排需要串接雲端備份服務。');
      return;
    }

    final storage = ref.read(storageServiceProvider);

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
      autoRenewOnConfirm: true, // Default to recurring confirmation mode
      recipientIds: [recipient.id],
      message: _messageController.text.trim(),
      sharedMemoryPrompt: _sharedMemoryController.text.trim(),
    );

    if (result.status == CreateTriggerStatus.quotaExceeded) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('額度已達上限', style: TextStyle(color: Colors.white)),
            content: const Text(
              '交代體驗版僅支援 3 次免費安排。若要啟用更多，請升級為安心版（買斷）或守護版（訂閱）。',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      }
    } else {
      // Success, refresh triggers and exit
      ref.read(activeTriggersProvider.notifier).refresh();
      if (mounted) {
        context.pop();
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('時間範圍錯誤', style: TextStyle(color: Colors.white)),
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
    final storage = ref.watch(storageServiceProvider);
    final quota = storage.getUserQuota();

    String quotaText = '免費額度剩餘 ${quota.freeTriggersRemaining} 次';
    if (quota.isLocalUnlimited || quota.isCloudGuardianActive) {
      quotaText = '無限次';
    }

    return Scaffold(
      backgroundColor: Colors.grey[950],
      appBar: AppBar(
        title: const Text('安排安心交代', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section A: Time setting
                const Text(
                  '確認時間間隔',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickTimeButton('24 小時', 24),
                    _buildQuickTimeButton('72 小時', 72),
                    _buildQuickTimeButton('7 天', 168),
                  ],
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 32),

                // Section B: Recipient info
                const Text(
                  '收件人資訊',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recipientNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('收件人姓名'),
                  validator: (val) => (val == null || val.isEmpty) ? '請輸入收件人姓名' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recipientEmailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildInputDecoration('收件人 Email'),
                  validator: (val) {
                    if (val == null || val.isEmpty) return '請輸入收件人 Email';
                    if (!val.contains('@')) return '請輸入正確的 Email 格式';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Relationship>(
                  value: _selectedRelationship,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('與收件人的關係'),
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
                const SizedBox(height: 32),

                // Section C: Message
                const Text(
                  '交代訊息內容',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  maxLength: 300,
                  decoration: _buildInputDecoration('請輸入交代內容（限 300 字）'),
                  validator: (val) => (val == null || val.isEmpty) ? '請輸入交代訊息' : null,
                ),
                const SizedBox(height: 20),

                // Section D: Shared identity passphrase
                const Text(
                  '身分識別暗語',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  '填寫「你」與「這位收件人」之間只有兩人才知道的一件事（例如某段共同經歷）。這段文字會出現在到期通知 Email 的最上方，讓收件人立刻確認：「這是本人親自設定的，不是詐騙或系統誤發」。',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sharedMemoryController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('例如：我們第一次出遊去了哪裡？只有你們兩人知道的事'),
                  validator: (val) => (val == null || val.isEmpty) ? '請填寫身分識別暗語' : null,
                ),
                const SizedBox(height: 40),

                // Section E: Quota and Save
                Center(
                  child: Column(
                    children: [
                      Text(
                        quotaText,
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: _save,
                          child: const Text(
                            '儲存並啟動守護',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
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
}

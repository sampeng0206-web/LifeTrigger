「App內所有UI文案、按鈕、通知、Email範本，除《萬一我消失》這個品牌名稱本身外，一律禁止出現「消失」「死亡」「離開」「最後」「遺言」等字眼。範例替換：
首頁狀態用『今天一切都好嗎？』而非『萬一我消失』；確認按鈕用『我還在』而非『取消Trigger』。」

# Implementation Notes - Week 1

## 待釐清

1. **地端到期觸發限制**：任務 3 的 `checkOverdueTriggers` 在本週僅做狀態更新（更新為 `triggered`）與 log 記錄「應觸發但尚未串接寄送」。由於本週尚未對接任何雲端排程或郵件伺服器（預留給 W2），此階段無法真正寄送信件。
2. **免責聲明條款**：目前 checkOverdueTriggers 判定逾期後「只標記狀態，不實際寄信」以及「App 未被打開時地端判定邏輯不運行」的限制，需記錄於未來 W6 的法規條款與免責聲明中。
3. **待補正式美術素材**：目前 App 圖示與啟動畫面仍使用舊專案「誰在亂搞」的暫用素材。本週功能開發已完成，但後續設計完成後必須將正式美術素材（Logo、App圖示、啟動背景與圖片）補齊並重新生成。

## 決定

1. **套件版本號選用與理由**：
   * `hive: ^2.2.3` / `hive_flutter: ^1.1.0`：極度輕量的地端 NoSQL 資料庫，無須額外的 C++ 編譯開銷，極適合小型交代專案。
   * `flutter_local_notifications: ^17.1.2`：用於本地排程警告通知。
   * `local_auth: ^2.2.0`：用於 Face ID/Touch ID 生物辨識與解鎖。
   * `flutter_secure_storage: ^9.2.2`：用於加密儲存 Face ID 啟用狀態等敏感設定。
   * `flutter_riverpod: ^2.5.1` / `riverpod_annotation: ^2.3.3`：現代化的 Flutter 狀態管理，保障狀態的可測試性與解耦。
   * `go_router: ^14.2.0`：官方宣告式路由管理，支援巢狀路由與跳轉。
   * `uuid: ^4.3.3`：用於生成 Trigger/Recipient 的唯一識別碼。
   * `timezone: ^0.9.2`：通知排程的時區計算。
   * `build_runner: ^2.4.9` / `hive_generator: ^2.0.1` / `riverpod_generator: ^2.4.0`：開發期代碼生成工具。

2. **Hive Box 命名與關聯設計**：
   * **命名**：Trigger 儲存於 `triggers` box；Recipient 儲存於 `recipients` box；UserQuota 儲存於 `user_quotas` box。
   * **關聯方式**：在 `Trigger` 模型中儲存 `List<String> recipientIds`。
   * **理由**：收件人（Recipient）可能在多個不同的 Trigger 中重複使用。若將其拆為獨立 Box 儲存，未來使用者在修改某一收件人聯絡方式（如更換 Email）時，只需更新 `recipients` box 中的單筆資料即可，不需遍歷更新所有 Trigger 內嵌的 Recipient 物件，避免資料不一致。

3. **額度扣除邏輯實作細節**：
   * 當建立全新的 Trigger 時，在 `createNewTrigger` 內檢查 UserQuota：
     * 若 `isLocalUnlimited == true`（安心版買斷）或 `isCloudGuardianActive == true`（訂閱守護版），則直接允許建立，不扣減剩餘額度。
     * 若為免費體驗版且 `freeTriggersRemaining > 0`，則允許建立，並將 `freeTriggersRemaining` 扣減 1。
     * 若都不滿足，則回傳升級付費的狀態。
     * 額度只在「建立全新 Trigger」時扣除，對於 Trigger 的確認（「我還在」）或重置不進行扣減。

4. **iOS Info.plist 配置**：
   * `Info.plist` 中已加入 `NSFaceIDUsageDescription` 機制（Key: `NSFaceIDUsageDescription`，Value: `本App使用Face ID保護您的交代內容，避免他人隨意開啟。`），確保在 iOS 實機呼叫 Face ID 時不會閃退。此設定已納入專案版控，未來經由 Codemagic 或 GitHub Actions 簽章打包時需注意不被覆蓋。

## 偏離

1. **Windows 開發環境下無法本地編譯 iOS**：
   * 偏離原指令「iOS 優先」的本地編譯目標。我們將在本地使用 **Android 模擬器**（啟用指紋辨識模擬）進行主要的 UI 開發與功能邏輯驗證；iOS 的打包發佈移至雲端編譯服務（如 Codemagic / GitHub Actions） or 遠端 Mac 機器進行。

## 取捨

1. **地端逾期檢查的限制（Force Quit 限制）**：
   * 在 iOS 系統上，本地通知（排程防呆警告）在 App 被使用者手動往上滑關閉（Force Quit）後，仍會由 iOS 系統照常發出；但 App 內部的 `checkOverdueTriggers` 自動修正狀態邏輯將無法背景執行，必須等到使用者重新打開 App 時才會觸發地端狀態更新。此為 iOS 本地排程技術限制，故本專案必須取捨：於 W1 本地端僅提供 App 重新啟動時的補行狀態校正，而真正的逾期觸發與信件發送，後續 W2 必須依賴雲端伺服器（Cloud Sync / Cloud Timer）進行可靠的判定。

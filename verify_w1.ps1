Write-Host "=== 開始驗證 LifeTrigger W1 專案 ===" -ForegroundColor Green

# 1. 執行 flutter pub get
Write-Host "1. 執行 flutter pub get..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[錯誤] flutter pub get 失敗！" -ForegroundColor Red
    exit 1
}

# 2. 刪除所有手寫的 .g.dart 檔案
Write-Host "2. 刪除手寫的 .g.dart 檔案..." -ForegroundColor Cyan
$gFiles = Get-ChildItem -Path . -Filter *.g.dart -Recurse
if ($gFiles) {
    foreach ($file in $gFiles) {
        Write-Host "刪除: $($file.FullName)" -ForegroundColor Yellow
        Remove-Item -Path $file.FullName -Force
    }
}
Write-Host "手寫的 .g.dart 檔案已全數刪除。" -ForegroundColor Green

# 3. 執行 build_runner 生成代碼
Write-Host "3. 執行 build_runner 生成代碼..." -ForegroundColor Cyan
flutter packages pub run build_runner build --delete-conflicting-outputs
if ($LASTEXITCODE -ne 0) {
    Write-Host "[錯誤] build_runner 失敗！" -ForegroundColor Red
    exit 1
}
Write-Host "代碼生成完畢！" -ForegroundColor Green

# 4. 執行單元測試
Write-Host "4. 執行單元測試..." -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "[錯誤] 單元測試失敗！" -ForegroundColor Red
    exit 1
}
Write-Host "單元測試全數通過！" -ForegroundColor Green

# 5. 運行 App 到 Android 模擬器
Write-Host "5. 執行 flutter run (請確保已啟動 Android 模擬器)..." -ForegroundColor Cyan
flutter run -d emulator-5554


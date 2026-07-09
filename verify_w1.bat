@echo off
set "JAVA_HOME=C:\Users\vftwo\src\jdk"
set "PATH=C:\Users\vftwo\src\flutter\bin;%JAVA_HOME%\bin;%PATH%"
echo 1. running flutter pub get
call flutter pub get
if %ERRORLEVEL% neq 0 exit /b 1
echo 2. deleting old g.dart files
del /s /q *.g.dart 2>nul
echo 3. running build_runner
call flutter packages pub run build_runner build --delete-conflicting-outputs
if %ERRORLEVEL% neq 0 exit /b 1
echo 4. running flutter test
call flutter test
if %ERRORLEVEL% neq 0 exit /b 1
echo 5. running flutter run on emulator
call flutter run -d emulator-5554

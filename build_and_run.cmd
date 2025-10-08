@echo off

@REM SET ANDROID_HOME=%USERPROFILE%\AppData\Local\Android\Sdk
SET GRADLE_USER_HOME=D:\.gradle
SET ANDROID_HOME=D:\Android\Sdk
SET ANDROID_SDK_ROOT=%ANDROID_HOME%
SET ANDROID_PLATFORM_TOOLS=%ANDROID_HOME%\platform-tools

:: Wait for the emulator to fully boot
echo Waiting for emulator to boot...
:wait_for_boot
%ANDROID_PLATFORM_TOOLS%\adb wait-for-device
%ANDROID_PLATFORM_TOOLS%\adb shell getprop sys.boot_completed > nul 2>&1
if %errorlevel% neq 0 (
    timeout /t 2 /nobreak > nul
    goto :wait_for_boot
)

:: Additional wait to ensure Flutter can detect it
timeout /t 10 /nobreak

:: Run the Flutter app
echo Running Flutter app...
FOR /F "tokens=1" %%A IN ('%ANDROID_PLATFORM_TOOLS%\adb devices ^| findstr emulator') DO (
    echo Running Flutter app on %%A...
    flutter run -d %%A
)
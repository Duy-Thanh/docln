@echo off
REM Complete notification sound fix test script
REM This script fully uninstalls and reinstalls the app to test sound changes

echo ========================================
echo Notification Sound Fix - Full Test
echo ========================================
echo.

echo [1/5] Uninstalling app to clear all cached channels...
adb uninstall com.thanhlam.docln
if %ERRORLEVEL% NEQ 0 (
    echo Warning: App may not be installed
)
echo.

echo [2/5] Cleaning Flutter build...
flutter clean
echo.

echo [3/5] Getting dependencies...
flutter pub get
echo.

echo [4/5] Building and installing app...
echo This will take a few minutes...
flutter run --release
echo.

echo [5/5] DONE!
echo.
echo ========================================
echo TEST INSTRUCTIONS:
echo ========================================
echo 1. Open app ^> Settings ^> Notifications
echo 2. Select "Pixie Dust" sound
echo 3. Look for log: "Created new notification channel (high_importance_channel_v3)"
echo 4. Tap "Test Notification Sound"
echo 5. Listen for Pixie Dust sound (not default)
echo.
echo If it still plays default sound:
echo - Check TROUBLESHOOTING_NOTIFICATION_SOUND.md
echo - Verify android/app/src/main/res/raw/pixie_dust.mp3 exists
echo - Try "Use System Picker" option instead
echo.
pause

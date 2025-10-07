#!/bin/bash

# Linux version of run_android.cmd

echo "Killing any existing emulator processes..."
# Kill specific Android emulator processes safely
killall -q qemu-system-x86_64 2>/dev/null || true
ps aux | grep "[e]mulator.*avd" | awk '{print $2}' | xargs kill -9 2>/dev/null || true
ps aux | grep "[a]db" | awk '{print $2}' | xargs kill -9 2>/dev/null || true

# Wait a moment to ensure processes are killed
sleep 2

# Set Android environment variables
# Adjust these paths according to your Android SDK installation
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"

echo "Starting Android Emulator with cold boot..."
# The -no-snapshot-load flag forces a cold boot
emulator -avd Medium_Phone_API_36.1 -no-snapshot-load -no-snapshot-save &

# Wait for the emulator to fully boot
echo "Waiting for emulator to boot..."
wait_for_boot() {
    adb wait-for-device
    while [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]]; do
        echo "Still booting..."
        sleep 2
    done
}

wait_for_boot

# Additional wait to ensure Flutter can detect it
echo "Emulator booted, waiting for Flutter detection..."
sleep 10

# Run the Flutter app
echo "Running Flutter app..."
EMULATOR_ID=$(adb devices | grep emulator | head -n1 | cut -f1)
if [[ -n "$EMULATOR_ID" ]]; then
    echo "Running Flutter app on $EMULATOR_ID..."
    flutter run -d "$EMULATOR_ID"
else
    echo "No emulator found. Emulator may have failed to start."
    exit 1
fi
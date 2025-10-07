#!/bin/bash

# Flutter development helper script for Linux

# Set Android environment variables
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"

show_help() {
    echo "DocLN Flutter Development Helper - Linux"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  devices     - List available devices"
    echo "  emulators   - List available emulators"
    echo "  start-emu   - Start default emulator (Medium_Phone)"
    echo "  run         - Run app on first available device"
    echo "  build       - Build APK for release"
    echo "  clean       - Clean Flutter project"
    echo "  doctor      - Run Flutter doctor"
    echo "  deps        - Get Flutter dependencies"
    echo "  help        - Show this help message"
    echo ""
}

case "$1" in
    "devices"|"dev")
        echo "Available devices:"
        flutter devices
        ;;
    "emulators"|"emu-list")
        echo "Available emulators:"
        emulator -list-avds
        ;;
    "start-emu"|"emu")
        echo "Starting default emulator..."
        emulator -avd Medium_Phone -no-snapshot-load -no-snapshot-save &
        echo "Emulator started in background"
        ;;
    "run"|"r")
        echo "Running Flutter app..."
        flutter run
        ;;
    "build"|"b")
        echo "Building APK for release..."
        flutter build apk --release
        ;;
    "clean"|"c")
        echo "Cleaning Flutter project..."
        flutter clean
        flutter pub get
        ;;
    "doctor"|"doc")
        echo "Running Flutter doctor..."
        flutter doctor -v
        ;;
    "deps"|"d")
        echo "Getting Flutter dependencies..."
        flutter pub get
        ;;
    "help"|"h"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
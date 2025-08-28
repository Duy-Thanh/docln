#!/bin/bash

# DCL2 Migration Helper Script

set -e

echo "🚀 DCL2 Migration Helper"
echo "========================"

# Function to generate dependency injection code
generate_di() {
    echo "📦 Generating dependency injection code..."
    if command -v dart &> /dev/null; then
        dart pub get
        dart pub run build_runner build --delete-conflicting-outputs
        echo "✅ Dependency injection code generated successfully"
    else
        echo "❌ Dart not found. Please install Flutter/Dart SDK"
        exit 1
    fi
}

# Function to run DCL2 tests
run_tests() {
    echo "🧪 Running DCL2 tests..."
    if command -v flutter &> /dev/null; then
        flutter test test/dcl2/ || echo "⚠️  DCL2 tests not found or failed"
    else
        echo "❌ Flutter not found. Please install Flutter SDK"
        exit 1
    fi
}

# Function to enable DCL2 features
enable_feature() {
    local feature=$1
    echo "🔧 Enabling DCL2 $feature feature..."
    
    # Update constants file
    local constants_file="lib/dcl2/core/constants/constants.dart"
    if [ -f "$constants_file" ]; then
        sed -i.bak "s/enableDcl2${feature^} = false/enableDcl2${feature^} = true/" "$constants_file"
        echo "✅ DCL2 $feature feature enabled in constants"
    else
        echo "❌ Constants file not found"
    fi
}

# Function to disable DCL2 features
disable_feature() {
    local feature=$1
    echo "🔧 Disabling DCL2 $feature feature..."
    
    # Update constants file
    local constants_file="lib/dcl2/core/constants/constants.dart"
    if [ -f "$constants_file" ]; then
        sed -i.bak "s/enableDcl2${feature^} = true/enableDcl2${feature^} = false/" "$constants_file"
        echo "✅ DCL2 $feature feature disabled in constants"
    else
        echo "❌ Constants file not found"
    fi
}

# Function to show status
show_status() {
    echo "📊 DCL2 Migration Status"
    echo "========================"
    
    local constants_file="lib/dcl2/core/constants/constants.dart"
    if [ -f "$constants_file" ]; then
        echo "Feature Flags:"
        grep "enableDcl2" "$constants_file" | while read line; do
            echo "  $line"
        done
    else
        echo "❌ Constants file not found"
    fi
    
    echo ""
    echo "Directory Structure:"
    find lib/dcl2 -type d | head -10
}

# Main script logic
case "$1" in
    "generate")
        generate_di
        ;;
    "test")
        run_tests
        ;;
    "enable")
        if [ -z "$2" ]; then
            echo "Usage: $0 enable <feature>"
            echo "Available features: bookmarks, settings, novels, reader, auth"
            exit 1
        fi
        enable_feature "$2"
        ;;
    "disable")
        if [ -z "$2" ]; then
            echo "Usage: $0 disable <feature>"
            echo "Available features: bookmarks, settings, novels, reader, auth"
            exit 1
        fi
        disable_feature "$2"
        ;;
    "status")
        show_status
        ;;
    "help"|"--help"|"-h"|"")
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  generate      Generate dependency injection code"
        echo "  test          Run DCL2 tests"
        echo "  enable <f>    Enable DCL2 feature (bookmarks, settings, etc.)"
        echo "  disable <f>   Disable DCL2 feature"
        echo "  status        Show current migration status"
        echo "  help          Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 generate"
        echo "  $0 enable bookmarks"
        echo "  $0 disable bookmarks"
        echo "  $0 status"
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
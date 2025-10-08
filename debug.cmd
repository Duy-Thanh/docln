@echo off

@REM SET ANDROID_HOME=%USERPROFILE%\AppData\Local\Android\Sdk
SET GRADLE_USER_HOME=D:\.gradle
SET ANDROID_HOME=D:\Android\Sdk
SET ANDROID_SDK_ROOT=%ANDROID_HOME%
SET ANDROID_PLATFORM_TOOLS=%ANDROID_HOME%\platform-tools

:: Run the Flutter app
flutter build apk --debug
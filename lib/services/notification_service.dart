import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'preferences_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _isEnabled = false;

  // Preferences service instance
  final PreferencesService _prefsService = PreferencesService();

  // Available notification sounds
  static const Map<String, String> availableSounds = {
    'pixie_dust': 'Pixie Dust',
    'default': 'Default System Sound',
    'custom': 'Custom Sound File',
    'system_picker': 'Use System Picker',
  };

  bool get isEnabled => _isEnabled;

  /// Get current notification sound preference
  Future<String> getNotificationSound() async {
    await _prefsService.initialize();
    return _prefsService.getString(
      'notification_sound',
      defaultValue: 'pixie_dust',
    );
  }

  /// Get custom sound file path (if user selected custom)
  Future<String?> getCustomSoundPath() async {
    await _prefsService.initialize();
    return _prefsService.getString('custom_sound_path', defaultValue: '');
  }

  /// Set custom sound file path
  Future<void> setCustomSoundPath(String path) async {
    await _prefsService.initialize();
    await _prefsService.setString('custom_sound_path', path);
    notifyListeners();
  }

  /// Set notification sound preference
  Future<void> setNotificationSound(String sound) async {
    await _prefsService.initialize();
    await _prefsService.setString('notification_sound', sound);
    notifyListeners();
    debugPrint('🔔 Notification sound changed to: $sound');
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize settings
      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final initializationSettings = const InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('🔔 Notification tapped: ${response.payload}');
        },
      );

      // Create default channel for Android
      final hasPermission = await Permission.notification.status.isGranted;
      _isEnabled = hasPermission;
      print(
        '🔔 Notification permission status: ${hasPermission ? 'granted' : 'denied'}',
      );

      final platform =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (platform != null) {
        // Get user's preferred notification sound
        final soundName = await getNotificationSound();
        
        // Create notification channel with custom sound
        final channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications',
          importance: Importance.max,
          playSound: true,
          sound: soundName != 'default' 
              ? RawResourceAndroidNotificationSound(soundName)
              : null, // null uses system default
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );

        await platform.createNotificationChannel(channel);
        print('🔔 High importance notification channel created with sound: $soundName');
      }

      _isInitialized = true;
      print('🔔 Notification service initialized successfully');

      // Load saved preference
      await _prefsService.initialize();
      _isEnabled = _prefsService.getBool('notifications', defaultValue: false);
      notifyListeners();
    } catch (e) {
      print('🔔 Error initializing notification service: $e');
      _isEnabled = false;
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<bool> checkPermission() async {
    final status = await Permission.notification.status;
    _isEnabled = status.isGranted;
    notifyListeners();
    return status.isGranted;
  }

  Future<void> openSettings() async {
    try {
      await AppSettings.openAppSettings();
    } catch (e) {
      print('🔔 Error opening settings: $e');
    }
  }

  /// Open system notification channel settings for this app
  /// This allows users to change sound via Android's native UI
  Future<void> openNotificationChannelSettings() async {
    try {
      final platform =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (platform != null) {
        // This opens the notification channel settings directly
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
        debugPrint('🔔 Opened notification channel settings');
      }
    } catch (e) {
      debugPrint('🔔 Error opening notification channel settings: $e');
      // Fallback to general app settings
      await openSettings();
    }
  }

  Future<bool> setNotificationEnabled(bool enabled) async {
    print("🔔 Setting notification enabled: $enabled");
    try {
      if (enabled) {
        final hasPermission = await requestPermission();
        if (!hasPermission) {
          _isEnabled = false;
          notifyListeners();
          return false;
        }
      }

      await _prefsService.initialize();
      await _prefsService.setBool('notifications', enabled);
      _isEnabled = enabled;
      notifyListeners();
      return true;
    } catch (e) {
      print('🔔 Error setting notification enabled: $e');
      _isEnabled = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> isNotificationEnabled() async {
    try {
      await _prefsService.initialize();
      final enabled = _prefsService.getBool(
        'notifications',
        defaultValue: false,
      );
      _isEnabled = enabled && await Permission.notification.isGranted;
      notifyListeners();
      return _isEnabled;
    } catch (e) {
      print('🔔 Error checking notification status: $e');
      _isEnabled = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPermission() async {
    print("🔔 Requesting notification permission...");
    try {
      final status = await Permission.notification.request();
      print("🔔 Permission status: $status");
      _isEnabled = status.isGranted;
      notifyListeners();
      return status.isGranted;
    } catch (e) {
      print("🔔 Error requesting permission: $e");
      _isEnabled = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    print("🔔 Attempting to show notification: $title");
    if (!_isInitialized) await init();

    try {
      if (!_isEnabled || !(await Permission.notification.isGranted)) {
        print("🔔 Notification permission not granted");
        return false;
      }

      // Get user's preferred notification sound
      final soundName = await getNotificationSound();

      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        sound: soundName != 'default' 
            ? RawResourceAndroidNotificationSound(soundName)
            : null, // null uses system default
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        fullScreenIntent: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notifications.show(
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print("🔔 Notification sent successfully with sound: $soundName");
      return true;
    } catch (e) {
      print("🔔 Error showing notification: $e");
      return false;
    }
  }

  /// Recreate notification channel with new sound (Android only)
  /// Call this after changing notification sound preference
  Future<void> updateNotificationChannel() async {
    try {
      final platform =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (platform != null) {
        // Get user's preferred notification sound
        final soundName = await getNotificationSound();
        
        // Delete old channel
        await platform.deleteNotificationChannel('high_importance_channel');
        
        // Create new channel with updated sound
        final channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications',
          importance: Importance.max,
          playSound: true,
          sound: soundName != 'default' 
              ? RawResourceAndroidNotificationSound(soundName)
              : null,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );

        await platform.createNotificationChannel(channel);
        debugPrint('🔔 Notification channel updated with sound: $soundName');
      }
    } catch (e) {
      debugPrint('❌ Error updating notification channel: $e');
    }
  }

  /// Test notification with current sound setting
  Future<void> testNotificationSound() async {
    final soundName = await getNotificationSound();
    final soundLabel = availableSounds[soundName] ?? 'Unknown';
    
    await showNotification(
      id: 999999,
      title: '🔊 Sound Test',
      body: 'Testing: $soundLabel',
      payload: 'sound_test',
    );
  }
}


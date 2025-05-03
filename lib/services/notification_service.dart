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

  bool get isEnabled => _isEnabled;

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
        const channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );

        await platform.createNotificationChannel(channel);
        print('🔔 High importance notification channel created');
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

      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        fullScreenIntent: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print("🔔 Notification sent successfully");
      return true;
    } catch (e) {
      print("🔔 Error showing notification: $e");
      return false;
    }
  }
}

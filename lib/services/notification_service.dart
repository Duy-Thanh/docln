import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this package

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize settings
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      final initializationSettings = InitializationSettings(
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
      if (await Permission.notification.isDenied) {
        print('🔔 Notification permission is denied');
      }

      final platform = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
          
      if (platform != null) {
        const channel = AndroidNotificationChannel(
          'high_importance_channel', // NEW channel id
          'High Importance Notifications', // NEW channel name
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
    } catch (e) {
      print('🔔 Error initializing notification service: $e');
      rethrow;
    }
  }

  Future<void> setNotificationEnabled(bool enabled) async {
    print("🔔 Setting notification enabled: $enabled");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', enabled);
    
    if (enabled) {
      // Ensure we have permission when enabling
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        throw Exception('Notification permission denied');
      }
    }
  }

  Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications') ?? false;
  }

  Future<bool> requestPermission() async {
    print("🔔 Requesting notification permission...");
    
    // Request notification permission using permission_handler
    final status = await Permission.notification.request();
    print("🔔 Permission status: $status");
    
    return status.isGranted;
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    print("🔔 Attempting to show notification: $title");
    if (!_isInitialized) await init();

    try {
      // Check if permission is granted
      if (!(await Permission.notification.isGranted)) {
        print("🔔 Notification permission not granted");
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel', // Use the new channel
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
    } catch (e) {
      print("🔔 Error showing notification: $e");
      rethrow;
    }
  }
}
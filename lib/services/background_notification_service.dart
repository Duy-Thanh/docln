import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'novel_database_service.dart';
import 'notification_service.dart';
import '../modules/light_novel.dart';

/// Background service that monitors bookmarked novels for updates
/// Uses FCM (Firebase Cloud Messaging) for reliable push notifications
class BackgroundNotificationService {
  static final BackgroundNotificationService _instance =
      BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;
  int? _lastKnownServerStartTime; // Track server restarts
  Timer? _heartbeatTimer; // TIER 3: Periodic heartbeat

  /// Initialize FCM and notification handlers
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request notification permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('✅ FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        final token = await _fcm.getToken();
        debugPrint('📱 FCM Token: $token');

        // Save token for server registration
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token ?? '');

        // Setup message handlers
        _setupMessageHandlers();

        // 🔒 TIER 3: Start heartbeat to detect server restarts
        _startHeartbeat();

        _initialized = true;
        debugPrint('✅ BackgroundNotificationService (FCM) initialized');
      } else {
        debugPrint('⚠️ FCM notifications not authorized');
      }
    } catch (e) {
      debugPrint('❌ Error initializing FCM service: $e');
      rethrow;
    }
  }

  /// Setup FCM message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground message received: ${message.notification?.title}');
      _handleMessage(message);
    });

    // Handle background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Background message opened: ${message.notification?.title}');
      _handleMessage(message);
    });

    // Handle messages when app is terminated (setup in main.dart)
    // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Handle incoming FCM messages
  void _handleMessage(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        // Show local notification
        await _sendNotification(
          id: message.hashCode,
          title: notification.title ?? 'Novel Update',
          body: notification.body ?? '',
          payload: data['novelId'],
        );

        // Update last check time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_background_check', DateTime.now().millisecondsSinceEpoch);
      }

      // Handle data payload
      if (data.containsKey('action')) {
        await _handleDataPayload(data);
      }
    } catch (e) {
      debugPrint('❌ Error handling FCM message: $e');
    }
  }

  /// Handle data-only payload from FCM
  Future<void> _handleDataPayload(Map<String, dynamic> data) async {
    final action = data['action'];

    switch (action) {
      case 'novel_update':
        final novelId = data['novelId'];
        debugPrint('📖 Novel update received for: $novelId');
        // Optionally fetch latest novel details from server
        break;

      case 'force_refresh':
        debugPrint('🔄 Force refresh requested from server');
        // Trigger a manual refresh of all bookmarks
        break;

      case 'sync_bookmarks':
        debugPrint('🔄 Syncing bookmarks with server');
        await _syncBookmarksWithServer();
        break;

      default:
        debugPrint('⚠️ Unknown action: $action');
    }
  }

  /// Start FCM-based monitoring by registering bookmarks with server
  Future<void> startPeriodicChecks() async {
    await initialize();

    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');

      if (fcmToken == null || fcmToken.isEmpty) {
        throw Exception('FCM token not available');
      }

      // Register bookmarks with your backend server
      await _syncBookmarksWithServer();

      // Save registration status
      await prefs.setBool('background_checks_enabled', true);
      await prefs.setInt('background_checks_started_at', DateTime.now().millisecondsSinceEpoch);

      debugPrint('✅ FCM monitoring enabled');
      debugPrint('📡 Server will monitor your bookmarks and send push notifications');
      debugPrint('⚡ Instant notifications when updates are detected!');
    } catch (e) {
      debugPrint('❌ Error starting FCM monitoring: $e');
      rethrow;
    }
  }

  /// Stop FCM monitoring
  Future<void> stopPeriodicChecks() async {
    try {
      // Stop heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      
      // Unregister from server
      await _unregisterFromServer();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_checks_enabled', false);
      await prefs.remove('background_checks_started_at');

      debugPrint('⏹️ FCM monitoring stopped');
    } catch (e) {
      debugPrint('❌ Error stopping FCM monitoring: $e');
    }
  }

  /// 🔒 TIER 3: Heartbeat to detect server restarts
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _checkServerHealth();
    });
    debugPrint('💓 Heartbeat started (60s interval)');
  }

  /// Check if server has restarted and re-sync if needed
  Future<void> _checkServerHealth() async {
    try {
      // final serverUrl = 'http://10.0.2.2:3000/health';
      final serverUrl = 'https://docln.javalorant.xyz/health';
      final response = await http.get(Uri.parse(serverUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentServerStartTime = data['serverStartTime'];

        if (currentServerStartTime != null) {
          if (_lastKnownServerStartTime != null && 
              _lastKnownServerStartTime != currentServerStartTime) {
            // 🔒 TIER 2: Server restarted! Re-sync bookmarks
            debugPrint('🔄 Server restart detected! Re-syncing bookmarks...');
            await _syncBookmarksWithServer();
          }
          _lastKnownServerStartTime = currentServerStartTime;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Heartbeat check failed: $e');
      // Server might be down, will retry in next interval
    }
  }

  /// Sync bookmarks with backend server
  Future<void> _syncBookmarksWithServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');
      final currentServer = prefs.getString('selected_server') ?? 'https://docln.sbs';

      // Get all bookmarks
      final db = NovelDatabaseService();
      await db.initialize();
      final bookmarks = await db.getBookmarks(currentServer);

      if (bookmarks.isEmpty) {
        debugPrint('ℹ️ No bookmarks to sync');
        return;
      }

      // Prepare bookmark data for server
      final bookmarkData = bookmarks.map((novel) {
        return {
          'novelId': novel.id,
          'title': novel.title,
          'url': novel.url,
          'lastUpdated': novel.lastUpdated,
          'chapters': novel.chapters,
          'notificationEnabled': prefs.getBool('notification_enabled_${novel.id}') ?? true,
        };
      }).toList();

      // TODO: Replace with your actual backend server URL after deployment
      // Examples:
      // - Railway: 'https://your-app.up.railway.app/api/sync-bookmarks'
      // - Render: 'https://docln-notification-server.onrender.com/api/sync-bookmarks'
      // - Heroku: 'https://docln-notification-server.herokuapp.com/api/sync-bookmarks'
      // - VPS: 'https://your-domain.com/api/sync-bookmarks'
      // 
      // For local testing:
      // - Android Emulator: 'http://10.0.2.2:3000/api/sync-bookmarks'
      // - iOS Simulator: 'http://localhost:3000/api/sync-bookmarks'
      // - Physical Device: 'http://YOUR_COMPUTER_IP:3000/api/sync-bookmarks'
      // final serverUrl = 'http://10.0.2.2:3000/api/sync-bookmarks'; // Android Emulator
      final serverUrl = 'https://docln.javalorant.xyz/api/sync-bookmarks'; // Android Emulator

      debugPrint('📤 Syncing ${bookmarks.length} bookmarks with server...');

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcmToken': fcmToken,
          'bookmarks': bookmarkData,
          'server': currentServer,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // 🔒 TIER 2: Track server start time for restart detection
        final responseData = jsonDecode(response.body);
        if (responseData['serverStartTime'] != null) {
          _lastKnownServerStartTime = responseData['serverStartTime'];
          debugPrint('✅ Server start time tracked: $_lastKnownServerStartTime');
        }
        debugPrint('✅ Bookmarks synced with server');
      } else {
        debugPrint('⚠️ Server returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error syncing bookmarks: $e');
      // Fallback to local monitoring if server is unavailable
      debugPrint('⚠️ Falling back to local monitoring');
    }
  }

  /// Unregister from server
  Future<void> _unregisterFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');

      if (fcmToken == null) return;

      // TODO: Replace with your actual backend server URL after deployment
      // For local testing:
      // - Android Emulator: 'http://10.0.2.2:3000/api/unregister'
      // - iOS Simulator: 'http://localhost:3000/api/unregister'
      // - Physical Device: 'http://YOUR_COMPUTER_IP:3000/api/unregister'
      // final serverUrl = 'http://10.0.2.2:3000/api/unregister'; // Android Emulator
      final serverUrl = 'https://docln.javalorant.xyz/api/unregister'; // Android Emulator

      await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcmToken': fcmToken}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('✅ Unregistered from server');
    } catch (e) {
      debugPrint('⚠️ Error unregistering from server: $e');
    }
  }

  /// Check if background checks are enabled
  Future<bool> areBackgroundChecksEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('background_checks_enabled') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking background status: $e');
      return false;
    }
  }

  /// Get last background check time
  Future<DateTime?> getLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Force reload to get updates
      final timestamp = prefs.getInt('last_background_check');
      return timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e) {
      debugPrint('❌ Error getting last check time: $e');
      return null;
    }
  }

  /// Check if notifications are enabled for a specific novel
  Future<bool> isNovelNotificationEnabled(String novelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notification_enabled_$novelId') ?? true;
    } catch (e) {
      debugPrint('❌ Error checking notification status: $e');
      return true; // Default to enabled
    }
  }

  /// Enable/disable notifications for a specific novel
  Future<void> setNovelNotificationEnabled(String novelId, bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_enabled_$novelId', enabled);
      
      // Re-sync with server to update notification preferences
      await _syncBookmarksWithServer();
      
      debugPrint(
        '${enabled ? '🔔' : '🔕'} Notifications ${enabled ? 'enabled' : 'disabled'} for novel $novelId',
      );
    } catch (e) {
      debugPrint('❌ Error setting notification status: $e');
    }
  }

  /// Trigger a manual check (useful for testing or immediate refresh)
  /// This will fetch and check all bookmarks locally
  Future<void> triggerManualCheck() async {
    await initialize();

    try {
      debugPrint('⚡ Triggering manual check...');
      
      final prefs = await SharedPreferences.getInstance();
      final currentServer = prefs.getString('selected_server') ?? 'https://docln.sbs';
      
      // Get all bookmarks
      final db = NovelDatabaseService();
      await db.initialize();
      final bookmarks = await db.getBookmarks(currentServer);

      if (bookmarks.isEmpty) {
        debugPrint('ℹ️ No bookmarked novels to check');
        return;
      }

      debugPrint('📚 Checking ${bookmarks.length} bookmarked novels...');

      // Check app version
      await _checkAppVersion();

      // Check each bookmark
      for (final novel in bookmarks) {
        try {
          final isEnabled = prefs.getBool('notification_enabled_${novel.id}') ?? true;
          if (!isEnabled) {
            debugPrint('🔕 Skipping ${novel.title} (notifications disabled)');
            continue;
          }

          await _checkNovelForUpdates(novel, currentServer, db, prefs);
        } catch (e) {
          debugPrint('❌ Error checking novel ${novel.title}: $e');
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(seconds: 1));
      }

      // Update last check time
      await prefs.setInt('last_background_check', DateTime.now().millisecondsSinceEpoch);

      debugPrint('✅ Manual check completed!');
    } catch (e) {
      debugPrint('❌ Error during manual check: $e');
      rethrow;
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to a topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Check if a new app version is available
  static Future<void> _checkAppVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastKnownVersion = prefs.getString('last_known_app_version') ?? '';
      const currentVersion = '2025.10.11'; // From pubspec.yaml

      if (lastKnownVersion.isNotEmpty && lastKnownVersion != currentVersion) {
        // New version detected
        await _sendNotification(
          id: 999999,
          title: '🎉 App Updated!',
          body: 'DocLN has been updated to version $currentVersion',
          payload: 'app_version_update',
        );
      }

      await prefs.setString('last_known_app_version', currentVersion);
    } catch (e) {
      debugPrint('❌ Error checking app version: $e');
    }
  }

  /// Send a notification
  static Future<void> _sendNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final notificationService = NotificationService();
      await notificationService.init();

      if (notificationService.isEnabled) {
        await notificationService.showNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }
}

/// Background message handler for FCM (must be top-level function)
/// This handles messages when the app is terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Handling background message: ${message.notification?.title}');
  
  // Initialize services if needed
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('last_background_check', DateTime.now().millisecondsSinceEpoch);
  
  // You can handle data payload here if needed
  if (message.data.isNotEmpty) {
    debugPrint('📦 Message data: ${message.data}');
  }
}

/// Check a single novel for updates
Future<void> _checkNovelForUpdates(
  LightNovel novel,
  String currentServer,
  NovelDatabaseService db,
  SharedPreferences prefs,
) async {
  try {
    // Get the full URL
    final fullUrl = novel.url.startsWith('http')
        ? novel.url
        : '$currentServer${novel.url}';

    debugPrint('🔍 Checking: ${novel.title}');
    debugPrint('   URL: $fullUrl');

    // IMPORTANT: Background tasks run in a separate isolate
    // Complex services (DNS, Proxy) may not work properly in background
    // Use simple direct HTTP connection for reliability
    
    Map<String, dynamic> novelDetails = {};
    
    debugPrint('   🌐 Fetching HTML directly...');
    
    // Retry logic for DNS/network failures
    const maxRetries = 3;
    int retryCount = 0;
    Duration retryDelay = const Duration(seconds: 2);
    
    while (retryCount < maxRetries) {
      try {
        final startTime = DateTime.now();
        
        // Simple direct HTTP request with generous timeout
        final response = await http.get(
          Uri.parse(fullUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml',
            'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
          },
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            final elapsed = DateTime.now().difference(startTime);
            debugPrint('   ❌ HTTP request timed out after ${elapsed.inSeconds}s');
            throw TimeoutException('HTTP timeout after ${elapsed.inSeconds}s');
          },
        );

        final elapsed = DateTime.now().difference(startTime);
        debugPrint('   ✅ Got response (${response.statusCode}) in ${elapsed.inSeconds}s');

        if (response.statusCode != 200) {
          debugPrint('   ❌ Bad status code: ${response.statusCode}');
          return;
        }

        // Parse HTML directly without using CrawlerService
        debugPrint('   📝 Parsing HTML...');
        final document = html_parser.parse(response.body);

        // Extract title
        final titleElement = document.querySelector('.series-name a');
        final title = titleElement?.text.trim() ?? novel.title;

        // Extract cover
        final coverElement = document.querySelector('.series-cover .content.img-in-ratio');
        String? coverUrl = novel.coverUrl;
        if (coverElement != null) {
          final style = coverElement.attributes['style'] ?? '';
          final urlMatch = RegExp(r"url\('([^']+)'\)").firstMatch(style);
          if (urlMatch != null) {
            coverUrl = urlMatch.group(1);
          }
        }

        // Extract chapters
        final chapterElements = document.querySelectorAll('.chapter-name');
        final chapters = <Map<String, dynamic>>[];

        for (var element in chapterElements) {
          final titleElement = element.querySelector('a');
          final linkElement = element.querySelector('a');

          if (titleElement != null && linkElement != null) {
            final chapterTitle = titleElement.text.trim();
            final chapterLink = linkElement.attributes['href'] ?? '';

            chapters.add({
              'title': chapterTitle,
              'url': chapterLink,
            });
          }
        }

        debugPrint('   ✅ Found ${chapters.length} chapters');

        // Extract actual last updated time from the website
        // Look for the latest chapter's time
        String? lastUpdated;
        final firstChapterTime = document.querySelector('.chapter-time');
        if (firstChapterTime != null) {
          lastUpdated = firstChapterTime.text.trim();
        }

        novelDetails = {
          'title': title,
          'cover': coverUrl,
          'chapters': chapters,
          'lastUpdated': lastUpdated, // Use actual time from website, not current time
        };

        debugPrint('   ✅ Parsed successfully');
        break; // Success! Exit retry loop
        
      } catch (e) {
        retryCount++;
        final isDnsError = e.toString().contains('Failed host lookup') || 
                          e.toString().contains('SocketException');
        
        if (retryCount < maxRetries && isDnsError) {
          debugPrint('   ⚠️ DNS/Network error (attempt $retryCount/$maxRetries): $e');
          debugPrint('   🔄 Retrying in ${retryDelay.inSeconds}s...');
          await Future.delayed(retryDelay);
          retryDelay = retryDelay * 2; // Exponential backoff
        } else {
          debugPrint('   ❌ Failed to fetch/parse: $e');
          return; // Give up after max retries
        }
      }
    }

    if (novelDetails.isEmpty ||
        novelDetails['title'] == null ||
        (novelDetails['title'] as String).isEmpty) {
      debugPrint('⚠️ No valid novel details returned');
      return;
    }

    // Create updated LightNovel object
    final updatedNovel = LightNovel(
      id: novel.id,
      title: novelDetails['title'] ?? novel.title,
      url: fullUrl,
      coverUrl: novelDetails['cover'] ?? novel.coverUrl,
      chapters: (novelDetails['chapters'] as List?)?.length ?? novel.chapters,
      latestChapter: (novelDetails['chapters'] as List?)?.isNotEmpty == true
          ? (novelDetails['chapters'] as List).first['title']
          : novel.latestChapter,
      lastUpdated: novelDetails['lastUpdated'] ?? novel.lastUpdated,
      rating: novelDetails['rating'] ?? novel.rating,
      reviews: novelDetails['reviews'] ?? novel.reviews,
      views: novelDetails['views'] ?? novel.views,
    );

    // Get last known state
    final lastKnownKey = 'novel_last_state_${novel.id}';
    final lastKnownStateJson = prefs.getString(lastKnownKey);

    Map<String, dynamic>? lastKnownState;
    if (lastKnownStateJson != null) {
      lastKnownState = jsonDecode(lastKnownStateJson) as Map<String, dynamic>;
    }

    // Check for changes and send notifications
    await _compareAndNotify(novel, updatedNovel, lastKnownState);

    // Save updated state
    final newState = {
      'chapters': updatedNovel.chapters,
      'latestChapter': updatedNovel.latestChapter,
      'lastUpdated': updatedNovel.lastUpdated,
      'views': updatedNovel.views,
      'rating': updatedNovel.rating,
      'reviews': updatedNovel.reviews,
    };
    await prefs.setString(lastKnownKey, jsonEncode(newState));

    // Update database
    await db.saveNovel(updatedNovel);

    debugPrint('✅ Updated: ${novel.title}');
  } catch (e) {
    debugPrint('❌ Error checking novel ${novel.title}: $e');
  }
}

/// Compare old and new state and send notifications
Future<void> _compareAndNotify(
  LightNovel oldNovel,
  LightNovel newNovel,
  Map<String, dynamic>? lastKnownState,
) async {
  if (lastKnownState == null) {
    // First time tracking this novel, don't send notifications
    return;
  }

  final notificationId = oldNovel.id.hashCode;

  // Check for new chapters
  final oldChapters = lastKnownState['chapters'] as int? ?? 0;
  final newChapters = newNovel.chapters ?? 0;

  if (newChapters > oldChapters) {
    final chaptersAdded = newChapters - oldChapters;
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 1,
      title: '📖 ${newNovel.title}',
      body: chaptersAdded == 1
          ? 'Chapter $newChapters has been released!'
          : '$chaptersAdded new chapters released!',
      payload: 'novel:${newNovel.id}',
    );
  }

  // Check for chapter updates
  if (newNovel.latestChapter != (lastKnownState['latestChapter'] ?? '') &&
      newChapters == oldChapters) {
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 2,
      title: '✏️ ${newNovel.title}',
      body: 'Chapter "${newNovel.latestChapter}" has been updated!',
      payload: 'novel:${newNovel.id}',
    );
  }

  // Check for story information updates
  if (newNovel.lastUpdated != (lastKnownState['lastUpdated'] ?? '')) {
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 3,
      title: '🔄 ${newNovel.title}',
      body: 'Story information has been updated',
      payload: 'novel:${newNovel.id}',
    );
  }

  // Check for rating/review changes (significant changes only)
  final oldRating = lastKnownState['rating'] as double? ?? 0.0;
  final newRating = newNovel.rating ?? 0.0;
  final oldReviews = lastKnownState['reviews'] as int? ?? 0;
  final newReviews = newNovel.reviews ?? 0;

  if ((newRating - oldRating).abs() > 0.5 || newReviews - oldReviews > 10) {
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 4,
      title: '⭐ ${newNovel.title}',
      body: 'Rating: ${newRating.toStringAsFixed(1)} ($newReviews reviews)',
      payload: 'novel:${newNovel.id}',
    );
  }
}

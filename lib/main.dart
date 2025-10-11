import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/SplashScreen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Services
import 'services/notification_service.dart';
import 'services/background_notification_service.dart';
import 'services/theme_services.dart';
import 'services/language_service.dart';
import 'services/bookmark_service.dart';
import 'services/bookmark_service_v2.dart';
import 'services/history_service_v2.dart';
import 'services/novel_database_service.dart';
import 'services/novel_data_migration_service.dart';
import 'services/proxy_service.dart';
import 'services/http_client.dart';
import 'services/dns_service.dart';
import 'services/server_management_service.dart';
import 'services/novel_url_migration_service.dart';
import 'screens/HistoryScreen.dart';
import 'handler/system_ui_handler.dart';
import 'screens/HomeScreen.dart';
import 'services/crawler_service.dart';
import 'services/preferences_service.dart';
import 'services/preferences_recovery_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Dart libs
import 'dart:ui';

// Function to migrate from old preferences to new SQLite-based preferences
Future<void> migratePreferences() async {
  try {
    // Check if migration has already been done
    final prefsService = PreferencesService();
    await prefsService.initialize();

    if (prefsService.getBool(
      '_sqlite_migration_completed',
      defaultValue: false,
    )) {
      debugPrint('SQLite preferences migration already completed, skipping');
      return;
    }

    debugPrint(
      'Starting migration from SharedPreferences to SQLite preferences...',
    );

    // The migration is now handled in the PreferencesService
    // This simply triggers the migration process
    await prefsService.migrateToSQLite();

    // Mark migration as complete
    await prefsService.setBool('_sqlite_migration_completed', true);

    debugPrint('Preferences migration to SQLite completed successfully');
  } catch (e) {
    debugPrint('Error migrating preferences: $e');
  }
}

// Function to migrate novel data from JSON to database
Future<void> migrateNovelData() async {
  try {
    debugPrint('🔄 Checking if novel data migration is needed...');

    final migrationService = NovelDataMigrationService();

    // Check if we need to fix a previous migration (backup exists but migration done)
    final prefs = PreferencesService();
    await prefs.initialize();

    final migrationComplete = prefs.getBool(
      'novel_data_migration_complete_v2',
      defaultValue: false,
    );
    final fixApplied = prefs.getBool(
      'novel_data_migration_fix_applied',
      defaultValue: false,
    );
    final hasBackup = prefs.getString('bookmarked_novels_backup').isNotEmpty;

    // If migration was done but fix not applied yet, and we still have backup
    if (migrationComplete && !fixApplied && hasBackup) {
      debugPrint('🔧 Detected previous migration with URL issues, fixing...');

      final fixSuccess = await migrationService.fixMigration();

      if (fixSuccess) {
        // Mark fix as applied so it doesn't run again
        await prefs.setBool('novel_data_migration_fix_applied', true);

        debugPrint('✅ Migration fix successful!');

        // Show stats
        final info = await migrationService.getMigrationInfo();
        debugPrint('   Fixed bookmarks: ${info['newData']?['bookmarks'] ?? 0}');
        debugPrint('   Fixed history: ${info['newData']?['history'] ?? 0}');
      } else {
        debugPrint('⚠️ Migration fix had issues, using existing data');
      }

      return;
    }

    if (await migrationService.needsMigration()) {
      debugPrint('📚 Starting novel data migration (JSON → Database)...');

      final success = await migrationService.migrate();

      if (success) {
        debugPrint('✅ Novel data migration successful!');

        // Show migration info
        final info = await migrationService.getMigrationInfo();
        debugPrint('   Old bookmarks: ${info['oldData']?['bookmarks'] ?? 0}');
        debugPrint('   Old history: ${info['oldData']?['history'] ?? 0}');
        debugPrint('   New bookmarks: ${info['newData']?['bookmarks'] ?? 0}');
        debugPrint('   New history: ${info['newData']?['history'] ?? 0}');

        // Clean up old JSON data (backed up first)
        await migrationService.cleanupOldData();
        debugPrint('🧹 Old JSON data cleaned up (backups saved)');
      } else {
        debugPrint('⚠️ Novel data migration had issues, but app will continue');
      }
    } else {
      debugPrint('ℹ️ Novel data migration not needed (already completed)');
    }
  } catch (e) {
    debugPrint('❌ Error during novel data migration: $e');
    debugPrint('App will continue with current data');
  }
}

// Function to enable notifications for existing bookmarks (one-time migration)
Future<void> enableNotificationsForExistingBookmarks() async {
  try {
    final prefs = PreferencesService();
    await prefs.initialize();

    // Check if migration has already been done
    final migrationDone = prefs.getBool(
      'notifications_enabled_for_existing_bookmarks',
      defaultValue: false,
    );

    if (migrationDone) {
      debugPrint('✅ Notifications already enabled for existing bookmarks');
      return;
    }

    debugPrint('🔔 Enabling notifications for existing bookmarks...');

    final bookmarkService = BookmarkServiceV2();
    await bookmarkService.init();

    final bookmarkCount = bookmarkService.bookmarkCount;

    if (bookmarkCount == 0) {
      debugPrint('ℹ️ No existing bookmarks, skipping migration');
      await prefs.setBool('notifications_enabled_for_existing_bookmarks', true);
      return;
    }

    debugPrint('📚 Found $bookmarkCount existing bookmarks');

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.init();

    // Check if we can enable notifications
    final hasPermission = await notificationService.checkPermission();

    if (!hasPermission) {
      debugPrint(
        '⚠️ Requesting notification permission for existing bookmarks...',
      );
      final granted = await notificationService.requestPermission();

      if (!granted) {
        debugPrint('⚠️ Notification permission denied, skipping migration');
        await prefs.setBool(
          'notifications_enabled_for_existing_bookmarks',
          true,
        );
        return;
      }
    }

    // Enable notifications
    await notificationService.setNotificationEnabled(true);

    // Start background service
    final backgroundService = BackgroundNotificationService();
    await backgroundService.initialize();
    await backgroundService.startPeriodicChecks();

    // Mark migration as complete
    await prefs.setBool('notifications_enabled_for_existing_bookmarks', true);

    debugPrint(
      '✅ Notifications enabled for $bookmarkCount existing bookmarks!',
    );

    // Send a welcome notification
    await notificationService.showNotification(
      id: 888888,
      title: '🔔 Notifications Enabled!',
      body:
          'You\'ll now receive updates for your $bookmarkCount bookmarked novels',
      payload: 'welcome_notification',
    );
  } catch (e) {
    debugPrint('❌ Error enabling notifications for existing bookmarks: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FlutterError.onError = (errorDetails) {
  //   FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  // };

  // // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  // PlatformDispatcher.instance.onError = (error, stack) {
  //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  //   return true;
  // };

  // // Add this test event
  // await FirebaseAnalytics.instance.logEvent(
  //   name: 'app_opened',
  //   parameters: {'time': DateTime.now().toString()},
  // );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize and repair SQLite preferences if needed (before initializing other services)
  await PreferencesService.repairIfNeeded();

  // Migrate from old preferences to new SQLite-based preferences
  await migratePreferences();

  // Initialize server management and migrate novel URLs
  final serverManagement = ServerManagementService();
  final urlMigration = NovelUrlMigrationService();
  await serverManagement.initialize();
  await urlMigration.migrateNovelUrls();

  // Migrate novel data from JSON to database (CRITICAL FIX!)
  await migrateNovelData();

  final themeService = ThemeServices();
  final languageService = LanguageService();
  final notificationService = NotificationService();
  final backgroundNotificationService = BackgroundNotificationService();
  final bookmarkService = BookmarkService();
  final bookmarkServiceV2 = BookmarkServiceV2();
  // final historyService = HistoryService(); // Old service removed
  final historyServiceV2 = HistoryServiceV2();
  final proxyService = ProxyService();
  final httpClient = AppHttpClient();
  final dnsService = DnsService();
  final crawlerService = CrawlerService();
  final preferencesService = PreferencesService();

  await Future.wait([
    preferencesService.initialize(),
    themeService.init(),
    languageService.init(),
    notificationService.init(),
    backgroundNotificationService.initialize(),
    bookmarkService.init(),
    bookmarkServiceV2.init(),
    // historyService.loadHistory(); // Old service removed
    historyServiceV2.init(),
    proxyService.initialize(),
    httpClient.initialize(),
    dnsService.initialize(),
    crawlerService.initialize(),
  ]);

  // Start periodic background checks for novel updates
  // This runs even when the app is closed
  await backgroundNotificationService.startPeriodicChecks();

  // Enable notifications for existing bookmarks (one-time migration for users updating from old versions)
  await enableNotificationsForExistingBookmarks();

  // Set initial system UI styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferencesService>.value(
          value: preferencesService,
        ),
        ChangeNotifierProvider<ThemeServices>.value(value: themeService),
        ChangeNotifierProvider<LanguageService>.value(value: languageService),
        ChangeNotifierProvider<NotificationService>.value(
          value: notificationService,
        ),
        ChangeNotifierProvider<BookmarkService>.value(value: bookmarkService),
        ChangeNotifierProvider<BookmarkServiceV2>.value(
          value: bookmarkServiceV2,
        ),
        // ChangeNotifierProvider<HistoryService>.value(value: historyService), // Old service removed
        ChangeNotifierProvider<HistoryServiceV2>.value(value: historyServiceV2),
        ChangeNotifierProvider<ServerManagementService>.value(
          value: serverManagement,
        ),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  // static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  // static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
  //   analytics: analytics,
  // );

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeServices>(context);
    final languageService = Provider.of<LanguageService>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DocLN',
      theme: themeService.getLightTheme(),
      darkTheme: themeService.getDarkTheme(),
      themeMode: themeService.themeMode,
      locale: languageService.currentLocale,
      supportedLocales: const [Locale('en', ''), Locale('vi', '')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder(
        // This future checks if the splash screen has been shown and if auth is initialized
        future: Future.delayed(const Duration(seconds: 5), () => true),
        builder: (context, snapshot) {
          // While waiting, show splash screen
          if (!snapshot.hasData) {
            return const SplashScreen();
          }

          // After splash screen, always go to home screen (login is optional)
          // The user can choose to login from the home screen if they want
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: HomeScreen(),
            transitionBuilder: (Widget child, Animation<double> animation) {
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              );

              return FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                  ),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.7,
                    end: 1.0,
                  ).animate(curvedAnimation),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

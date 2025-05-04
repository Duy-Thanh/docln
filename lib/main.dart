import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/SplashScreen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Services
import 'services/notification_service.dart';
import 'services/theme_services.dart';
import 'services/language_service.dart';
import 'services/bookmark_service.dart';
import 'services/proxy_service.dart';
import 'services/http_client.dart';
import 'services/dns_service.dart';
import 'screens/HistoryScreen.dart';
import 'handler/system_ui_handler.dart';
import 'screens/HomeScreen.dart';
import 'services/crawler_service.dart';
import 'services/preferences_service.dart';
import 'services/preferences_recovery_service.dart';
import 'services/auth_service.dart';
import 'services/encrypted_db_service.dart';
import 'screens/LoginScreen.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cajmqxovsmtcybsezibu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNham1xeG92c210Y3lic2V6aWJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYzMTYzMDIsImV4cCI6MjA2MTg5MjMwMn0.mt7uv4_MOAJzCHBGuGw_c_OB7HXTvqmNvKzHlZqPed0',
    debug: true,
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Add this test event
  await FirebaseAnalytics.instance.logEvent(
    name: 'app_opened',
    parameters: {'time': DateTime.now().toString()},
  );

  // Initialize and repair SQLite preferences if needed (before initializing other services)
  await PreferencesService.repairIfNeeded();

  // Migrate from old preferences to new SQLite-based preferences
  await migratePreferences();

  final themeService = ThemeServices();
  final languageService = LanguageService();
  final notificationService = NotificationService();
  final bookmarkService = BookmarkService();
  final historyService = HistoryService();
  final proxyService = ProxyService();
  final httpClient = AppHttpClient();
  final dnsService = DnsService();
  final crawlerService = CrawlerService();
  final preferencesService = PreferencesService();
  final authService = AuthService();
  final encryptedDbService = EncryptedDbService();

  await Future.wait([
    preferencesService.initialize(),
    themeService.init(),
    languageService.init(),
    notificationService.init(),
    bookmarkService.init(),
    historyService.loadHistory(),
    proxyService.initialize(),
    httpClient.initialize(),
    dnsService.initialize(),
    crawlerService.initialize(),
    authService.initialize(),
    encryptedDbService.initialize(),
  ]);

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
        ChangeNotifierProvider<HistoryService>.value(value: historyService),
        ChangeNotifierProvider<AuthService>.value(value: authService),
      ],
      child: const MainApp(),
    ),
  );
}

// It's handy to then extract the Supabase client in a variable for later uses
final supabase = Supabase.instance.client;

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeServices>(context);
    final languageService = Provider.of<LanguageService>(context);
    final authService = Provider.of<AuthService>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DocLN',
      theme: themeService.getLightTheme(),
      darkTheme: themeService.getDarkTheme(),
      themeMode: themeService.themeMode,
      navigatorObservers: [observer],
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

          // After splash screen, decide whether to show login or home screen
          Widget nextScreen;
          if (authService.isAuthenticated) {
            nextScreen = HomeScreen();
          } else {
            // Check if this is the first time or the user has explicitly logged out
            final hasLoggedOutBefore = Provider.of<PreferencesService>(
              context,
              listen: false,
            ).getBool('has_logged_out_before', defaultValue: false);

            if (hasLoggedOutBefore) {
              nextScreen = const LoginScreen();
            } else {
              // For first time users, let them use the app before requiring login
              nextScreen = HomeScreen();
            }
          }

          // Create an animation controller manually for the transition
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: nextScreen,
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

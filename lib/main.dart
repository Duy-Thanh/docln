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
import 'services/preferences_recovery_service.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Dart libs
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Check and repair preferences if corrupted (before initializing other services)
  await PreferencesRecoveryService.repairIfNeeded();

  final themeService = ThemeServices();
  final languageService = LanguageService();
  final notificationService = NotificationService();
  final bookmarkService = BookmarkService();
  final historyService = HistoryService();
  final proxyService = ProxyService();
  final httpClient = AppHttpClient();
  final dnsService = DnsService();
  final crawlerService = CrawlerService();
  final preferencesRecoveryService = PreferencesRecoveryService();

  await Future.wait([
    themeService.init(),
    languageService.init(),
    notificationService.init(),
    bookmarkService.init(),
    historyService.loadHistory(),
    proxyService.initialize(),
    httpClient.initialize(),
    dnsService.initialize(),
    crawlerService.initialize(),
    preferencesRecoveryService.initialize(),
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
        ChangeNotifierProvider<ThemeServices>.value(value: themeService),
        ChangeNotifierProvider<LanguageService>.value(value: languageService),
        ChangeNotifierProvider<NotificationService>.value(
          value: notificationService,
        ),
        ChangeNotifierProvider<BookmarkService>.value(value: bookmarkService),
        ChangeNotifierProvider<HistoryService>.value(value: historyService),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeServices, LanguageService>(
      builder: (context, themeService, languageService, child) {
        return AnimatedSystemUIHandler(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeService.themeMode,
            theme: themeService.getLightTheme(),
            darkTheme: themeService.getDarkTheme(),
            locale: languageService.currentLocale,
            navigatorObservers: [observer],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en', ''), Locale('vi', '')],
            builder: (context, child) {
              // Ensure proper MediaQuery inheritance
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                // Prevent text scaling from affecting layout
                data: mediaQuery.copyWith(
                  textScaler: themeService.textScaler,
                  // Ensure proper padding for system UI
                  padding: mediaQuery.padding,
                  viewPadding: mediaQuery.viewPadding,
                  viewInsets: mediaQuery.viewInsets,
                ),
                child: ScrollConfiguration(
                  // Enable scrolling everywhere
                  behavior: const MaterialScrollBehavior().copyWith(
                    physics: const ClampingScrollPhysics(),
                    // Enable drag scrolling on all platforms
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: child!,
                ),
              );
            },
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}

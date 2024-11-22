import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/SplashScreen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Services
import 'services/notification_service.dart';
import 'services/theme_services.dart';
import 'services/language_service.dart';
import 'handler/system_ui_handler.dart';

// Dart libs
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeService = ThemeServices();
  final languageService = LanguageService();
  final notificationService = NotificationService();

  await Future.wait([
    themeService.init(),
    languageService.init(),
    notificationService.init(),
  ]);

  // Set initial system UI styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

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
        ChangeNotifierProvider<NotificationService>.value(value: notificationService),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''),
              Locale('vi', ''),
            ],
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
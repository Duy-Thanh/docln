import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/SplashScreen.dart';
import 'package:provider/provider.dart';

// Services
import 'services/notification_service.dart';
import 'services/theme_services.dart';
import 'services/language_service.dart';

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

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: languageService),
        Provider<NotificationService>.value(value: notificationService),
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
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: themeService.themeMode,
          theme: themeService.getLightTheme(),
          darkTheme: themeService.getDarkTheme(),
          locale: languageService.currentLocale,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: themeService.textScaler),
              child: child!,
            );
          },
          home: SplashScreen(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_services.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/proxy_service.dart';
import '../services/dns_service.dart';
import '../services/settings_services.dart';
import '../services/crawler_service.dart';
import '../screens/custom_toast.dart';
import '../services/preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:http/http.dart' as http;
import '../services/performance_service.dart';
import '../services/update_service.dart';
import '../screens/widgets/update_dialog.dart';
import '../screens/WireGuardSettingsScreen.dart';
import '../screens/WarpSettingsScreen.dart';
import '../services/preferences_recovery_service.dart';
import 'package:file_picker/file_picker.dart';
import '../screens/wallpaper_colors_screen.dart';
import '../screens/ServerDiagnosticScreen.dart';
import '../services/server_management_service.dart';

// GridPainter class at the top level
class GridPainter extends CustomPainter {
  final Color color;

  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 30.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SettingsScreen extends StatefulWidget {
  final Function(bool hasChanges)? onSettingsChanged;

  const SettingsScreen({super.key, this.onSettingsChanged});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  final CrawlerService _crawlerService = CrawlerService();
  static const String _appVersion = 'Version: 2025.10.09';
  bool isDarkMode = false;
  String? currentServer;
  double textSize = 16.0;
  bool isNotificationsEnabled = true;
  String? selectedLanguage;
  bool isDataSaverEnabled = false;

  // Proxy settings
  bool isProxyEnabled = false;
  String proxyType = 'None';
  TextEditingController proxyAddressController = TextEditingController();
  TextEditingController proxyPortController = TextEditingController();
  TextEditingController proxyUsernameController = TextEditingController();
  TextEditingController proxyPasswordController = TextEditingController();

  // DNS settings
  bool isDnsEnabled = false;
  String dnsProvider = 'Default';
  TextEditingController customDnsController = TextEditingController();

  bool _hasUnsavedChanges = false;
  late AnimationController _animationController;

  // Initialize with default values
  late bool _initialDarkMode = false;
  late double _initialTextSize = 16.0;
  late bool _initialNotifications = true;
  late String? _initialLanguage = 'English';
  late bool _initialDataSaver = false;
  late String? _initialServer;

  // Initial proxy settings
  late bool _initialProxyEnabled = false;
  late String _initialProxyType = 'None';
  late String _initialProxyAddress = '';
  late String _initialProxyPort = '';
  late String _initialProxyUsername = '';
  late String _initialProxyPassword = '';

  // Initial DNS settings
  late bool _initialDnsEnabled = false;
  late String _initialDnsProvider = 'Default';
  late String _initialCustomDns = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Initialize settings from providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeService = Provider.of<ThemeServices>(context, listen: false);
      final languageService = Provider.of<LanguageService>(
        context,
        listen: false,
      );
      setState(() {
        isDarkMode = themeService.themeMode == ThemeMode.dark;
        selectedLanguage = languageService.currentLocale.languageCode;
      });
    });

    _loadSettings();
  }

  Future<void> _optimizeScreen() async {
    await PerformanceService.optimizeScreen('SettingsScreen');
  }

  @override
  void dispose() {
    _animationController.dispose();
    proxyAddressController.dispose();
    proxyPortController.dispose();
    proxyUsernameController.dispose();
    proxyPasswordController.dispose();
    customDnsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefsService = PreferencesService();
      await prefsService.initialize();

      final themeService = Provider.of<ThemeServices>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );

      // Check notification permission status
      final hasPermission = await notificationService.checkPermission();

      setState(() {
        isDarkMode = prefsService.getBool('darkMode', defaultValue: false);
        textSize = themeService.textSize.clamp(12.0, 24.0);
        // Only enable notifications if we have permission
        isNotificationsEnabled =
            hasPermission &&
            prefsService.getBool('isNotifications', defaultValue: true);
        selectedLanguage = prefsService.getString(
          'language',
          defaultValue: 'English',
        );
        isDataSaverEnabled = prefsService.getBool(
          'dataSaver',
          defaultValue: false,
        );

        _initialDarkMode = isDarkMode;
        _initialTextSize = textSize;
        _initialNotifications = isNotificationsEnabled;
        _initialLanguage = selectedLanguage;
        _initialDataSaver = isDataSaverEnabled;
      });

      await _loadCurrentServer();
      await _loadProxySettings();
      await _loadDnsSettings();
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        textSize = 16.0;
        _initialTextSize = 16.0;
        isNotificationsEnabled = false;
        _initialNotifications = false;
      });
    }
  }

  Future<void> _loadProxySettings() async {
    try {
      // Load proxy settings
      isProxyEnabled = await _settingsService.isProxyEnabled();
      proxyType = await _settingsService.getProxyType();
      proxyAddressController.text = await _settingsService.getProxyAddress();
      proxyPortController.text = await _settingsService.getProxyPort();
      proxyUsernameController.text = await _settingsService.getProxyUsername();
      proxyPasswordController.text = await _settingsService.getProxyPassword();

      // Store initial values
      _initialProxyEnabled = isProxyEnabled;
      _initialProxyType = proxyType;
      _initialProxyAddress = proxyAddressController.text;
      _initialProxyPort = proxyPortController.text;
      _initialProxyUsername = proxyUsernameController.text;
      _initialProxyPassword = proxyPasswordController.text;
    } catch (e) {
      print('Error loading proxy settings: $e');
    }
  }

  Future<void> _loadDnsSettings() async {
    try {
      // Load DNS settings
      isDnsEnabled = await _settingsService.isDnsEnabled();
      dnsProvider = await _settingsService.getDnsProvider();
      customDnsController.text = await _settingsService.getCustomDns();

      // Store initial values
      _initialDnsEnabled = isDnsEnabled;
      _initialDnsProvider = dnsProvider;
      _initialCustomDns = customDnsController.text;
    } catch (e) {
      print('Error loading DNS settings: $e');
    }
  }

  void _checkForChanges() {
    setState(() {
      _hasUnsavedChanges =
          isDarkMode != _initialDarkMode ||
          textSize != _initialTextSize ||
          isNotificationsEnabled != _initialNotifications ||
          selectedLanguage != _initialLanguage ||
          isDataSaverEnabled != _initialDataSaver ||
          currentServer != _initialServer ||
          isProxyEnabled != _initialProxyEnabled ||
          proxyType != _initialProxyType ||
          proxyAddressController.text != _initialProxyAddress ||
          proxyPortController.text != _initialProxyPort ||
          proxyUsernameController.text != _initialProxyUsername ||
          proxyPasswordController.text != _initialProxyPassword ||
          isDnsEnabled != _initialDnsEnabled ||
          dnsProvider != _initialDnsProvider ||
          customDnsController.text != _initialCustomDns;
    });
  }

  void _onSettingChanged(Function() change) {
    change();
    final hasChanges =
        isDarkMode != _initialDarkMode ||
        textSize != _initialTextSize ||
        isNotificationsEnabled != _initialNotifications ||
        selectedLanguage != _initialLanguage ||
        isDataSaverEnabled != _initialDataSaver ||
        currentServer != _initialServer ||
        isProxyEnabled != _initialProxyEnabled ||
        proxyType != _initialProxyType ||
        proxyAddressController.text != _initialProxyAddress ||
        proxyPortController.text != _initialProxyPort ||
        proxyUsernameController.text != _initialProxyUsername ||
        proxyPasswordController.text != _initialProxyPassword ||
        isDnsEnabled != _initialDnsEnabled ||
        dnsProvider != _initialDnsProvider ||
        customDnsController.text != _initialCustomDns;

    setState(() {
      _hasUnsavedChanges = hasChanges;
    });
    widget.onSettingsChanged?.call(hasChanges);
  }

  Future<void> _loadCurrentServer() async {
    final server = await _settingsService.getCurrentServer();
    setState(() {
      currentServer = server;
      _initialServer = server;
    });
  }

  Future<void> saveSettings() async {
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    try {
      final prefsService = PreferencesService();
      await prefsService.initialize();

      final themeService = Provider.of<ThemeServices>(context, listen: false);
      final languageService = Provider.of<LanguageService>(
        context,
        listen: false,
      );
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );
      final proxyService = ProxyService();
      final dnsService = DnsService();
      final serverManagement = Provider.of<ServerManagementService>(
        context,
        listen: false,
      );

      // Save all settings
      await Future.wait([
        prefsService.setBool('darkMode', isDarkMode),
        prefsService.setDouble('textSize', textSize),
        Future(() => themeService.setTextSize(textSize)),
        notificationService.setNotificationEnabled(isNotificationsEnabled),
        prefsService.setString('language', selectedLanguage ?? 'English'),
        prefsService.setBool('dataSaver', isDataSaverEnabled),
        serverManagement.setServer(currentServer ?? 'https://ln.hako.vn'),
        _settingsService.saveCurrentServer(currentServer ?? ''),

        // Save proxy settings
        _settingsService.setProxyEnabled(isProxyEnabled),
        _settingsService.setProxyType(proxyType),
        _settingsService.setProxyAddress(proxyAddressController.text),
        _settingsService.setProxyPort(proxyPortController.text),
        _settingsService.setProxyUsername(proxyUsernameController.text),
        _settingsService.setProxyPassword(proxyPasswordController.text),

        // Save DNS settings
        _settingsService.setDnsEnabled(isDnsEnabled),
        _settingsService.setDnsProvider(dnsProvider),
        _settingsService.setCustomDns(customDnsController.text),
      ]);

      // Update proxy, DNS, and crawler services with new settings
      await proxyService.updateProxySettings();
      await dnsService.updateDnsSettings();
      await _crawlerService.refreshSettings();

      // If notifications were just enabled, request permission
      if (isNotificationsEnabled && !_initialNotifications) {
        final granted = await notificationService.requestPermission();
        if (!granted) {
          setState(() {
            isNotificationsEnabled = false;
          });
          CustomToast.show(
            context,
            'Failed to enable notifications: Permission denied',
          );
          return;
        }

        // Show confirmation notification
        await notificationService.showNotification(
          title: 'Notifications Enabled',
          body:
              'You will now receive updates for new chapters and announcements',
        );
      }

      setState(() {
        _initialDarkMode = isDarkMode;
        _initialTextSize = textSize;
        _initialNotifications = isNotificationsEnabled;
        _initialLanguage = selectedLanguage;
        _initialDataSaver = isDataSaverEnabled;
        _initialServer = currentServer;

        // Update initial proxy settings
        _initialProxyEnabled = isProxyEnabled;
        _initialProxyType = proxyType;
        _initialProxyAddress = proxyAddressController.text;
        _initialProxyPort = proxyPortController.text;
        _initialProxyUsername = proxyUsernameController.text;
        _initialProxyPassword = proxyPasswordController.text;

        // Update initial DNS settings
        _initialDnsEnabled = isDnsEnabled;
        _initialDnsProvider = dnsProvider;
        _initialCustomDns = customDnsController.text;

        _hasUnsavedChanges = false;
      });

      // Update theme and language
      await themeService.setThemeMode(isDarkMode);
      if (selectedLanguage != null) {
        await languageService.setLanguage(selectedLanguage!);
      }

      CustomToast.show(context, 'Settings saved successfully');

      widget.onSettingsChanged?.call(false);
    } catch (e) {
      CustomToast.show(context, 'Failed to save settings: ${e.toString()}');
    }
  }

  void _revertSettings() {
    final themeService = Provider.of<ThemeServices>(context, listen: false);
    setState(() {
      textSize = _initialTextSize;
      isDarkMode = _initialDarkMode;
      isNotificationsEnabled = _initialNotifications;
      selectedLanguage = _initialLanguage;
      isDataSaverEnabled = _initialDataSaver;
      currentServer = _initialServer;

      // Revert proxy settings
      isProxyEnabled = _initialProxyEnabled;
      proxyType = _initialProxyType;
      proxyAddressController.text = _initialProxyAddress;
      proxyPortController.text = _initialProxyPort;
      proxyUsernameController.text = _initialProxyUsername;
      proxyPasswordController.text = _initialProxyPassword;

      // Revert DNS settings
      isDnsEnabled = _initialDnsEnabled;
      dnsProvider = _initialDnsProvider;
      customDnsController.text = _initialCustomDns;

      _hasUnsavedChanges = false;
    });
    // Reset the text size in ThemeService
    themeService.setTextSize(_initialTextSize);
    widget.onSettingsChanged?.call(false);
  }

  // Add this method to check for updates
  Future<void> _checkForUpdates() async {
    try {
      CustomToast.show(context, 'Checking for updates...');
      final updateInfo = await UpdateService.checkForUpdates();

      if (!mounted) return;

      if (updateInfo != null) {
        showDialog(
          context: context,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
      } else {
        CustomToast.show(context, 'You are using the latest version!');
      }
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, 'Error checking for updates: $e');
    }
  }

  // Change from void _revertSettings() to:
  void revertSettings() {
    _revertSettings();
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Show explanation dialog before requesting permission
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Enable Notifications'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Would you like to receive notifications for:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildNotificationBenefit(
                icon: Icons.new_releases,
                text: 'New chapter releases',
              ),
              _buildNotificationBenefit(
                icon: Icons.campaign,
                text: 'Important announcements',
              ),
              _buildNotificationBenefit(
                icon: Icons.update,
                text: 'App updates',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        return;
      }

      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );
      final granted = await notificationService.requestPermission();

      if (!granted) {
        if (!context.mounted) return;

        // Show settings guidance dialog if permission denied
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.notifications_off, color: Colors.grey),
                SizedBox(width: 8),
                Text('Permission Required'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'To receive notifications, you need to enable them in your device settings.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can change this anytime in your device settings.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Update the switch to reflect the actual state
                  _onSettingChanged(
                    () => setState(() => isNotificationsEnabled = false),
                  );
                },
                child: const Text('Maybe Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Update the switch to reflect the actual state
                  _onSettingChanged(
                    () => setState(() => isNotificationsEnabled = false),
                  );
                  // Open device settings
                  final notificationService = Provider.of<NotificationService>(
                    context,
                    listen: false,
                  );
                  notificationService.openSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // If we get here, either permissions were granted or we're turning notifications off
    _onSettingChanged(() {
      setState(() => isNotificationsEnabled = value);
    });
  }

  Widget _buildNotificationBenefit({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showTextSizeDialog() {
    double tempSize = textSize.clamp(12.0, 24.0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Text Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('A', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: tempSize,
                      min: 12.0,
                      max: 24.0,
                      divisions: 12,
                      label: tempSize.round().toString(),
                      onChanged: (value) {
                        setDialogState(() => tempSize = value);
                        final themeService = Provider.of<ThemeServices>(
                          context,
                          listen: false,
                        );
                        themeService.setTextSize(value); // Pass the actual size
                      },
                    ),
                  ),
                  const Text('A', style: TextStyle(fontSize: 24)),
                ],
              ),
              Text('Preview Text', style: TextStyle(fontSize: tempSize)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final themeService = Provider.of<ThemeServices>(
                  context,
                  listen: false,
                );
                themeService.setTextSize(_initialTextSize);
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _onSettingChanged(() => setState(() => textSize = tempSize));
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // Update the language bottom sheet to use the new _changeLanguage method
  void _showLanguageBottomSheet() {
    final languages = [
      'English',
      'Tiếng Việt',
      'Français',
      'Española',
      'Deutsch',
      'Italiana',
      'Nederlands',
      'Português',
      'Русский',
      '日本語',
      '한국인',
      '中国人',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Language',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  return ListTile(
                    leading: Radio<String>(
                      value: language,
                      groupValue: selectedLanguage,
                      onChanged: (value) async {
                        if (value != null) {
                          Navigator.pop(context);
                          await _changeLanguage(value);
                        }
                      },
                    ),
                    title: Text(language),
                    onTap: () async {
                      Navigator.pop(context);
                      await _changeLanguage(language);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'About Light Novel Reader',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                _appVersion,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '© 2024 - 2025 CyberDay Studios',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text(
                'Developed by nekkochan',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              const Text(
                'Light Novel Reader is a free and open-source light novel reader app that allows you to read light novels online for free',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Text(
                'This app is not affiliated with any of the websites it links to.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text(
                'This application is under heavy development. That means the application may contain bugs and errors. Please report any issues to the developer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showServerBottomSheet() {
    const servers = CrawlerService.servers; // Get servers from CrawlerService

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Server',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: servers.length,
                itemBuilder: (context, index) {
                  final server = servers[index];
                  final isSelected = server == currentServer;
                  return _buildServerListItem(server, isSelected);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerListItem(String server, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.dns_rounded,
          color: isSelected ? colorScheme.primary : colorScheme.outline,
        ),
      ),
      title: Text(
        server,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? colorScheme.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary)
          : null,
      onTap: () async {
        Navigator.pop(context);
        await _changeServer(server);
      },
    );
  }

  Future<void> _changeServer(String newServer) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Test server connection
      final response = await http
          .get(
            Uri.parse(newServer),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );

      // Pop loading dialog
      Navigator.pop(context);

      if (response.statusCode == 200) {
        _onSettingChanged(() {
          setState(() => currentServer = newServer);
        });
        CustomToast.show(context, 'Server changed successfully');
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      // Pop loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      CustomToast.show(context, 'Failed to connect to server: ${e.toString()}');
    }
  }

  Future<void> _changeLanguage(String newLanguage) async {
    try {
      _onSettingChanged(() async {
        setState(() => selectedLanguage = newLanguage);

        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        try {
          final languageService = Provider.of<LanguageService>(
            context,
            listen: false,
          );
          await languageService.setLanguage(newLanguage);

          // Pop loading dialog
          Navigator.pop(context);
          CustomToast.show(context, 'Language changed to $newLanguage');
        } catch (e) {
          // Pop loading dialog
          Navigator.pop(context);
          rethrow;
        }
      });
    } catch (e) {
      CustomToast.show(context, 'Failed to change language: ${e.toString()}');
      // Revert the change
      setState(() => selectedLanguage = _initialLanguage);
    }
  }

  Widget _buildServerOption(String server) {
    final isSelected = currentServer == server;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Radio<String>(
          value: server,
          groupValue: currentServer,
          onChanged: (String? value) async {
            // Update both services to keep them in sync
            final serverManagement = Provider.of<ServerManagementService>(
              context,
              listen: false,
            );
            await serverManagement.setServer(value!);
            await _settingsService.saveCurrentServer(value);
            _onSettingChanged(() => _loadCurrentServer());
            Navigator.pop(context);
          },
        ),
        title: Text(
          server,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? colorScheme.primary : null,
          ),
        ),
        onTap: () async {
          // Update both services to keep them in sync
          final serverManagement = Provider.of<ServerManagementService>(
            context,
            listen: false,
          );
          await serverManagement.setServer(server);
          await _settingsService.saveCurrentServer(server);
          _onSettingChanged(
            () => _loadCurrentServer(),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 24,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        Theme.of(context).colorScheme.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildModernSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }

  void _handleTextSizeChange(double newSize) {
    _onSettingChanged(() {
      setState(() => textSize = newSize);
    });
  }

  Widget _buildModernSliderTile(
    String title,
    String subtitle,
    IconData icon,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colorScheme.primary),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                const Text('A', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: value.clamp(12.0, 24.0),
                    min: 12.0,
                    max: 24.0,
                    divisions: 12,
                    label: value.round().toString(),
                    onChanged: (newValue) {
                      // Only update the state, don't update ThemeService yet
                      onChanged(newValue);
                      // Preview the change
                      final themeService = Provider.of<ThemeServices>(
                        context,
                        listen: false,
                      );
                      themeService.previewTextSize(newValue);
                    },
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 24)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Preview Text', style: TextStyle(fontSize: value)),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperThemeSettings() {
    final themeService = Provider.of<ThemeServices>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.palette_rounded, color: colorScheme.primary),
          ),
          title: const Text(
            'Material You from Wallpaper',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            themeService.hasWallpaperColors
                ? (themeService
                          .wallpaperThemeService
                          .extractor
                          .isUsingSystemWallpaper
                      ? 'Using system wallpaper colors'
                      : 'Using custom image colors')
                : 'Extract colors from wallpaper',
          ),
          trailing: Switch.adaptive(
            value: themeService.useWallpaperColors,
            onChanged: themeService.hasWallpaperColors
                ? (value) {
                    _onSettingChanged(() async {
                      await themeService.setUseWallpaperColors(value);
                      setState(() {});
                    });
                  }
                : null,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    CustomToast.show(
                      context,
                      'Extracting from system wallpaper...',
                    );
                    final result = await themeService
                        .updateWallpaperColorsFromSystem();
                    if (result) {
                      CustomToast.show(
                        context,
                        'System wallpaper colors extracted!',
                      );
                      setState(() {});
                    } else {
                      CustomToast.show(
                        context,
                        'System wallpaper not supported on this device',
                      );
                    }
                  },
                  icon: const Icon(Icons.wallpaper, size: 18),
                  label: const Text('System', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    CustomToast.show(context, 'Selecting wallpaper...');
                    final result = await themeService.updateWallpaperColors();
                    if (result) {
                      CustomToast.show(
                        context,
                        'Colors extracted successfully!',
                      );
                      setState(() {});
                    } else {
                      CustomToast.show(context, 'Failed to extract colors');
                    }
                  },
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text(
                    'Pick Image',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (themeService.hasWallpaperColors) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    _onSettingChanged(() {
                      themeService.clearWallpaperColors();
                      setState(() {});
                    });
                    CustomToast.show(context, 'Wallpaper colors cleared');
                  },
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear wallpaper colors',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (themeService.hasWallpaperColors)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: themeService.getWallpaperColorPreview().map((color) {
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.horizontal(
                          left:
                              color ==
                                  themeService.getWallpaperColorPreview().first
                              ? const Radius.circular(12)
                              : Radius.zero,
                          right:
                              color ==
                                  themeService.getWallpaperColorPreview().last
                              ? const Radius.circular(12)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        if (themeService.hasWallpaperColors)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WallpaperColorsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.preview, size: 18),
              label: const Text('View Color Details'),
            ),
          ),
      ],
    );
  }

  Widget _buildServerTile() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.dns_rounded, color: colorScheme.primary),
      ),
      title: const Text(
        'Current Server',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(currentServer ?? 'No server selected'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showServerBottomSheet(),
    );
  }

  Widget _buildServerDiagnosticButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ServerDiagnosticScreen(),
            ),
          );
        },
        icon: const Icon(Icons.healing, size: 18),
        label: const Text('Fix Server Issues'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildLanguageTile() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.language_rounded, color: colorScheme.primary),
      ),
      title: const Text(
        'Language',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(selectedLanguage ?? 'English'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showLanguageBottomSheet(),
    );
  }

  Widget _buildAboutTile() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('About App'),
          subtitle: const Text(_appVersion),
          onTap: () {
            _showAboutDialog();
          },
        ),
        ListTile(
          leading: const Icon(Icons.system_update_rounded),
          title: const Text('Check for Updates'),
          subtitle: const Text('Check if a new version is available'),
          onTap: _checkForUpdates,
        ),
        ListTile(
          leading: const Icon(Icons.code_rounded),
          title: const Text('Source Code'),
          subtitle: const Text('View on GitHub'),
          onTap: () async {
            final uri = Uri.parse('https://github.com/Duy-Thanh/docln');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.library_books_rounded),
          title: const Text('Open Source Licenses'),
          subtitle: const Text(
            'View open source licenses and third-party notices',
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Theme(
                  data: Theme.of(context).copyWith(
                    appBarTheme: AppBarTheme(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      elevation: 0,
                    ),
                    cardTheme: CardThemeData(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  child: LicensePage(
                    applicationName: 'Light Novel Reader',
                    applicationVersion: _appVersion,
                    applicationIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 36,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    applicationLegalese:
                        '© 2025 Nekkochan\n\n'
                        'This application is built with Flutter and uses '
                        'various open source libraries. We are grateful to '
                        'the open source community for their contributions.',
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Add proxy settings section
  Widget _buildProxySection() {
    return _buildSection('Proxy Settings', [
      _buildModernSwitchTile(
        'Enable Proxy',
        'Use proxy for accessing blocked content',
        Icons.security_rounded,
        isProxyEnabled,
        (value) =>
            _onSettingChanged(() => setState(() => isProxyEnabled = value)),
      ),
      if (isProxyEnabled) ...[
        _buildProxyTypeTile(),
        _buildProxyConfigurationTile(),
        _buildProxyInfoBanner(),
      ],
    ]);
  }

  Widget _buildProxyTypeTile() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.dns_rounded, color: colorScheme.primary),
      ),
      title: const Text(
        'Proxy Type',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(proxyType),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showProxyTypeBottomSheet(),
    );
  }

  Widget _buildProxyConfigurationTile() {
    bool isCustom = proxyType == 'Custom';
    final colorScheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.settings_rounded, color: colorScheme.primary),
      ),
      title: const Text(
        'Proxy Configuration',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${proxyAddressController.text}:${proxyPortController.text}',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              TextField(
                controller: proxyAddressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter proxy address (e.g., 1.1.1.1)',
                  border: OutlineInputBorder(),
                ),
                enabled: isCustom,
                onChanged: (_) => _onSettingChanged(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proxyPortController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: 'Enter proxy port (e.g., 80)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: isCustom,
                onChanged: (_) => _onSettingChanged(() {}),
              ),
              const SizedBox(height: 12),
              if (isCustom) ...[
                TextField(
                  controller: proxyUsernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username (Optional)',
                    hintText: 'Enter username if required',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _onSettingChanged(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proxyPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Password (Optional)',
                    hintText: 'Enter password if required',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (_) => _onSettingChanged(() {}),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _testProxyConnection,
                icon: const Icon(Icons.network_check),
                label: const Text('Test Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showProxyTypeBottomSheet() {
    final presets = SettingsService.proxyPresets.keys.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Proxy Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  return ListTile(
                    leading: Radio<String>(
                      value: preset,
                      groupValue: proxyType,
                      onChanged: (value) {
                        Navigator.pop(context);
                        _updateProxyType(value!);
                      },
                    ),
                    title: Text(preset),
                    subtitle: _getProxyDescription(preset),
                    onTap: () {
                      Navigator.pop(context);
                      _updateProxyType(preset);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getProxyDescription(String type) {
    switch (type) {
      case 'None':
        return const Text('No proxy (direct connection)');
      case 'Open Proxy 1':
        return const Text('Public HTTP proxy - 91.92.209.35:3128');
      case 'Open Proxy 2':
        return const Text('Public HTTP proxy - 45.173.6.5:999');
      case 'Open Proxy 3':
        return const Text('Public HTTP proxy - 103.151.40.25:80');
      case 'HTTP SOCKS5':
        return const Text('SOCKS5 proxy - 216.137.184.253:80');
      case 'Custom':
        return const Text('Configure your own proxy settings');
      default:
        return const Text('');
    }
  }

  void _updateProxyType(String type) {
    _onSettingChanged(() {
      setState(() {
        proxyType = type;

        // Update fields based on preset
        if (type != 'Custom') {
          final preset = SettingsService.proxyPresets[type];
          if (preset != null) {
            proxyAddressController.text = preset['address'] as String;
            proxyPortController.text = preset['port'] as String;
          }
        }
      });
    });
  }

  Future<void> _testProxyConnection() async {
    if (!isProxyEnabled) {
      CustomToast.show(context, 'Please enable proxy first');
      return;
    }

    if (proxyAddressController.text.isEmpty ||
        proxyPortController.text.isEmpty) {
      CustomToast.show(context, 'Proxy address and port are required');
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Save current settings to a temporary proxy service
      await _settingsService.setProxyEnabled(true);
      await _settingsService.setProxyType(proxyType);
      await _settingsService.setProxyAddress(proxyAddressController.text);
      await _settingsService.setProxyPort(proxyPortController.text);
      await _settingsService.setProxyUsername(proxyUsernameController.text);
      await _settingsService.setProxyPassword(proxyPasswordController.text);

      final proxyService = ProxyService();
      await proxyService.updateProxySettings();

      // Test connection to a reliable server
      final response = await proxyService.get(
        Uri.parse('https://www.google.com'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        },
      );

      // Pop loading dialog
      Navigator.pop(context);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        CustomToast.show(context, 'Proxy connection successful! ✅');
      } else {
        CustomToast.show(
          context,
          'Connection failed: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      // Pop loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      CustomToast.show(context, 'Connection failed: ${e.toString()}');
    }
  }

  // Add a helper widget to display proxy information
  Widget _buildProxyInfoBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'About Proxies',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Public proxies may be unreliable or slow. They can help bypass '
            'network restrictions but may not always work.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            'If one proxy doesn\'t work, try another or configure your own. '
            'The app will automatically fall back to direct connection if the proxy fails.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Add DNS settings section
  Widget _buildDnsSection() {
    return _buildSection('DNS Settings', [
      _buildModernSwitchTile(
        'Enable Custom DNS',
        'Override system DNS settings (requires manual configuration)',
        Icons.dns_rounded,
        isDnsEnabled,
        (value) =>
            _onSettingChanged(() => setState(() => isDnsEnabled = value)),
      ),
      if (isDnsEnabled) ...[
        _buildDnsProviderTile(),
        _buildDnsConfigurationTile(),
        _buildDnsInfoBanner(),
      ],
    ]);
  }

  // Add WireGuard settings section
  Widget _buildWireGuardSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection('WireGuard VPN', [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.vpn_lock, color: colorScheme.secondary),
        ),
        title: const Text(
          'WireGuard Settings',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Configure secure VPN tunnel for app traffic'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WireGuardSettingsScreen(),
            ),
          );
        },
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.secondary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.secondary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'About WireGuard',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'WireGuard creates an encrypted VPN tunnel specifically for app traffic. '
              'It provides stronger protection than proxies and can bypass most network restrictions.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    ]);
  }

  // Add Cloudflare WARP settings section
  Widget _buildWarpSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection('Cloudflare WARP', [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.shield, color: colorScheme.tertiary),
        ),
        title: const Text(
          'WARP Settings',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Route ALL app traffic through Cloudflare WARP'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WarpSettingsScreen()),
          );
        },
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.tertiary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.tertiary, size: 18),
                SizedBox(width: 8),
                Text(
                  'About Cloudflare WARP',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            const Text(
              'WARP routes ALL app traffic through Cloudflare\'s global network using WireGuard protocol. '
              'It\'s faster, more reliable, and perfect for bypassing website restrictions. '
              'When website blocks your app, use WARP to restore access!',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildDnsProviderTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.public, color: Colors.green),
      ),
      title: const Text(
        'DNS Provider',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(dnsProvider),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showDnsProviderBottomSheet(),
    );
  }

  Widget _buildDnsConfigurationTile() {
    return dnsProvider == 'Custom'
        ? ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            title: const Text(
              'DNS Configuration',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              customDnsController.text.isEmpty
                  ? 'No custom DNS set'
                  : customDnsController.text,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: customDnsController,
                      decoration: const InputDecoration(
                        labelText: 'Custom DNS',
                        hintText: 'Enter DNS server (e.g., 1.1.1.1)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _onSettingChanged(() {}),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showDnsInstructions,
                      icon: const Icon(Icons.help_outline),
                      label: const Text('How to Configure DNS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            title: const Text(
              'DNS Configuration',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(_getDnsServerForProvider()),
            trailing: ElevatedButton.icon(
              onPressed: _showDnsInstructions,
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('How to Configure'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: const Size(120, 36),
              ),
            ),
          );
  }

  String _getDnsServerForProvider() {
    if (dnsProvider == 'Default') {
      return 'System default';
    } else if (dnsProvider == 'Custom') {
      return customDnsController.text.isEmpty
          ? 'Not set'
          : customDnsController.text;
    } else {
      return SettingsService.dnsProviders[dnsProvider] ?? 'Unknown';
    }
  }

  void _showDnsProviderBottomSheet() {
    final providers = SettingsService.dnsProviders.keys.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select DNS Provider',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: providers.length,
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  return ListTile(
                    leading: Radio<String>(
                      value: provider,
                      groupValue: dnsProvider,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        Navigator.pop(context);
                        _updateDnsProvider(value!);
                      },
                    ),
                    title: Text(provider),
                    subtitle: _getDnsDescription(provider),
                    onTap: () {
                      Navigator.pop(context);
                      _updateDnsProvider(provider);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getDnsDescription(String provider) {
    switch (provider) {
      case 'Default':
        return const Text('Use system default DNS settings');
      case 'Cloudflare':
        return const Text('Fast and private DNS (1.1.1.1)');
      case 'Cloudflare Secondary':
        return const Text('Alternate Cloudflare DNS (1.0.0.1)');
      case 'Google':
        return const Text('Google public DNS (8.8.8.8)');
      case 'Google Secondary':
        return const Text('Alternate Google DNS (8.8.4.4)');
      case 'OpenDNS':
        return const Text('Cisco OpenDNS (208.67.222.222)');
      case 'OpenDNS Secondary':
        return const Text('Alternate OpenDNS (208.67.220.220)');
      case 'Quad9':
        return const Text('Security-focused DNS (9.9.9.9)');
      case 'Custom':
        return const Text('Configure your own DNS server');
      default:
        return const Text('');
    }
  }

  void _updateDnsProvider(String newProvider) {
    _onSettingChanged(() {
      setState(() {
        dnsProvider = newProvider;
      });
    });
  }

  void _showDnsInstructions() {
    final dnsService = DnsService();
    final instructions = dnsService.getDnsSetupInstructions();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('DNS Configuration Instructions'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(instructions),
              const SizedBox(height: 16),
              const Text(
                'Note: The app cannot change system DNS settings directly. '
                'You need to configure DNS in your device settings.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              const Text(
                'After changing DNS settings in your device, come back to the app and enable DNS usage here '
                'to help the app use fallback servers optimized for your DNS settings.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Add a helper widget to display DNS information
  Widget _buildDnsInfoBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text(
                'About DNS',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'DNS (Domain Name System) translates domain names to IP addresses. '
            'Changing your DNS can help improve security, privacy, and sometimes bypass basic content restrictions.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            'Unlike a proxy, DNS changes affect your entire device, not just this app. '
            'The app cannot change DNS directly - you must configure it in your device settings.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Build backup and recovery section
  Widget _buildBackupSection() {
    return _buildSection('Data Backup & Recovery', [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.backup_rounded, color: Colors.amber),
        ),
        title: const Text(
          'Backup Preferences',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Save current settings to a backup file'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showBackupDialog(),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restore_rounded, color: Colors.amber),
        ),
        title: const Text(
          'Restore from Backup',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Restore settings from a previous backup'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showRestoreDialog(),
      ),
      const Divider(),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.ios_share_rounded, color: Colors.green),
        ),
        title: const Text(
          'Export Preferences',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Export settings to share with other devices'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _exportPreferences(),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.download_rounded, color: Colors.green),
        ),
        title: const Text(
          'Import Preferences',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Import settings from exported file'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _importPreferences(),
      ),
      const Divider(),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.healing_rounded, color: Colors.red),
        ),
        title: const Text(
          'Repair Preferences',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Fix corrupted preferences (if having issues)'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _repairPreferences(),
      ),
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text(
                  'About Backup & Recovery',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'The app now uses SQLite for preferences storage, which is more reliable and less prone to corruption than the previous system.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Automatic backups are created every 6 hours. Multiple backup formats are supported, including SQL database backups and JSON exports.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'If the app crashes or shows blank screens, try the "Repair Preferences" option to fix potential corruption issues.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    ]);
  }

  // Show backup dialog
  void _showBackupDialog() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Create backup
      final recoveryService = PreferencesRecoveryService();
      final success = await recoveryService.backupPreferences();

      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      // Show result dialog
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Backup Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your preferences have been successfully backed up.'),
                SizedBox(height: 16),
                Text(
                  'The backup includes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _buildBackupInfoItem(
                  'Theme and appearance settings',
                  Icons.color_lens,
                ),
                _buildBackupInfoItem('Language preferences', Icons.language),
                _buildBackupInfoItem(
                  'Network and proxy settings',
                  Icons.router,
                ),
                _buildBackupInfoItem(
                  'All other app configurations',
                  Icons.settings,
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        CustomToast.show(
          context,
          'Failed to create backup',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      // Dismiss loading indicator if showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      CustomToast.show(
        context,
        'Error creating backup: $e',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Widget _buildBackupInfoItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  // Show restore dialog
  void _showRestoreDialog() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get available backups
      final recoveryService = PreferencesRecoveryService();
      final backups = await recoveryService.getAvailableBackups();

      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      if (backups.isEmpty) {
        CustomToast.show(
          context,
          'No backups found',
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Show backup list in bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Backup to Restore',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Choose a backup from the list below. Backups are ordered from newest to oldest.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: backups.length,
                  itemBuilder: (context, index) {
                    final backup = backups[index];
                    final timestamp = DateTime.parse(
                      backup['timestamp'] as String,
                    );
                    final formattedDate =
                        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

                    final type = backup['type'] as String;
                    final format = backup['format'] as String;

                    IconData backupIcon;
                    Color backupColor;

                    if (format == 'SQLite') {
                      backupIcon = Icons.storage;
                      backupColor = Colors.purple;
                    } else if (type == 'sqlite') {
                      backupIcon = Icons.backup;
                      backupColor = Colors.blue;
                    } else {
                      backupIcon = Icons.restore;
                      backupColor = Colors.amber;
                    }

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: backupColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(backupIcon, color: backupColor),
                      ),
                      title: Text(
                        'Backup from $formattedDate',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Type: ${format} ${type == "legacy" ? "(Legacy)" : ""} • Size: ${(backup['size'] as int) ~/ 1024} KB',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmAndRestoreBackup(
                          backup['path'] as String,
                          format,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Dismiss loading indicator if showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      CustomToast.show(
        context,
        'Error loading backups: $e',
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Confirm and restore backup
  void _confirmAndRestoreBackup(String backupPath, String backupFormat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Restore Backup'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will replace all your current settings with the selected backup.',
            ),
            SizedBox(height: 12),
            Text(
              'Backup Type: $backupFormat',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Text(
              'Are you sure you want to continue?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreBackup(backupPath);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  // Restore from backup
  void _restoreBackup(String backupPath) async {
    try {
      // Show loading indicator with more detailed steps
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Restoring Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while your settings are being restored...'),
              SizedBox(height: 8),
              Text(
                'This may take a moment. Do not close the app.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      final recoveryService = PreferencesRecoveryService();
      final success = await recoveryService.restoreFromBackup(
        backupPath,
        context,
      );

      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      if (success) {
        // Reload settings
        await _loadSettings();

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Restore Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your preferences have been successfully restored from backup.',
                ),
                SizedBox(height: 12),
                Text(
                  'The following settings have been restored:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                _buildBackupInfoItem(
                  'Theme and appearance settings',
                  Icons.color_lens,
                ),
                _buildBackupInfoItem('Language preferences', Icons.language),
                _buildBackupInfoItem(
                  'Network and proxy settings',
                  Icons.router,
                ),
                _buildBackupInfoItem(
                  'All other app configurations',
                  Icons.settings,
                ),
                SizedBox(height: 12),
                Text(
                  'It\'s recommended to restart the app for all changes to take full effect.',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Dismiss loading indicator if showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      CustomToast.show(
        context,
        'Error restoring backup: $e',
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Export preferences
  void _exportPreferences() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final recoveryService = PreferencesRecoveryService();
      final exportPath = await recoveryService.createExportFile();

      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      if (exportPath != null) {
        // Show success dialog with export details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Export Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your preferences have been successfully exported.'),
                SizedBox(height: 12),
                Text(
                  'File location:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  exportPath,
                  style: TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
                Text('Would you like to share this file?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  // Share the file
                  await Share.shareXFiles(
                    [XFile(exportPath)],
                    subject: 'DocLN Preferences Export',
                    text: 'DocLN Preferences Export',
                  );
                },
                icon: Icon(Icons.share),
                label: Text('Share'),
              ),
            ],
          ),
        );
      } else {
        CustomToast.show(
          context,
          'Failed to create export file',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      // Dismiss loading indicator if showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      CustomToast.show(
        context,
        'Error exporting preferences: $e',
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Import preferences
  void _importPreferences() async {
    try {
      // Show info dialog first
      bool? shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Import Preferences'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You can import preferences that were previously exported from this app.',
              ),
              SizedBox(height: 12),
              Text(
                'This will replace all your current settings with the imported file.',
              ),
              SizedBox(height: 12),
              Text(
                'Make sure the file is a valid preferences export file.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Continue'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;

      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;

      // Show confirmation dialog
      if (!mounted) return;

      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Confirm Import'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected file:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(filePath.split('/').last, style: TextStyle(fontSize: 14)),
              SizedBox(height: 16),
              Text(
                'This will replace ALL your current settings with the imported file. This cannot be undone.',
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 12),
              Text('Are you sure you want to continue?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final recoveryService = PreferencesRecoveryService();
      final success = await recoveryService.importFromFile(filePath, context);

      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      if (success) {
        // Reload settings
        await _loadSettings();

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Import Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your preferences have been successfully imported.'),
                SizedBox(height: 12),
                Text(
                  'It\'s recommended to restart the app for all changes to take full effect.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Dismiss loading indicator if showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      CustomToast.show(
        context,
        'Failed to import preferences: $e',
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Repair preferences
  void _repairPreferences() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.healing, color: Colors.red),
            SizedBox(width: 8),
            Text('Repair Preferences'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will attempt to repair corrupted preferences. Use this if you\'re experiencing:',
            ),
            SizedBox(height: 12),
            _buildRepairInfoItem('Crash after opening webview'),
            _buildRepairInfoItem('Settings not saving properly'),
            _buildRepairInfoItem('App freezing or showing blank screens'),
            _buildRepairInfoItem('Other unexpected behavior'),
            SizedBox(height: 16),
            Text(
              'Note: A backup will be created before attempting repair.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
            SizedBox(height: 4),
            Text(
              'Continue with repair?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: Text('Repairing Preferences'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Please wait...'),
                      SizedBox(height: 8),
                      Text(
                        'We\'re checking for issues and attempting to fix them.',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );

              final recoveryService = PreferencesRecoveryService();
              final success = await recoveryService.recoverPreferences(context);

              // Dismiss loading indicator
              if (mounted) Navigator.pop(context);

              if (!mounted) return;

              if (success) {
                // Reload settings
                await _loadSettings();

                // Show success message
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Repair Successful'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preferences repair completed successfully.'),
                        SizedBox(height: 12),
                        Text(
                          'It\'s recommended to restart the app for all changes to take full effect.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Repair'),
          ),
        ],
      ),
    );
  }

  Widget _buildRepairInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, dynamic result) async {
        if (!_hasUnsavedChanges) {
          return;
        }

        final bool shouldPop =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('Unsaved Changes'),
                content: const Text(
                  'You have unsaved changes. Do you want to save them before leaving?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _revertSettings(); // Add this line
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Discard'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _saveSettings();
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Save'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ) ??
            false;

        if (shouldPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              stretch: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).primaryTextTheme.titleLarge?.color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_hasUnsavedChanges) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Unsaved',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.darken,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade800,
                              Colors.purple.shade500,
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _animationController.value * 2 * 3.14159,
                          child: CustomPaint(
                            painter: GridPainter(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildQuickActionCard(
                          icon: Icons.dark_mode_rounded,
                          title: 'Theme',
                          subtitle: isDarkMode ? 'Dark Mode' : 'Light Mode',
                          onTap: () => _onSettingChanged(
                            () => setState(() => isDarkMode = !isDarkMode),
                          ),
                        ),
                        _buildQuickActionCard(
                          icon: Icons.text_fields_rounded,
                          title: 'Text Size',
                          subtitle: '${textSize.round()}',
                          onTap: () => _showTextSizeDialog(),
                        ),
                        _buildQuickActionCard(
                          icon: Icons.language_rounded,
                          title: 'Language',
                          subtitle: selectedLanguage ?? 'English',
                          onTap: () => _showLanguageBottomSheet(),
                        ),
                        _buildQuickActionCard(
                          icon: Icons.dns_rounded,
                          title: 'Server',
                          subtitle: currentServer ?? 'Not Selected',
                          onTap: () => _showServerBottomSheet(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                _buildSection('Appearance', [
                  _buildModernSwitchTile(
                    'Dark Mode',
                    'Switch between light and dark theme',
                    Icons.dark_mode_rounded,
                    isDarkMode,
                    (value) => _onSettingChanged(
                      () => setState(() => isDarkMode = value),
                    ),
                  ),
                  _buildModernSliderTile(
                    'Text Size',
                    'Adjust the size of text in the app',
                    Icons.text_fields_rounded,
                    textSize,
                    (value) {
                      _onSettingChanged(() {
                        setState(() => textSize = value);
                      });
                    },
                  ),
                  _buildWallpaperThemeSettings(),
                ]),
                _buildSection('Server Settings', [
                  _buildServerTile(),
                  _buildServerDiagnosticButton(),
                  _buildModernSwitchTile(
                    'Data Saver',
                    'Reduce data usage when loading content',
                    Icons.data_usage_rounded,
                    isDataSaverEnabled,
                    (value) => _onSettingChanged(
                      () => setState(() => isDataSaverEnabled = value),
                    ),
                  ),
                ]),
                _buildProxySection(),
                _buildWireGuardSection(),
                _buildWarpSection(),
                _buildDnsSection(),
                _buildBackupSection(),
                _buildSection('Notifications', [
                  _buildModernSwitchTile(
                    'Push Notifications',
                    'Receive notification for new chapter releases, application updates and announcements',
                    Icons.notifications_rounded,
                    isNotificationsEnabled,
                    (value) => _toggleNotifications(value),
                  ),
                ]),
                _buildSection('Language', [_buildLanguageTile()]),
                _buildSection('About', [_buildAboutTile()]),
                const SizedBox(height: 80), // Space for FAB
              ]),
            ),
          ],
        ),
        floatingActionButton: _hasUnsavedChanges
            ? Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: _saveSettings,
                  elevation: 0,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  icon: Icon(
                    Icons.save_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  label: Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // Build the account section
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} '
          '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
    }
  }

  // Ensure two digits for formatting
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  // Get the last sync time
}

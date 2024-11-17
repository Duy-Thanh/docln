import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_services.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import 'package:http/http.dart' as http;
import '../services/crawler_service.dart';
import 'dart:async'; // For TimeoutException
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../services/settings_services.dart';
import '../screens/custom_toast.dart';

// GridPainter class at the top level
class GridPainter extends CustomPainter {
  final Color color;
  
  GridPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
      
    final spacing = 30.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  bool isDarkMode = false;
  String? currentServer;
  double textSize = 16.0;
  bool isNotificationsEnabled = true;
  String? selectedLanguage;
  bool isDataSaverEnabled = false;

  bool _hasUnsavedChanges = false;
  late AnimationController _animationController;
  
  // Initialize with default values
  late bool _initialDarkMode = false;
  late double _initialTextSize = 16.0;
  late bool _initialNotifications = true;
  late String? _initialLanguage = 'English';
  late bool _initialDataSaver = false;
  late String? _initialServer = null;

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
      final languageService = Provider.of<LanguageService>(context, listen: false);
      setState(() {
        isDarkMode = themeService.themeMode == ThemeMode.dark;
        selectedLanguage = languageService.currentLocale.languageCode;
      });
    });

    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeService = Provider.of<ThemeServices>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      
      // Check notification permission status
      final hasPermission = await notificationService.checkPermission();
      
      setState(() {
        isDarkMode = prefs.getBool('darkMode') ?? false;
        textSize = themeService.textSize.clamp(12.0, 24.0);
        // Only enable notifications if we have permission
        isNotificationsEnabled = hasPermission && (prefs.getBool('isNotifications') ?? true);
        selectedLanguage = prefs.getString('language') ?? 'English';
        isDataSaverEnabled = prefs.getBool('dataSaver') ?? false;

        _initialDarkMode = isDarkMode;
        _initialTextSize = textSize;
        _initialNotifications = isNotificationsEnabled;
        _initialLanguage = selectedLanguage;
        _initialDataSaver = isDataSaverEnabled;
      });

      await _loadCurrentServer();
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

  void _checkForChanges() {
    setState(() {
      _hasUnsavedChanges = 
        isDarkMode != _initialDarkMode ||
        textSize != _initialTextSize ||
        isNotificationsEnabled != _initialNotifications ||
        selectedLanguage != _initialLanguage ||
        isDataSaverEnabled != _initialDataSaver ||
        currentServer != _initialServer;
    });
  }

  void _onSettingChanged(Function() change) {
    change();
    _checkForChanges();
  }

  Future<void> _loadCurrentServer() async {
    final server = await _settingsService.getCurrentServer();
    setState(() {
      currentServer = server;
      _initialServer = server;
    });
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeService = Provider.of<ThemeServices>(context, listen: false);
      final languageService = Provider.of<LanguageService>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);

      // Save all settings
      await Future.wait([
        prefs.setBool('darkMode', isDarkMode),
        prefs.setDouble('textSize', textSize),
        notificationService.setNotificationEnabled(isNotificationsEnabled),
        prefs.setString('language', selectedLanguage ?? 'English'),
        prefs.setBool('dataSaver', isDataSaverEnabled),
        _settingsService.saveCurrentServer(currentServer ?? ''),
      ]);

      // If notifications were just enabled, request permission
      if (isNotificationsEnabled && !_initialNotifications) {
        final granted = await notificationService.requestPermission();
        if (!granted) {
          setState(() {
            isNotificationsEnabled = false;
          });
          CustomToast.show(context, 'Failed to enable notifications: Permission denied');
          return;
        }
        
        // Show confirmation notification
        await notificationService.showNotification(
          title: 'Notifications Enabled',
          body: 'You will now receive updates for new chapters and announcements',
        );
      }
      
      setState(() {
        _initialDarkMode = isDarkMode;
        _initialTextSize = textSize;
        _initialNotifications = isNotificationsEnabled;
        _initialLanguage = selectedLanguage;
        _initialDataSaver = isDataSaverEnabled;
        _initialServer = currentServer;
        _hasUnsavedChanges = false;
      });

      // Update theme and language
      await themeService.setThemeMode(isDarkMode);
      if (selectedLanguage != null) {
        await languageService.setLanguage(selectedLanguage!);
      }

      CustomToast.show(context, 'Settings saved successfully');
    } catch (e) {
      CustomToast.show(context, 'Failed to save settings: ${e.toString()}');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Show explanation dialog before requesting permission
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue),
              SizedBox(width: 8),
              Text('Enable Notifications'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Would you like to receive notifications for:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
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
              child: Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Enable'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        return;
      }

      final notificationService = Provider.of<NotificationService>(context, listen: false);
      final granted = await notificationService.requestPermission();
      
      if (!granted) {
        if (!context.mounted) return;
        
        // Show settings guidance dialog if permission denied
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.notifications_off, color: Colors.grey),
                SizedBox(width: 8),
                Text('Permission Required'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'To receive notifications, you need to enable them in your device settings.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'You can change this anytime in your device settings.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Update the switch to reflect the actual state
                  _onSettingChanged(() => setState(() => isNotificationsEnabled = false));
                },
                child: Text('Maybe Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Update the switch to reflect the actual state
                  _onSettingChanged(() => setState(() => isNotificationsEnabled = false));
                  // Open device settings
                  final notificationService = Provider.of<NotificationService>(context, listen: false);
                  notificationService.openSettings();
                },
                child: Text('Open Settings'),
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
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
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
          title: Text('Text Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('A', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: tempSize,
                      min: 12.0,
                      max: 24.0,
                      divisions: 12,
                      label: tempSize.round().toString(),
                      onChanged: (value) {
                        setDialogState(() => tempSize = value);
                        final themeService = Provider.of<ThemeServices>(context, listen: false);
                        themeService.setTextSize(value); // Pass the actual size
                      },
                    ),
                  ),
                  Text('A', style: TextStyle(fontSize: 24)),
                ],
              ),
              Text('Preview Text', style: TextStyle(fontSize: tempSize)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final themeService = Provider.of<ThemeServices>(context, listen: false);
                themeService.setTextSize(_initialTextSize);
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _onSettingChanged(() => setState(() => textSize = tempSize));
                Navigator.pop(context);
              },
              child: Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // Update the language bottom sheet to use the new _changeLanguage method
  void _showLanguageBottomSheet() {
    final languages = ['English', 'Tiếng Việt', 'Français', 'Española', 'Deutsch', 
                      'Italiana', 'Nederlands', 'Português', 'Русский', '日本語', 
                      '한국인', '中国人'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
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
              margin: EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
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
        title: Text('About Light Novel Reader', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.menu_book_rounded, size: 64, color: Colors.blue),
              ),
              SizedBox(height: 24),
              Text('Version 1.0.0.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('© 2024 CyberDay Studios',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              Text('Developed by nekkochan',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              Text(
                'Light Novel Reader is a free and open-source light novel reader app that allows you to read light novels online for free',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 24),
              Text(
                'This app is not affiliated with any of the websites it links to.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
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
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showServerBottomSheet() {
    final servers = CrawlerService.servers; // Get servers from CrawlerService
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
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
              margin: EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
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
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.dns_rounded,
          color: isSelected ? Colors.blue : Colors.grey,
        ),
      ),
      title: Text(
        server,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.blue : null,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Colors.blue) : null,
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
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Test server connection
      final response = await http.get(
        Uri.parse(newServer),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36'
        },
      ).timeout(
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
          builder: (context) => Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          final languageService = Provider.of<LanguageService>(context, listen: false);
          await languageService.setLanguage(newLanguage);
          
          // Pop loading dialog
          Navigator.pop(context);
          CustomToast.show(context, 'Language changed to $newLanguage');
        } catch (e) {
          // Pop loading dialog
          Navigator.pop(context);
          throw e;
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
    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Radio<String>(
          value: server,
          groupValue: currentServer,
          onChanged: (String? value) async {
            await _settingsService.saveCurrentServer(value!);
            _onSettingChanged(() => _loadCurrentServer());
            Navigator.pop(context);
          },
        ),
        title: Text(
          server,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.blue : null,
          ),
        ),
        onTap: () async {
          await _settingsService.saveCurrentServer(server);
          _onSettingChanged(() => _loadCurrentServer());  // This is causing the issue
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
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
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
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
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
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }

  Widget _buildModernSliderTile(
    String title,
    String subtitle,
    IconData icon,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      subtitle: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('A', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: value.clamp(12.0, 24.0),
                  min: 12.0,
                  max: 24.0,
                  divisions: 12,
                  label: value.round().toString(),
                  onChanged: (newValue) {
                    onChanged(newValue);
                    // Update text size in real-time
                    final themeService = Provider.of<ThemeServices>(context, listen: false);
                    themeService.setTextSize(newValue); // Updated method name
                  },
                ),
              ),
              Text('A', style: TextStyle(fontSize: 24)),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Preview Text',
              style: TextStyle(fontSize: value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerTile() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.dns_rounded, color: Colors.blue),
      ),
      title: Text(
        'Current Server',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(currentServer ?? 'No server selected'),
      trailing: Icon(Icons.chevron_right_rounded),
      onTap: () => _showServerBottomSheet(),
    );
  }

  Widget _buildLanguageTile() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.language_rounded, color: Colors.blue),
      ),
      title: Text(
        'Language',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(selectedLanguage ?? 'English'),
      trailing: Icon(Icons.chevron_right_rounded),
      onTap: () => _showLanguageBottomSheet(),
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.info_outline_rounded, color: Colors.blue),
      ),
      title: Text(
        'About',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text('Version 1.0.0.0'),
      trailing: Icon(Icons.chevron_right_rounded),
      onTap: () => _showAboutDialog(),
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
        
        final bool shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Unsaved Changes'),
            content: Text('You have unsaved changes. Do you want to save them before leaving?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text('Discard'),
              ),
              TextButton(
                onPressed: () async {
                  await _saveSettings();
                  Navigator.of(context).pop(true);
                },
                child: Text('Save'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text('Cancel'),
              ),
            ],
          ),
        ) ?? false;

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
                        color: Theme.of(context).primaryTextTheme.titleLarge?.color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_hasUnsavedChanges) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
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
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.darken,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.blue.shade800, Colors.purple.shade500],
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
                padding: EdgeInsets.all(16),
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
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildQuickActionCard(
                          icon: Icons.dark_mode_rounded,
                          title: 'Theme',
                          subtitle: isDarkMode ? 'Dark Mode' : 'Light Mode',
                          onTap: () => _onSettingChanged(() => setState(() => isDarkMode = !isDarkMode)),
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
                _buildSection(
                  'Appearance',
                  [
                    _buildModernSwitchTile(
                      'Dark Mode',
                      'Switch between light and dark theme',
                      Icons.dark_mode_rounded,
                      isDarkMode,
                      (value) => _onSettingChanged(() => setState(() => isDarkMode = value)),
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
                  ],
                ),
                _buildSection(
                  'Server Settings',
                  [
                    _buildServerTile(),
                    _buildModernSwitchTile(
                      'Data Saver',
                      'Reduce data usage when loading content',
                      Icons.data_usage_rounded,
                      isDataSaverEnabled,
                      (value) => _onSettingChanged(() => setState(() => isDataSaverEnabled = value)),
                    ),
                  ],
                ),
                _buildSection(
                  'Notifications',
                  [
                    _buildModernSwitchTile(
                      'Push Notifications',
                      'Receive updates and announcements',
                      Icons.notifications_rounded,
                      isNotificationsEnabled,
                      (value) => _toggleNotifications(value),
                    ),
                  ],
                ),
                _buildSection(
                  'Language',
                  [
                    _buildLanguageTile(),
                  ],
                ),
                _buildSection(
                  'About',
                  [
                    _buildAboutTile(),
                  ],
                ),
                SizedBox(height: 80), // Space for FAB
              ]),
            ),
          ],
        ),
        floatingActionButton: _hasUnsavedChanges ? Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _saveSettings,
            elevation: 0,
            backgroundColor: Colors.blue.shade600,
            icon: Icon(Icons.save_rounded, color: Colors.white),
            label: Text(
              'Save Changes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ) : null,
      ),
    );
  }
}
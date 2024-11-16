import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_services.dart';
import '../screens/custom_toast.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool isDarkMode = false;
  String? currentServer;
  double textSize = 16.0;
  bool isNotificationsEnabled = true;
  String? selectedLanguage;
  bool isDataSaverEnabled = false;

  bool _hasUnsavedChanges = false;
  
  // Add these variables to track initial values
  late bool _initialDarkMode;
  late double _initialTextSize;
  late bool _initialNotifications;
  late String? _initialLanguage;
  late bool _initialDataSaver;
  late String? _initialServer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('darkMode') ?? false;
      textSize = prefs.getDouble('textSize') ?? 16.0;
      isNotificationsEnabled = prefs.getBool('isNotifications') ?? true;
      selectedLanguage = prefs.getString('language') ?? 'English';
      isDataSaverEnabled = prefs.getBool('dataSaver') ?? false;

      // Store initial values
      _initialDarkMode = isDarkMode;
      _initialTextSize = textSize;
      _initialNotifications = isNotificationsEnabled;
      _initialLanguage = selectedLanguage;
      _initialDataSaver = isDataSaverEnabled;

      _loadCurrentServer();
    });
  }

  Future<void> _loadCurrentServer() async {
    final server = await _settingsService.getCurrentServer();
    setState(() {
      currentServer = server;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDarkMode);
    await prefs.setDouble('textSize', textSize);
    await prefs.setBool('notifications', isNotificationsEnabled);
    await prefs.setString('language', selectedLanguage ?? 'English');
    await prefs.setBool('dataSaver', isDataSaverEnabled);
    CustomToast.show(context, 'Settings saved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Settings',
                style: TextStyle(color: Theme.of(context).primaryTextTheme.titleLarge?.color)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade800, Colors.blue.shade600],
                  )
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSection(
                'Appearance',
                [
                  _buildSwitchTile(
                    'Dark Mode',
                    'Switch between light and dark theme',
                    Icons.dark_mode,
                    isDarkMode,
                    (value) => setState(() => isDarkMode = value),
                  ),
                  _buildSliderTile(
                    'Text Size',
                    'Adjust the size of text in the app',
                    Icons.text_fields,
                    textSize,
                    (value) => setState(() => textSize = value),
                  ),
                ]
              ),
              _buildSection(
                'Server Settings',
                [
                  _buildServerTile(),
                  _buildSwitchTile(
                    'Data Saver',
                    'Reduce data usage when loading content',
                    Icons.data_usage,
                    isDataSaverEnabled,
                    (value) => setState(() => isDataSaverEnabled = value),
                  ),
                ],
              ),
              _buildSection(
                'Notifications',
                [
                  _buildSwitchTile(
                    'Push Notifications',
                    'Receive updates and announcements',
                    Icons.notifications,
                    isNotificationsEnabled,
                    (value) => setState(() => isNotificationsEnabled = value),
                  ),
                ],
              ),
              _buildSection(
                'Language',
                [
                  _buildLanguageDropdown(),
                ],
              ),
              _buildSection(
                'About',
                [
                  _buildAboutTile(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: Text('Save Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ]),
          )
        ]
      )
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: children,)
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }

  Widget _buildSliderTile(String title, String subtitle, IconData icon, double value, Function(double) onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            min: 12.0,
            max: 24.0,
            divisions: 12,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildServerTile() {
    return ListTile(
      leading: Icon(Icons.dns, color: Colors.blue),
      title: Text('Current server'),
      subtitle: Text(currentServer ?? 'No server selected. The app will use the default server'),
      trailing: Icon(Icons.chevron_right),
      onTap: () {
        _showServerSelectionDialog();
      },
    );
  }

  Widget _buildLanguageDropdown() {
    final languages = ['English', 'Tiếng Việt', 'Français', 'Española', 'Deutsch', 'Italiana', 'Nederlands', 'Português', 'Русский', '日本語', '한국인', '中国人'];
    return ListTile(
      leading: Icon(Icons.language, color: Colors.blue),
      title: Text('Language'),
      trailing: DropdownButton<String>(
        value: selectedLanguage,
        onChanged: (String? newValue) {
          setState(() {
            selectedLanguage = newValue;
          });
        },
        items: languages.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      leading: Icon(Icons.info_outline, color: Colors.blue),
      title: Text('About'),
      subtitle: Text('Version 1.0.0.0'),
      onTap: () {
        _showAboutDialog();
      },
    );
  }

  void _showServerSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Please select one of following servers below here. If you not selected, the app will use the default server.", style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            ListTile(
              title: Text('ln.hako.vn'),
              onTap: () async {
                await _settingsService.saveCurrentServer('ln.hako.vn');
                _loadCurrentServer();
                Navigator.pop(context);
              },
            ),
             ListTile(
              title: Text('ln.hako.re'),
              onTap: () async {
                await _settingsService.saveCurrentServer('ln.hako.re');
                _loadCurrentServer();
                Navigator.pop(context);
              },
            ),
             ListTile(
              title: Text('docln.net'),
              onTap: () async {
                await _settingsService.saveCurrentServer('docln.net');
                _loadCurrentServer();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      )
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About Light Novel Reader'),
        content: Column(
          children: [
            Icon(Icons.flutter_dash, size: 200, color: Colors.blue),
            SizedBox(height: 16),
            Text('Version 1.0.0.0'),
            SizedBox(height: 8),
            Text('© 2024 CyberDay Studios.'),
            SizedBox(height: 16),
            Text('Developed by nekkochan.'),
            SizedBox(height: 30),
            Text('Light Novel Reader is a free and open-source light novel reader app that allows you to read light novels online for free', textAlign: TextAlign.center),
            SizedBox(height: 40),
            Text('This app is not affiliated with any of the websites it links to.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 16),
            Text('This application is under heavy development. That''s mean the application may contain bugs and errors. Please report any issues to the developer.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
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
}

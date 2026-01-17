import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:docln/core/services/theme_services.dart';
import 'package:docln/core/services/language_service.dart';
import 'package:docln/core/services/notification_service.dart';
import 'package:docln/core/services/settings_services.dart';
import 'package:docln/core/widgets/custom_toast.dart';
import 'package:docln/core/services/preferences_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:ui';
import 'package:docln/core/services/performance_service.dart';
import 'package:docln/core/services/update_service.dart';
import 'package:docln/core/widgets/update_dialog.dart';
import 'package:docln/features/settings/ui/WireGuardSettingsScreen.dart';
import 'package:docln/features/settings/ui/WarpSettingsScreen.dart';
import 'package:docln/core/services/preferences_recovery_service.dart';
import 'package:file_picker/file_picker.dart';

import 'package:docln/features/settings/ui/ServerDiagnosticScreen.dart';
import 'package:docln/features/settings/ui/BackgroundServiceDebugScreen.dart';
import 'package:docln/features/settings/logic/network_settings_provider.dart';
import 'package:docln/features/settings/ui/widgets/network_section.dart';
import 'package:docln/features/settings/logic/appearance_settings_provider.dart';
import 'package:docln/features/settings/ui/widgets/appearance_section.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// GridPainter class at the top level (kept for potentially future use or consistency)
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
  static const String _appVersion = 'Version: 2025.10.12-rev1.0';

  // Local state
  bool isDarkMode = false;
  double textSize = 16.0;
  bool isNotificationsEnabled = true;
  String notificationSound = 'pixie_dust';
  String? selectedLanguage;
  bool isDataSaverEnabled = false;

  // State tracking
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  late NetworkSettingsProvider _networkSettingsProvider;
  late AppearanceSettingsProvider _appearanceSettingsProvider;

  // Initial values for revert
  bool _initialNotifications = true;
  String _initialNotificationSound = 'pixie_dust';
  String? _initialLanguage;
  bool _initialDataSaver = false;

  @override
  void initState() {
    super.initState();
    _networkSettingsProvider = NetworkSettingsProvider();
    _appearanceSettingsProvider = AppearanceSettingsProvider();

    // Initialize settings from providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeService = Provider.of<ThemeServices>(context, listen: false);
      final languageService = Provider.of<LanguageService>(
        context,
        listen: false,
      );

      // Initialize Appearance Provider
      _appearanceSettingsProvider.init(
        themeService.themeMode == ThemeMode.dark,
        themeService.textSize,
      );

      setState(() {
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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefsService = PreferencesService();
      await prefsService.initialize();

      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );
      final hasPermission = await notificationService.checkPermission();
      final savedSound = await notificationService.getNotificationSound();

      setState(() {
        isNotificationsEnabled =
            hasPermission &&
            prefsService.getBool('isNotifications', defaultValue: true);
        notificationSound = savedSound;
        selectedLanguage = prefsService.getString(
          'language',
          defaultValue: 'English',
        );
        isDataSaverEnabled = prefsService.getBool(
          'dataSaver',
          defaultValue: false,
        );

        _initialNotifications = isNotificationsEnabled;
        _initialNotificationSound = notificationSound;
        _initialLanguage = selectedLanguage;
        _initialDataSaver = isDataSaverEnabled;
        _hasUnsavedChanges = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        isNotificationsEnabled = false;
        _initialNotifications = false;
      });
    }
  }

  void _onSettingChanged(VoidCallback change) {
    change();
    setState(() {
      _hasUnsavedChanges = true;
    });
    // Notify parent if needed
    if (widget.onSettingsChanged != null) {
      widget.onSettingsChanged!(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Provide providers locally for the sections
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _networkSettingsProvider),
        ChangeNotifierProvider.value(value: _appearanceSettingsProvider),
      ],
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Settings'),
              centerTitle: false,
              scrolledUnderElevation: 0,
              backgroundColor: theme.colorScheme.surface,
              actions: [
                if (_hasUnsavedChanges)
                  TextButton.icon(
                    onPressed: () => _showUnsavedChangesDialog(context),
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      'Unsaved',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => _showAboutDialog(),
                ),
                const SizedBox(width: 8),
              ],
              expandedHeight: 120,
              titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 32,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                100 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionHeader(
                    'Appearance & Language',
                    Icons.palette_outlined,
                  ),
                  _buildSettingsGroup(
                    children: [
                      AppearanceSection(
                        onSettingsChanged: () => _onSettingChanged(() {}),
                      ),
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        leading: Icon(
                          Icons.language,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('Language'),
                        subtitle: Text(selectedLanguage ?? 'English'),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: _showLanguageDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    'Connection & Network',
                    Icons.wifi_rounded,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.5,
                        ),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: NetworkSection(
                      onSettingsChanged: () => _onSettingChanged(() {}),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildWireGuardSection(),
                  const SizedBox(height: 16),
                  _buildWarpSection(),
                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    'Notifications',
                    Icons.notifications_outlined,
                  ),
                  _buildSettingsGroup(
                    children: [
                      SwitchListTile(
                        value: isNotificationsEnabled,
                        onChanged: _toggleNotifications,
                        title: const Text('Enable Notifications'),
                        subtitle: const Text(
                          'Receive notifications for new chapters',
                        ),
                        secondary: Icon(
                          Icons.notifications_active,
                          color: isNotificationsEnabled
                              ? theme.colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                      if (isNotificationsEnabled) ...[
                        const Divider(height: 1, indent: 56),
                        _buildNotificationSoundTile(),
                        const Divider(height: 1, indent: 56),
                        _buildTestNotificationButton(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader('System', Icons.settings_system_daydream),
                  _buildSettingsGroup(
                    children: [
                      SwitchListTile(
                        value: isDataSaverEnabled,
                        onChanged: (value) => _onSettingChanged(() {
                          setState(() => isDataSaverEnabled = value);
                        }),
                        title: const Text('Data Saver'),
                        subtitle: const Text(
                          'Reduce image quality to save data',
                        ),
                        secondary: Icon(
                          Icons.data_saver_on,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.update, color: Colors.green),
                        title: const Text('Check for Updates'),
                        subtitle: const Text(_appVersion),
                        onTap: _checkForUpdates,
                        trailing: OutlinedButton(
                          onPressed: _checkForUpdates,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Check'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildBackupSection(),
                  const SizedBox(height: 24),

                  _buildDebugSection(),
                ]),
              ),
            ),
          ],
        ),
        floatingActionButton: _hasUnsavedChanges
            ? FloatingActionButton.extended(
                onPressed: _isSaving ? null : saveSettings,
                icon: _isSaving
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }

  // --- UI Builders ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildWireGuardSection() {
    return _buildSettingsGroup(
      children: [
        ListTile(
          leading: Icon(
            Icons.vpn_lock,
            color: Theme.of(context).colorScheme.secondary,
          ),
          title: const Text('WireGuard VPN'),
          subtitle: const Text('Configure secure VPN tunnel'),
          trailing: const Icon(Icons.chevron_right, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WireGuardSettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWarpSection() {
    return _buildSettingsGroup(
      children: [
        ListTile(
          leading: Icon(
            Icons.shield,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          title: const Text('Cloudflare WARP'),
          subtitle: const Text('Route traffic through Cloudflare'),
          trailing: const Icon(Icons.chevron_right, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WarpSettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBackupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Backup & Restore', Icons.backup),
        _buildSettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Export Preferences'),
              subtitle: const Text('Save settings to a file'),
              onTap: _exportPreferences,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.file_download, color: Colors.orange),
              title: const Text('Import Preferences'),
              subtitle: const Text('Restore settings from file'),
              onTap: _importPreferences,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.green),
              title: const Text('Restore from Backup'),
              subtitle: const Text('Restore from local auto-backups'),
              onTap: _showRestoreDialog,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.build, color: Colors.red),
              title: const Text('Repair Preferences'),
              subtitle: const Text('Fix corrupted settings'),
              onTap: _repairPreferences,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDebugSection() {
    if (!isDataSaverEnabled) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Debug & Diagnostic', Icons.bug_report),
        _buildSettingsGroup(
          children: [
            ListTile(
              title: const Text('Server Diagnostics'),
              leading: Icon(
                Icons.monitor_heart,
                color: Theme.of(context).colorScheme.primary,
              ),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServerDiagnosticScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              title: const Text('Background Service Tests'),
              leading: Icon(
                Icons.work_history,
                color: Theme.of(context).colorScheme.primary,
              ),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BackgroundServiceDebugScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // --- Logic Methods ---

  void _toggleNotifications(bool value) {
    _onSettingChanged(() {
      setState(() {
        isNotificationsEnabled = value;
      });
    });
  }

  Widget _buildNotificationSoundTile() {
    return ListTile(
      title: const Text('Notification Sound'),
      subtitle: Text(notificationSound),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: _showNotificationSoundPicker,
    );
  }

  Widget _buildTestNotificationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: OutlinedButton.icon(
        onPressed: () {
          final notifService = Provider.of<NotificationService>(
            context,
            listen: false,
          );
          notifService.showNotification(
            title: 'Test Notification',
            body: 'This is a test notification from Settings.',
          );
        },
        icon: const Icon(Icons.notifications_active),
        label: const Text('Test Notification'),
      ),
    );
  }

  void _showNotificationSoundPicker() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Sound'),
        children: [
          SimpleDialogOption(
            onPressed: () => _handleSoundSelection('default'),
            child: const Text('Default (App Sound)'),
          ),
          SimpleDialogOption(
            onPressed: _openSystemNotificationSettings,
            child: const Text('System Settings'),
          ),
        ],
      ),
    );
  }

  void _handleSoundSelection(String sound) {
    _onSettingChanged(() {
      setState(() => notificationSound = sound);
    });
    Navigator.pop(context);
  }

  void _openSystemNotificationSettings() async {
    Navigator.pop(context);
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  void _checkForUpdates() async {
    CustomToast.show(context, 'Checking for updates...');
    try {
      final info = await UpdateService.checkForUpdates();
      if (!mounted) return;

      if (info != null) {
        showDialog(
          context: context,
          builder: (context) => UpdateDialog(updateInfo: info),
        );
      } else {
        CustomToast.show(context, 'You are on the latest version');
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, 'Error checking updates');
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: [
          SimpleDialogOption(
            onPressed: () => _changeLanguage('English'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('English'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => _changeLanguage('Vietnamese'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Vietnamese'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLanguage(String newLanguage) async {
    Navigator.pop(context);
    _onSettingChanged(() async {
      setState(() => selectedLanguage = newLanguage);
      try {
        final languageService = Provider.of<LanguageService>(
          context,
          listen: false,
        );
        await languageService.setLanguage(newLanguage);
        CustomToast.show(context, 'Language changed to $newLanguage');
      } catch (e) {
        // Handle error if needed
      }
    });
  }

  void _showUnsavedChangesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to save them?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              revertSettings();
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              saveSettings();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: 'DocLN',
        applicationVersion: _appVersion.replaceAll('Version: ', ''),
        applicationIcon: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 30,
          ),
        ),
        children: const [
          SizedBox(height: 16),
          Text('Smart Light Novel Reader App.'),
          Text('Developed by Nekkochan & Team.'),
        ],
      ),
    );
  }

  Future<void> saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _appearanceSettingsProvider.saveSettings(context);
      await _networkSettingsProvider.saveSettings();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', isNotificationsEnabled);
      await prefs.setString('notification_sound', notificationSound);
      await prefs.setBool('data_saver', isDataSaverEnabled);
      await prefs.setString('language', selectedLanguage ?? 'English');

      setState(() {
        _hasUnsavedChanges = false;
        _initialNotifications = isNotificationsEnabled;
        _initialNotificationSound = notificationSound;
        _initialDataSaver = isDataSaverEnabled;
        _initialLanguage = selectedLanguage;
      });

      if (mounted) {
        CustomToast.show(context, 'Settings saved successfully');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Error saving settings: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void revertSettings() {
    setState(() {
      isNotificationsEnabled = _initialNotifications;
      notificationSound = _initialNotificationSound;
      isDataSaverEnabled = _initialDataSaver;
      selectedLanguage = _initialLanguage;
      _hasUnsavedChanges = false;
    });

    // Re-init providers to revert their state
    final themeService = Provider.of<ThemeServices>(context, listen: false);
    _appearanceSettingsProvider.init(
      themeService.themeMode == ThemeMode.dark,
      themeService.textSize,
    );
    // Network provider might need similar revert logic or reloading from prefs
    // For now we assume network settings revert via re-loading screen or simple re-init if we had data
  }

  // --- Backup Helpers ---

  void _exportPreferences() async {
    try {
      final recoveryService = PreferencesRecoveryService();
      final exportPath = await recoveryService.createExportFile();

      if (exportPath != null && mounted) {
        Share.shareXFiles([
          XFile(exportPath),
        ], subject: 'DocLN Preferences Export');
      } else if (mounted) {
        CustomToast.show(context, 'Failed to create export file');
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, 'Error exporting: $e');
    }
  }

  void _importPreferences() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      if (!mounted) return;
      final recoveryService = PreferencesRecoveryService();
      final success = await recoveryService.importFromFile(
        result.files.single.path!,
        context,
      );

      if (success && mounted) {
        await _loadSettings();
        CustomToast.show(context, 'Import successful. Restart recommended.');
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, 'Error importing: $e');
    }
  }

  void _showRestoreDialog() async {
    final recoveryService = PreferencesRecoveryService();
    final backups = await recoveryService.getAvailableBackups();

    if (!mounted) return;
    if (backups.isEmpty) {
      CustomToast.show(context, 'No backups found');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: backups.length,
        itemBuilder: (context, index) {
          final backup = backups[index];
          return ListTile(
            title: Text(backup['timestamp'].toString()),
            subtitle: Text(backup['type'].toString()),
            onTap: () {
              Navigator.pop(context);
              _confirmAndRestoreBackup(backup['path'], backup['format']);
            },
          );
        },
      ),
    );
  }

  void _confirmAndRestoreBackup(String path, String format) async {
    final recoveryService = PreferencesRecoveryService();
    await recoveryService.restoreFromBackup(path, context);
    _loadSettings();
    if (mounted) CustomToast.show(context, 'Restored successfully');
  }

  void _repairPreferences() async {
    final recoveryService = PreferencesRecoveryService();
    await recoveryService.recoverPreferences(context);
    _loadSettings();
    if (mounted) CustomToast.show(context, 'Repair completed');
  }
}

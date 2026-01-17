import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:docln/core/services/theme_services.dart';
import 'package:docln/core/services/language_service.dart';
import 'package:docln/core/services/notification_service.dart';
import 'package:docln/core/services/settings_services.dart';
import 'package:docln/core/widgets/custom_toast.dart';
import 'package:docln/core/services/preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';
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
  static const String _appVersion = 'Version: 2025.10.12-rev1.0';
  bool isDarkMode = false;
  double textSize = 16.0;
  bool isNotificationsEnabled = true;
  String notificationSound = 'pixie_dust'; // Default notification sound
  String? selectedLanguage;
  bool isDataSaverEnabled = false;

  // Internal state
  bool _hasUnsavedChanges = false;
  late NetworkSettingsProvider _networkSettingsProvider;
  late AppearanceSettingsProvider _appearanceSettingsProvider;
  late AnimationController _animationController;

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
    _animationController.dispose();
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

      // Check notification permission status
      final hasPermission = await notificationService.checkPermission();

      // Load notification sound preference
      final savedSound = await notificationService.getNotificationSound();

      setState(() {
        // Only enable notifications if we have permission
        isNotificationsEnabled =
            hasPermission &&
            prefsService.getBool('isNotifications', defaultValue: true);
        notificationSound = savedSound; // Load saved sound
        selectedLanguage = prefsService.getString(
          'language',
          defaultValue: 'English',
        );
        isDataSaverEnabled = prefsService.getBool(
          'dataSaver',
          defaultValue: false,
        );

        _initialNotifications = isNotificationsEnabled;
        _initialNotificationSound = notificationSound; // Save initial sound
        _initialLanguage = selectedLanguage;
        _initialDataSaver = isDataSaverEnabled;
      });

      // Network and Appearance settings are loaded by their respective providers
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        isNotificationsEnabled = false;
        _initialNotifications = false;
      });
    }
  }

  // _loadProxySettings and _loadDnsSettings removed

  void _checkForChanges() {
    setState(() {
      _hasUnsavedChanges =
          isNotificationsEnabled != _initialNotifications ||
          notificationSound != _initialNotificationSound ||
          selectedLanguage != _initialLanguage ||
          isDataSaverEnabled != _initialDataSaver;
    });
  }

  void _onSettingChanged(Function() change) {
    change();
    final hasChanges =
        isNotificationsEnabled != _initialNotifications ||
        notificationSound != _initialNotificationSound ||
        selectedLanguage != _initialLanguage ||
        isDataSaverEnabled != _initialDataSaver;

    setState(() {
      _hasUnsavedChanges = hasChanges;
    });
    widget.onSettingsChanged?.call(hasChanges);
  }

  Future<void> saveSettings() async {
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    try {
      final prefsService = PreferencesService();
      await prefsService.initialize();

      final languageService = Provider.of<LanguageService>(
        context,
        listen: false,
      );
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );

      // Save all settings
      await Future.wait([
        notificationService.setNotificationEnabled(isNotificationsEnabled),
        notificationService.setNotificationSound(
          notificationSound,
        ), // Save notification sound
        prefsService.setString('language', selectedLanguage ?? 'English'),
        prefsService.setBool('dataSaver', isDataSaverEnabled),
      ]);

      // Save providers' settings
      await _appearanceSettingsProvider.saveSettings(context);

      // Save network settings
      await _networkSettingsProvider.saveSettings();

      // Note: Notification channel is automatically recreated when sound changes
      // via setNotificationSound() in _handleSoundSelection()

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
        _initialNotifications = isNotificationsEnabled;
        _initialLanguage = selectedLanguage;
        _initialDataSaver = isDataSaverEnabled;

        _hasUnsavedChanges = false;
      });

      // Update theme and language
      // Theme update handled by AppearanceSettingsProvider
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
    setState(() {
      isNotificationsEnabled = _initialNotifications;
      selectedLanguage = _initialLanguage;
      isDataSaverEnabled = _initialDataSaver;

      // Revert network settings
      _networkSettingsProvider.revertSettings();
      // Revert appearance settings
      _appearanceSettingsProvider.revertSettings(context);

      _hasUnsavedChanges = false;
    });
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

  Widget _buildNotificationSoundTile() {
    String soundLabel =
        NotificationService.availableSounds[notificationSound] ?? 'Unknown';

    // If custom sound, show file name
    if (notificationSound == 'custom') {
      soundLabel = 'Custom Sound File';
    }

    return ListTile(
      leading: Icon(
        notificationSound == 'custom'
            ? Icons.folder_open
            : Icons.volume_up_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Notification Sound'),
      subtitle: Text(soundLabel),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showNotificationSoundPicker(),
    );
  }

  Widget _buildTestNotificationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            final notificationService = Provider.of<NotificationService>(
              context,
              listen: false,
            );
            await notificationService.testNotificationSound();
            if (mounted) {
              CustomToast.show(context, '🔊 Test notification sent!');
            }
          },
          icon: const Icon(Icons.notifications_active, size: 20),
          label: const Text('Test Notification Sound'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }

  void _showNotificationSoundPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.music_note,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Notification Sound'),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Built-in sounds
              ...NotificationService.availableSounds.entries
                  .where((e) => e.key != 'custom' && e.key != 'system_picker')
                  .map((entry) {
                    final soundKey = entry.key;
                    final soundLabel = entry.value;
                    final isSelected = notificationSound == soundKey;

                    return RadioListTile<String>(
                      value: soundKey,
                      groupValue: notificationSound,
                      title: Text(soundLabel),
                      subtitle: soundKey != 'default'
                          ? Text(
                              '@raw/$soundKey',
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                      selected: isSelected,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) async {
                        if (value != null) {
                          await _handleSoundSelection(value);
                        }
                      },
                    );
                  }),

              const Divider(),

              // Custom sound file option - redirects to system picker
              ListTile(
                leading: Icon(Icons.audio_file, color: Colors.orange),
                title: const Text('Use Custom Sound'),
                subtitle: const Text('Opens system settings for custom sounds'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickCustomSoundFile();
                },
              ),

              // System picker option
              ListTile(
                leading: Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Use System Picker'),
                subtitle: const Text('Open Android notification settings'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  Navigator.pop(context);
                  await _openSystemNotificationSettings();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSoundSelection(String soundKey) async {
    Navigator.pop(context);
    _onSettingChanged(() {
      setState(() => notificationSound = soundKey);
    });

    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );

    // Save and test the sound
    // Note: setNotificationSound() automatically recreates the channel with new sound
    await notificationService.setNotificationSound(soundKey);
    await notificationService.testNotificationSound();
  }

  Future<void> _pickCustomSoundFile() async {
    // Show info dialog explaining limitation
    if (mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Custom Sounds'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Android notifications can only use:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text('• Built-in app sounds (Pixie Dust, Default)'),
              SizedBox(height: 8),
              Text('• System sounds via Android Settings'),
              SizedBox(height: 16),
              Text(
                'To use your own custom sound file, you need to:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text('1. Use "System Picker" option'),
              SizedBox(height: 8),
              Text('2. Android will show all available sounds'),
              SizedBox(height: 8),
              Text('3. Some devices let you add custom sounds there'),
              SizedBox(height: 16),
              Text(
                'Would you like to open System Settings now?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (proceed == true) {
        await _openSystemNotificationSettings();
      }
    }

    /* OLD CODE - File picker not supported for notifications
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final filePath = file.path;
        
        if (filePath != null) {
          final notificationService = Provider.of<NotificationService>(
            context,
            listen: false,
          );
          
          // Save custom sound path
          await notificationService.setCustomSoundPath(filePath);
          
          _onSettingChanged(() {
            setState(() => notificationSound = 'custom');
          });
          
          await notificationService.setNotificationSound('custom');
          
          if (mounted) {
            CustomToast.show(
              context,
              '✅ Custom sound selected: ${file.name}',
            );
            
            // Show option to test
            final shouldTest = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sound Selected'),
                content: Text('Test notification with "${file.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Test Now'),
                  ),
                ],
              ),
            );
            
            if (shouldTest == true && mounted) {
              // Note: Custom file playback may require copying to app directory
              CustomToast.show(
                context,
                '🔔 Custom sound files require app restart to take effect',
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          '❌ Error selecting sound file: $e',
        );
      }
    }
    */
  }

  Future<void> _openSystemNotificationSettings() async {
    try {
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );

      await notificationService.openNotificationChannelSettings();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('System Settings'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You can change the notification sound in Android\'s system settings:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 16),
                Text('1. Find "High Importance Notifications" channel'),
                SizedBox(height: 8),
                Text('2. Tap "Sound"'),
                SizedBox(height: 8),
                Text('3. Choose from all available system sounds'),
                SizedBox(height: 16),
                Text(
                  'This will override the app\'s sound setting.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got It'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '❌ Error opening system settings: $e');
      }
    }
  }

  void _showTextSizeDialog() {
    double tempSize = _appearanceSettingsProvider.textSize.clamp(12.0, 24.0);

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
                        themeService.previewTextSize(value);
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
                // Reset to initial (which is current applied)
                themeService.setTextSize(_appearanceSettingsProvider.textSize);
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _appearanceSettingsProvider.setTextSize(tempSize);
                _onSettingChanged(() {});
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

  Widget _buildBackgroundServiceDebugTile() {
    return ListTile(
      leading: const Icon(Icons.bug_report_rounded),
      title: const Text('Background Service Monitor'),
      subtitle: const Text('Monitor background notification service status'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BackgroundServiceDebugScreen(),
          ),
        );
      },
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
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _networkSettingsProvider),
          ChangeNotifierProvider.value(value: _appearanceSettingsProvider),
        ],
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  AppearanceSection(
                    onSettingsChanged: () => _onSettingChanged(() {}),
                  ),
                  _buildSection('Server Settings', [
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
                  // Network Section
                  NetworkSection(
                    onSettingsChanged: () {
                      // Since NetworkSettingsProvider saves immediately via its own methods in this refactor step,
                      // we might just need to capture that something changed if we want to enable global save button.

                      // However, the provider implementation saves immediately on interaction in some patterns,
                      // OR it holds state until .saveSettings() is called.

                      // The current NetworkSettingsProvider IMPLEMENTATION provided earlier has a `saveSettings()` method,
                      // but the `NetworkSection` UI provided calls `provider.set...` which notifies listeners but doesn't auto-save to disk,
                      // EXCEPT the UI widget implementation doesn't call `saveSettings`.

                      // Wait, checking the provider code I wrote:
                      // provider.setProxyEnabled -> just updates state and notifies.
                      // So we DO need to call provider.saveSettings() when the user hits the main SAVE button in SettingsScreen.

                      // So here we should trigger _onSettingChanged to enable the save button.
                      _onSettingChanged(() {});
                    },
                  ),
                  _buildWireGuardSection(),
                  _buildWarpSection(),
                  _buildBackupSection(),
                  _buildSection('Notifications', [
                    _buildModernSwitchTile(
                      'Push Notifications',
                      'Receive notification for new chapter releases, application updates and announcements',
                      Icons.notifications_rounded,
                      isNotificationsEnabled,
                      (value) => _toggleNotifications(value),
                    ),
                    if (isNotificationsEnabled) ...[
                      _buildNotificationSoundTile(),
                      _buildTestNotificationButton(),
                    ],
                  ]),
                  _buildSection('Developer Tools', [
                    _buildBackgroundServiceDebugTile(),
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

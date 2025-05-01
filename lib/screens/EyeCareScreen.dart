import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/eye_protection_service.dart';

class EyeCareScreen extends StatefulWidget {
  const EyeCareScreen({Key? key}) : super(key: key);

  @override
  _EyeCareScreenState createState() => _EyeCareScreenState();
}

class _EyeCareScreenState extends State<EyeCareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late EyeProtectionService _eyeProtectionService;
  bool _isFeatureEnabled = true;
  double _blueFilterLevel = 0.3;
  bool _adaptiveBrightnessEnabled = true;
  bool _readingModeEnabled = true;
  bool _breakReminderEnabled = true;
  int _breakInterval = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _eyeProtectionService = EyeProtectionService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _eyeProtectionService.initialize();
    setState(() {
      _isFeatureEnabled = _eyeProtectionService.eyeProtectionEnabled;
      _blueFilterLevel = _eyeProtectionService.blueFilterLevel;
      _adaptiveBrightnessEnabled =
          _eyeProtectionService.adaptiveBrightnessEnabled;
      _readingModeEnabled = true; // This could be stored in service too
      _breakReminderEnabled = _eyeProtectionService.periodicalReminderEnabled;
      _breakInterval = _eyeProtectionService.readingTimerInterval;
    });
  }

  Future<void> _updateSettings(String key, dynamic value) async {
    await _eyeProtectionService.savePreference(key, value);
    setState(() {
      // Update local state to match service
      switch (key) {
        case 'eye_protection_enabled':
          _isFeatureEnabled = value;
          break;
        case 'blue_filter_level':
          _blueFilterLevel = value;
          break;
        case 'adaptive_brightness_enabled':
          _adaptiveBrightnessEnabled = value;
          break;
        case 'reading_mode_enabled':
          _readingModeEnabled = value;
          break;
        case 'periodical_reminder_enabled':
          _breakReminderEnabled = value;
          break;
        case 'reading_timer_interval':
          _breakInterval = value;
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'eye',
                style: TextStyle(
                  color: theme.colorScheme.onBackground,
                  fontWeight: FontWeight.w400,
                  fontSize: 20,
                ),
              ),
              TextSpan(
                text: 'CARE™',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: 'Features'),
            Tab(text: 'Science'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeaturesTab(),
          _buildScienceTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildFeaturesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Key Features'),
          const SizedBox(height: 8),
          _buildFeatureCard(
            'Blue Light Filter',
            'Reduces harmful blue light emission that causes eye strain and disrupts sleep patterns.',
            Icons.filter_vintage_outlined,
            Colors.blue.shade700,
          ),
          _buildFeatureCard(
            'Adaptive Brightness',
            'Automatically adjusts screen brightness based on ambient light for optimal viewing comfort.',
            Icons.brightness_auto,
            Colors.amber.shade700,
          ),
          _buildFeatureCard(
            'Reading Mode',
            'Optimizes screen color temperature and contrast for long reading sessions.',
            Icons.menu_book_outlined,
            Colors.green.shade700,
          ),
          _buildFeatureCard(
            'Dark Mode',
            'Reduces overall light emission while maintaining readability in low-light environments.',
            Icons.dark_mode_outlined,
            Colors.indigo.shade700,
          ),
          _buildFeatureCard(
            'Reading Timer',
            'Gentle reminders to take breaks after extended reading periods.',
            Icons.timer_outlined,
            Colors.red.shade700,
          ),
          const SizedBox(height: 24),
          _buildHeader('Benefits'),
          const SizedBox(height: 8),
          _buildBenefit('Reduces digital eye strain and fatigue'),
          _buildBenefit('Prevents dry eyes during extended reading'),
          _buildBenefit('Minimizes headaches from screen glare'),
          _buildBenefit('Improves sleep quality by reducing blue light'),
          _buildBenefit('Promotes healthier reading habits'),
        ],
      ),
    );
  }

  Widget _buildScienceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('The Science'),
          const SizedBox(height: 16),
          Text(
            'Our eyeCARE™ technology is based on extensive research in ophthalmology and digital wellness.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _buildScienceCard(
            'Blue Light Research',
            'Studies at Harvard Medical School have shown that blue light exposure can suppress melatonin production, affecting sleep quality. Our filters are calibrated based on this research to minimize negative impacts.',
            'Dr. Charles Czeisler, Harvard Medical School',
          ),
          _buildScienceCard(
            'Digital Eye Strain',
            'Research from the Vision Council indicates that 59% of adults report symptoms of Digital Eye Strain (DES). Our adaptive brightness algorithms help reduce the factors that contribute to DES.',
            'Vision Council of America',
          ),
          _buildScienceCard(
            '20-20-20 Rule',
            'Ophthalmologists recommend the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds. Our timer feature is designed to help users implement this scientifically-backed practice.',
            'American Academy of Ophthalmology',
          ),
          _buildScienceCard(
            'Contrast Sensitivity',
            'Studies show that optimizing contrast and reducing glare can significantly reduce reading fatigue. Our Reading Mode adjusts these parameters based on peer-reviewed research.',
            'Dr. James Sheedy, Pacific University',
          ),
          const SizedBox(height: 24),
          _buildHeader('Research Partners'),
          const SizedBox(height: 16),
          _buildPartner('Tokyo Institute of Vision Science'),
          _buildPartner('Digital Wellness Research Center, California'),
          _buildPartner('European Association for Eye Health'),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('eyeCARE™ Settings'),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable eyeCARE™'),
            subtitle: const Text(
              'Master toggle for all eye protection features',
            ),
            value: _isFeatureEnabled,
            onChanged: (value) {
              _updateSettings('eye_protection_enabled', value);
            },
          ),
          const Divider(),
          // Blue Light Filter
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blue Light Filter Intensity',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _isFeatureEnabled ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjust the strength of blue light reduction',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        _isFeatureEnabled ? Colors.grey.shade600 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _blueFilterLevel,
                  onChanged:
                      _isFeatureEnabled
                          ? (value) {
                            _updateSettings('blue_filter_level', value);
                          }
                          : null,
                ),
              ],
            ),
          ),
          // Adaptive Brightness
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adaptive Brightness',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _isFeatureEnabled ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automatically adjust screen brightness',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _isFeatureEnabled
                                  ? Colors.grey.shade600
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _adaptiveBrightnessEnabled,
                  onChanged:
                      _isFeatureEnabled
                          ? (value) {
                            _updateSettings(
                              'adaptive_brightness_enabled',
                              value,
                            );
                          }
                          : null,
                ),
              ],
            ),
          ),
          // Reading Mode
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _isFeatureEnabled ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Optimize display for extended reading',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _isFeatureEnabled
                                  ? Colors.grey.shade600
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _readingModeEnabled,
                  onChanged:
                      _isFeatureEnabled
                          ? (value) {
                            _updateSettings('reading_mode_enabled', value);
                          }
                          : null,
                ),
              ],
            ),
          ),
          const Divider(),
          // Reading Break Timer
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading Break Timer',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _isFeatureEnabled ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Remind to take breaks while reading',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _isFeatureEnabled
                                  ? Colors.grey.shade600
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _breakReminderEnabled,
                  onChanged:
                      _isFeatureEnabled
                          ? (value) {
                            _updateSettings(
                              'periodical_reminder_enabled',
                              value,
                            );
                          }
                          : null,
                ),
              ],
            ),
          ),
          // Break Interval
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Break Interval',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _isFeatureEnabled ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time between reading breaks',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _isFeatureEnabled
                                  ? Colors.grey.shade600
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                _isFeatureEnabled
                    ? DropdownButton<int>(
                      value: _breakInterval,
                      items: const [
                        DropdownMenuItem<int>(value: 10, child: Text('10 min')),
                        DropdownMenuItem<int>(value: 15, child: Text('15 min')),
                        DropdownMenuItem<int>(value: 20, child: Text('20 min')),
                        DropdownMenuItem<int>(value: 30, child: Text('30 min')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _updateSettings('reading_timer_interval', value);
                        }
                      },
                    )
                    : Text(
                      '${_breakInterval} min',
                      style: TextStyle(color: Colors.grey),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildHeader('Presets'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _isFeatureEnabled ? () => _applyPreset('day') : null,
                child: const Text('Day Reading'),
              ),
              ElevatedButton(
                onPressed:
                    _isFeatureEnabled ? () => _applyPreset('night') : null,
                child: const Text('Night Reading'),
              ),
              ElevatedButton(
                onPressed:
                    _isFeatureEnabled ? () => _applyPreset('low_light') : null,
                child: const Text('Low Light'),
              ),
              ElevatedButton(
                onPressed: _isFeatureEnabled ? () => _applyPreset('max') : null,
                child: const Text('Maximum Protection'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildScienceCard(String title, String description, String source) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Source: $source',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartner(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.verified,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(name, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  void _applyPreset(String preset) async {
    switch (preset) {
      case 'day':
        // Moderate settings for daytime reading
        await _updateSettings('blue_filter_level', 0.3);
        await _updateSettings('adaptive_brightness_enabled', true);
        await _updateSettings('reading_mode_enabled', true);
        await _updateSettings('periodical_reminder_enabled', true);
        await _updateSettings('reading_timer_interval', 20);
        break;
      case 'night':
        // Higher blue filter for evening use
        await _updateSettings('blue_filter_level', 0.6);
        await _updateSettings('adaptive_brightness_enabled', true);
        await _updateSettings('reading_mode_enabled', true);
        await _updateSettings('periodical_reminder_enabled', true);
        await _updateSettings('reading_timer_interval', 20);
        await _eyeProtectionService.setWarmthLevel(
          0.7,
        ); // Increased warmth for night
        break;
      case 'low_light':
        // Settings optimized for reading in dim environments
        await _updateSettings('blue_filter_level', 0.5);
        await _updateSettings('adaptive_brightness_enabled', true);
        await _updateSettings('reading_mode_enabled', true);
        await _updateSettings('periodical_reminder_enabled', true);
        await _updateSettings(
          'reading_timer_interval',
          15,
        ); // More frequent breaks in low light
        await _eyeProtectionService.setWarmthLevel(0.6);
        break;
      case 'max':
        // Maximum eye protection settings
        await _updateSettings('blue_filter_level', 0.7);
        await _updateSettings('adaptive_brightness_enabled', true);
        await _updateSettings('reading_mode_enabled', true);
        await _updateSettings('periodical_reminder_enabled', true);
        await _updateSettings('reading_timer_interval', 15);
        await _eyeProtectionService.setWarmthLevel(0.8);
        break;
    }

    // Reload settings to update UI
    await _loadSettings();

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${preset.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')} preset applied',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

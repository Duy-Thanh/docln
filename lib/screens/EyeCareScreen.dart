import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EyeCareScreen extends StatefulWidget {
  const EyeCareScreen({Key? key}) : super(key: key);

  @override
  _EyeCareScreenState createState() => _EyeCareScreenState();
}

class _EyeCareScreenState extends State<EyeCareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFeatureEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                text: 'CARE',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              TextSpan(
                text: '™',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  fontFeatures: [FontFeature.superscripts()],
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
              setState(() {
                _isFeatureEnabled = value;
              });
            },
          ),
          const Divider(),
          ListTile(
            enabled: _isFeatureEnabled,
            title: const Text('Blue Light Filter Intensity'),
            subtitle: const Text('Adjust the strength of blue light reduction'),
            trailing: Slider(
              value: 0.7,
              onChanged: _isFeatureEnabled ? (value) {} : null,
            ),
          ),
          ListTile(
            enabled: _isFeatureEnabled,
            title: const Text('Adaptive Brightness'),
            subtitle: const Text('Automatically adjust screen brightness'),
            trailing: Switch(
              value: _isFeatureEnabled,
              onChanged: _isFeatureEnabled ? (value) {} : null,
            ),
          ),
          ListTile(
            enabled: _isFeatureEnabled,
            title: const Text('Reading Mode'),
            subtitle: const Text('Optimize display for extended reading'),
            trailing: Switch(
              value: _isFeatureEnabled,
              onChanged: _isFeatureEnabled ? (value) {} : null,
            ),
          ),
          const Divider(),
          ListTile(
            enabled: _isFeatureEnabled,
            title: const Text('Reading Break Timer'),
            subtitle: const Text('Remind to take breaks while reading'),
            trailing: Switch(
              value: _isFeatureEnabled,
              onChanged: _isFeatureEnabled ? (value) {} : null,
            ),
          ),
          ListTile(
            enabled: _isFeatureEnabled,
            title: const Text('Break Interval'),
            subtitle: const Text('Time between reading breaks'),
            trailing: DropdownButton<String>(
              disabledHint: const Text('20 min'),
              items:
                  _isFeatureEnabled
                      ? [
                        const DropdownMenuItem(
                          value: '10',
                          child: Text('10 min'),
                        ),
                        const DropdownMenuItem(
                          value: '20',
                          child: Text('20 min'),
                        ),
                        const DropdownMenuItem(
                          value: '30',
                          child: Text('30 min'),
                        ),
                      ]
                      : null,
              onChanged: (value) {},
              value: '20',
            ),
          ),
          const SizedBox(height: 24),
          _buildHeader('Presets'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _isFeatureEnabled ? () {} : null,
                child: const Text('Day Reading'),
              ),
              ElevatedButton(
                onPressed: _isFeatureEnabled ? () {} : null,
                child: const Text('Night Reading'),
              ),
              ElevatedButton(
                onPressed: _isFeatureEnabled ? () {} : null,
                child: const Text('Low Light'),
              ),
              ElevatedButton(
                onPressed: _isFeatureEnabled ? () {} : null,
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
}

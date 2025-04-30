import 'package:flutter/material.dart';
import '../services/eye_protection_service.dart';
import '../services/pupil_adaptation_service.dart';
import 'dart:async';

class EyeProtectionSettingsScreen extends StatefulWidget {
  const EyeProtectionSettingsScreen({Key? key}) : super(key: key);

  @override
  State<EyeProtectionSettingsScreen> createState() =>
      _EyeProtectionSettingsScreenState();
}

class _EyeProtectionSettingsScreenState
    extends State<EyeProtectionSettingsScreen> {
  final EyeProtectionService _eyeProtectionService = EyeProtectionService();
  final PupilAdaptationService _pupilService = PupilAdaptationService();
  Timer? _refreshTimer;
  bool _isAdvancedExpanded = false;
  bool _isScientificInfoExpanded = false;

  @override
  void initState() {
    super.initState();

    // Update UI every 10 minutes to reflect time-based changes
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    // Update pupil adaptation based on current time
    _pupilService.adjustMelanopsinSensitivity(DateTime.now());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eye Protection'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Eye Protection Master Switch
          _buildMasterSwitch(),

          const Divider(),

          // Blue Light Filter
          _buildBlueFilterSection(),

          const SizedBox(height: 16),

          // Reading Timer
          _buildReadingTimerSection(),

          const SizedBox(height: 16),

          // Advanced Settings
          _buildAdvancedSettingsSection(),

          const SizedBox(height: 16),

          // Scientific Information
          _buildScientificInfoSection(),

          const SizedBox(height: 32),

          // Pupil Simulation Visualization
          if (_eyeProtectionService.eyeProtectionEnabled)
            _buildPupilSimulation(),
        ],
      ),
    );
  }

  Widget _buildMasterSwitch() {
    return SwitchListTile(
      title: const Text(
        'Eye Protection',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        _eyeProtectionService.eyeProtectionEnabled
            ? 'Active - ${_eyeProtectionService.isNightTime ? "Night mode" : "Day mode"}'
            : 'Disabled',
      ),
      value: _eyeProtectionService.eyeProtectionEnabled,
      onChanged: (value) async {
        await _eyeProtectionService.savePreference(
          'eye_protection_enabled',
          value,
        );
        setState(() {});
      },
      secondary: Icon(
        _eyeProtectionService.eyeProtectionEnabled
            ? Icons.visibility
            : Icons.visibility_off,
        color:
            _eyeProtectionService.eyeProtectionEnabled
                ? Theme.of(context).primaryColor
                : Colors.grey,
        size: 28,
      ),
    );
  }

  Widget _buildBlueFilterSection() {
    final effectiveBlueFilter = _eyeProtectionService.effectiveBlueFilterLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.blur_on, size: 20),
            const SizedBox(width: 8),
            Text(
              'Blue Light Filter',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${(effectiveBlueFilter * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _eyeProtectionService.blueFilterLevel,
          min: 0.0,
          max: 0.7,
          divisions: 14,
          label:
              '${(_eyeProtectionService.blueFilterLevel * 100).toStringAsFixed(0)}%',
          onChanged:
              _eyeProtectionService.eyeProtectionEnabled
                  ? (value) async {
                    await _eyeProtectionService.savePreference(
                      'blue_filter_level',
                      value,
                    );
                    setState(() {});
                  }
                  : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Off', style: TextStyle(fontSize: 12)),
            Text('Medium', style: TextStyle(fontSize: 12)),
            Text('High', style: TextStyle(fontSize: 12)),
          ],
        ),
        if (_eyeProtectionService.dynamicFilteringEnabled &&
            _eyeProtectionService.isNightTime)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Currently enhanced for evening (${(effectiveBlueFilter - _eyeProtectionService.blueFilterLevel) * 100}% boost)',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.orange.shade700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReadingTimerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer, size: 20),
            const SizedBox(width: 8),
            Text(
              'Reading Break Timer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${_eyeProtectionService.readingTimerDuration} min',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _eyeProtectionService.readingTimerDuration.toDouble(),
          min: 10,
          max: 60,
          divisions: 10,
          label: '${_eyeProtectionService.readingTimerDuration} min',
          onChanged:
              _eyeProtectionService.eyeProtectionEnabled
                  ? (value) async {
                    await _eyeProtectionService.savePreference(
                      'reading_timer_duration',
                      value.round(),
                    );
                    setState(() {});
                  }
                  : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('10 min', style: TextStyle(fontSize: 12)),
            Text('30 min', style: TextStyle(fontSize: 12)),
            Text('60 min', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Reminds you to take a break from reading based on the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildAdvancedSettingsSection() {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: EdgeInsets.zero,
      expansionCallback: (index, isExpanded) {
        setState(() {
          _isAdvancedExpanded = !isExpanded;
        });
      },
      children: [
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(
                'Advanced Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: Icon(Icons.tune),
            );
          },
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dynamic Filtering
                SwitchListTile(
                  title: const Text('Dynamic Filtering'),
                  subtitle: const Text(
                    'Automatically adjust based on time of day',
                  ),
                  value: _eyeProtectionService.dynamicFilteringEnabled,
                  onChanged:
                      _eyeProtectionService.eyeProtectionEnabled
                          ? (value) async {
                            await _eyeProtectionService.savePreference(
                              'dynamic_filtering_enabled',
                              value,
                            );
                            setState(() {});
                          }
                          : null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),

                // Adaptive Brightness
                SwitchListTile(
                  title: const Text('Adaptive Brightness'),
                  subtitle: const Text(
                    'Adjust screen brightness based on time of day',
                  ),
                  value: _eyeProtectionService.adaptiveBrightnessEnabled,
                  onChanged:
                      _eyeProtectionService.eyeProtectionEnabled
                          ? (value) async {
                            await _eyeProtectionService.savePreference(
                              'adaptive_brightness_enabled',
                              value,
                            );
                            setState(() {});
                          }
                          : null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),

                // Contrast Reduction
                const SizedBox(height: 16),
                Text(
                  'Contrast Reduction',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Slider(
                  value: _eyeProtectionService.contrastReduction,
                  min: 0.0,
                  max: 0.3,
                  divisions: 6,
                  label:
                      '${(_eyeProtectionService.contrastReduction * 100).toStringAsFixed(0)}%',
                  onChanged:
                      _eyeProtectionService.eyeProtectionEnabled
                          ? (value) async {
                            await _eyeProtectionService.savePreference(
                              'contrast_reduction',
                              value,
                            );
                            setState(() {});
                          }
                          : null,
                ),

                // Color Temperature
                const SizedBox(height: 16),
                Text(
                  'Color Temperature',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Icon(Icons.wb_sunny, color: Colors.orange),
                    Expanded(
                      child: Slider(
                        value: _eyeProtectionService.warmColorTemperature,
                        min: 1800.0,
                        max: 6500.0,
                        divisions: 19,
                        label:
                            '${_eyeProtectionService.warmColorTemperature.toStringAsFixed(0)}K',
                        onChanged:
                            _eyeProtectionService.eyeProtectionEnabled
                                ? (value) async {
                                  await _eyeProtectionService.savePreference(
                                    'warm_color_temperature',
                                    value,
                                  );
                                  setState(() {});
                                }
                                : null,
                      ),
                    ),
                    Icon(Icons.wb_sunny, color: Colors.blue.shade300),
                  ],
                ),

                // Pupil Response Compensation
                const SizedBox(height: 16),
                Text(
                  'Pupil Response Compensation',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjusts screen parameters based on how your pupils naturally respond to light',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                Slider(
                  value: _eyeProtectionService.pupilResponseCompensation,
                  min: 0.0,
                  max: 0.4,
                  divisions: 8,
                  label:
                      '${(_eyeProtectionService.pupilResponseCompensation * 100).toStringAsFixed(0)}%',
                  onChanged:
                      _eyeProtectionService.eyeProtectionEnabled
                          ? (value) async {
                            await _eyeProtectionService.savePreference(
                              'pupil_response_compensation',
                              value,
                            );
                            setState(() {});
                          }
                          : null,
                ),
              ],
            ),
          ),
          isExpanded: _isAdvancedExpanded,
        ),
      ],
    );
  }

  Widget _buildScientificInfoSection() {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: EdgeInsets.zero,
      expansionCallback: (index, isExpanded) {
        setState(() {
          _isScientificInfoExpanded = !isExpanded;
        });
      },
      children: [
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(
                'Scientific Background',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: Icon(Icons.science),
            );
          },
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScienceCard(
                  title: 'Melanopsin Photoreceptors',
                  content:
                      'Specialized cells in your retina (ipRGCs) detect blue light independently from vision, signaling your brain about environmental brightness with peak sensitivity around 480nm.',
                ),

                const SizedBox(height: 12),

                _buildScienceCard(
                  title: 'Blue Light and Circadian Rhythm',
                  content:
                      'Blue light inhibits melatonin production, which signals your brain to stay alert. This is why evening blue light exposure can disrupt your sleep cycle.',
                ),

                const SizedBox(height: 12),

                _buildScienceCard(
                  title: 'Pupillary Light Reflex',
                  content:
                      'Your pupils constrict in bright light and dilate in darkness. Blue light triggers a stronger pupillary response that remains constricted longer compared to other wavelengths.',
                ),

                const SizedBox(height: 12),

                _buildScienceCard(
                  title: 'Eye Strain Reduction',
                  content:
                      'Reducing contrast, decreasing brightness, and filtering blue light can help reduce visual fatigue during extended reading sessions.',
                ),

                const SizedBox(height: 20),

                Center(
                  child: Text(
                    'Our technology is based on peer-reviewed research in vision science.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          isExpanded: _isScientificInfoExpanded,
        ),
      ],
    );
  }

  Widget _buildScienceCard({required String title, required String content}) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(content, style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // Interactive pupil simulation visualization
  Widget _buildPupilSimulation() {
    _pupilService.respondToAmbientLight(0.4, containsBlueLight: true);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pupil Response Simulation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pupil visualization
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.brown.shade900,
                ),
                child: Center(
                  child: Container(
                    width:
                        _pupilService.currentPupilDiameter *
                        6, // Scale for visualization
                    height: _pupilService.currentPupilDiameter * 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow(
                    'Diameter',
                    '${_pupilService.currentPupilDiameter.toStringAsFixed(1)} mm',
                  ),
                  _buildStatRow(
                    'Melanopsin',
                    '${(_pupilService.melanopsinSensitivity * 100).toStringAsFixed(0)}%',
                  ),
                  _buildStatRow(
                    'Strain Level',
                    '${(_pupilService.calculateEyeStrainFactor() * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Light Level'),
          Slider(
            min: 0.1,
            max: 1.0,
            divisions: 9,
            value: 0.4, // Default light level
            onChanged: (value) {
              // Simulate pupil response to changing light levels
              setState(() {
                _pupilService.respondToAmbientLight(value);
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Dark', style: TextStyle(fontSize: 12)),
              Text('Bright', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

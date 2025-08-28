import 'package:flutter/material.dart';
import '../../dcl2/core/utils/migration_helper.dart';
import '../../dcl2/core/utils/feature_flag_service.dart';
import '../../dcl2/core/di/injection_container.dart';

/// Development settings screen for controlling DCL2 migration
class Dcl2MigrationSettingsScreen extends StatefulWidget {
  const Dcl2MigrationSettingsScreen({Key? key}) : super(key: key);
  
  @override
  State<Dcl2MigrationSettingsScreen> createState() => _Dcl2MigrationSettingsScreenState();
}

class _Dcl2MigrationSettingsScreenState extends State<Dcl2MigrationSettingsScreen> {
  FeatureFlagService? _featureFlagService;
  bool _isDcl2Available = false;
  Map<String, bool> _featureFlags = {};
  String _migrationStatus = 'not_started';
  
  @override
  void initState() {
    super.initState();
    _initializeFeatureFlags();
  }
  
  void _initializeFeatureFlags() async {
    await Dcl2MigrationHelper.initialize();
    
    setState(() {
      _isDcl2Available = isDcl2Available();
      _migrationStatus = Dcl2MigrationHelper.getMigrationStatus();
    });
    
    if (_isDcl2Available) {
      _featureFlagService = getIt<FeatureFlagService>();
      setState(() {
        _featureFlags = {
          'bookmarks': Dcl2MigrationHelper.shouldUseDcl2Bookmarks(),
          'settings': Dcl2MigrationHelper.shouldUseDcl2Settings(),
          'novels': Dcl2MigrationHelper.shouldUseDcl2Novels(),
          'reader': Dcl2MigrationHelper.shouldUseDcl2Reader(),
          'auth': Dcl2MigrationHelper.shouldUseDcl2Auth(),
        };
      });
    }
  }
  
  void _toggleFeature(String feature, bool enabled) async {
    if (_featureFlagService == null) return;
    
    await Dcl2MigrationHelper.enableDcl2Feature(feature);
    
    setState(() {
      _featureFlags[feature] = enabled;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('DCL2 $feature ${enabled ? 'enabled' : 'disabled'}'),
        backgroundColor: enabled ? Colors.green : Colors.orange,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DCL2 Migration Settings'),
        subtitle: const Text('Development Only'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            if (_isDcl2Available) ...[
              _buildFeatureFlagsCard(),
              const SizedBox(height: 16),
              _buildMigrationActionsCard(),
            ] else
              _buildNotAvailableCard(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isDcl2Available ? Icons.check_circle : Icons.error,
                  color: _isDcl2Available ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'DCL2 Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Available: ${_isDcl2Available ? 'Yes' : 'No'}'),
            Text('Migration Status: $_migrationStatus'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureFlagsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feature Flags',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enable DCL2 features gradually. Changes take effect immediately.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ..._featureFlags.entries.map((entry) {
              return SwitchListTile(
                title: Text('DCL2 ${entry.key.toUpperCase()}'),
                subtitle: Text('Use DCL2 architecture for ${entry.key} feature'),
                value: entry.value,
                onChanged: (value) => _toggleFeature(entry.key, value),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMigrationActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Migration Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Dcl2MigrationHelper.migrateBookmarks();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bookmarks migration completed'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.sync),
              label: const Text('Migrate Bookmarks'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                await Dcl2MigrationHelper.setMigrationStatus('in_progress');
                setState(() {
                  _migrationStatus = 'in_progress';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Migration status updated'),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Migration'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotAvailableCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'DCL2 Not Available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'DCL2 architecture is not properly initialized. Please check the dependency injection setup.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
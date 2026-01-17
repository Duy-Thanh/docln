import 'package:flutter/material.dart';
import 'dart:async';
import 'package:docln/core/services/background_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug screen to monitor background notification service
class BackgroundServiceDebugScreen extends StatefulWidget {
  const BackgroundServiceDebugScreen({Key? key}) : super(key: key);

  @override
  State<BackgroundServiceDebugScreen> createState() =>
      _BackgroundServiceDebugScreenState();
}

class _BackgroundServiceDebugScreenState
    extends State<BackgroundServiceDebugScreen> {
  final _service = BackgroundNotificationService();
  bool _isEnabled = false;
  DateTime? _lastCheckTime;
  DateTime? _registeredTime;
  DateTime? _lastUiRefresh;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    // Update every second to show time elapsed
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    // Force SharedPreferences to reload from disk to get updates from background isolate
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // This ensures we get the latest values
    
    final enabled = await _service.areBackgroundChecksEnabled();
    final lastCheck = await _service.getLastCheckTime();

    final registeredTimestamp = prefs.getInt('background_checks_started_at');
    final registeredTime = registeredTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(registeredTimestamp)
        : null;

    setState(() {
      _isEnabled = enabled;
      _lastCheckTime = lastCheck;
      _registeredTime = registeredTime;
      _lastUiRefresh = DateTime.now(); // Track when UI was refreshed
    });
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ${difference.inSeconds % 60}s ago';
    } else {
      return '${difference.inSeconds}s ago';
    }
  }

  String _formatNextCheck(DateTime? lastCheck) {
    if (lastCheck == null || !_isEnabled) return 'Unknown';

    final nextCheck = lastCheck.add(const Duration(minutes: 15));
    final now = DateTime.now();

    if (nextCheck.isBefore(now)) {
      return 'Due now (waiting for Android)';
    }

    final timeUntil = nextCheck.difference(now);

    if (timeUntil.inMinutes > 0) {
      return 'in ~${timeUntil.inMinutes}m ${timeUntil.inSeconds % 60}s';
    } else {
      return 'in ~${timeUntil.inSeconds}s';
    }
  }

  Color _getLastCheckColor() {
    // If last check was before service registration, it's from a previous session
    if (_lastCheckTime != null && 
        _registeredTime != null && 
        _lastCheckTime!.isBefore(_registeredTime!)) {
      return Colors.orange.shade700; // Warning color
    }
    return Colors.orange; // Normal color
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Service Debug'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildTimingCard(),
            const SizedBox(height: 16),
            _buildControlsCard(),
            const SizedBox(height: 16),
            _buildInfoCard(),
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
                  _isEnabled ? Icons.check_circle : Icons.cancel,
                  color: _isEnabled ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Background Service Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(
              'Status',
              _isEnabled ? 'ENABLED ✅' : 'DISABLED ❌',
              _isEnabled ? Colors.green : Colors.red,
            ),
            _buildInfoRow(
              'Check Interval',
              '15 minutes (Android minimum)',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Timing Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_lastUiRefresh != null)
                  Text(
                    'Updated ${_formatTimeAgo(_lastUiRefresh)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            const Divider(),
            _buildInfoRow(
              'Service Registered',
              _registeredTime != null
                  ? '${_registeredTime!.toString().split('.')[0]}\n${_formatTimeAgo(_registeredTime)}'
                  : 'Not registered',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            // Show label based on whether check is from previous session or current
            _buildInfoRow(
              _lastCheckTime != null && 
                  _registeredTime != null && 
                  _lastCheckTime!.isBefore(_registeredTime!)
                  ? 'Last Check (Old Session)'
                  : 'Last Check (This Session)',
              _lastCheckTime != null
                  ? '${_lastCheckTime!.toString().split('.')[0]}\n${_formatTimeAgo(_lastCheckTime)}'
                  : (_registeredTime != null ? 'Waiting for first check...' : 'No checks yet'),
              _getLastCheckColor(),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Next Check (Estimated)',
              _formatNextCheck(_lastCheckTime),
              Colors.purple,
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Note: Android may delay checks for battery optimization',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controls',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            ElevatedButton.icon(
              onPressed: _isEnabled ? null : _startService,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Background Service'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isEnabled ? _stopService : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Background Service'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Manual Test',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isEnabled ? _triggerManualCheck : null,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check for Updates NOW'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚡ Triggers an immediate background check without waiting 15 minutes',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Important Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• Background checks run every 15 minutes minimum\n'
              '• Android may batch or delay checks to save battery\n'
              '• Checks only run when connected to internet\n'
              '• You can close the app - service runs in background\n'
              '• First check runs ~1 minute after enabling',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startService() async {
    try {
      await _service.startPeriodicChecks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background service started! First check in ~1 minute'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopService() async {
    try {
      await _service.stopPeriodicChecks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background service stopped'),
          backgroundColor: Colors.orange,
        ),
      );
      await _loadStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _triggerManualCheck() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Triggering manual check...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );

      await _service.triggerManualCheck();

      // Wait a moment for the task to register
      await Future.delayed(const Duration(milliseconds: 500));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✅ Manual check triggered!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Watch logcat for results:\nadb logcat -s "flutter" | Select-String "BACKGROUND"',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh status after background task completes
      // Background tasks take ~15-20 seconds for 6 novels
      await Future.delayed(const Duration(seconds: 5));
      await _loadStatus();
      
      // Refresh again to ensure we catch any late updates
      await Future.delayed(const Duration(seconds: 2));
      await _loadStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error triggering manual check: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

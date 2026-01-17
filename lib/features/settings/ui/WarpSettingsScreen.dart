import 'package:flutter/material.dart';
import 'package:docln/core/services/warp_service.dart';

/// Cloudflare WARP Settings Screen
///
/// This screen allows users to:
/// - Enable/disable WARP connection
/// - View connection status
/// - Manage WARP account
/// - See traffic routing information
class WarpSettingsScreen extends StatefulWidget {
  const WarpSettingsScreen({super.key});

  @override
  State<WarpSettingsScreen> createState() => _WarpSettingsScreenState();
}

class _WarpSettingsScreenState extends State<WarpSettingsScreen> {
  final WarpService _warpService = WarpService();
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  String _currentStatus = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _initializeWarp();
    _listenToStatusChanges();
  }

  Future<void> _initializeWarp() async {
    try {
      await _warpService.initialize();
      final status = await _warpService.getStatus();
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    } catch (e) {
      debugPrint('Error initializing WARP: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error initializing WARP: $e')));
      }
    }
  }

  void _listenToStatusChanges() {
    _warpService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
  }

  Future<void> _connectToWarp() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final connected = await _warpService.connect();
      if (mounted) {
        if (connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Connected to Cloudflare WARP'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to connect to WARP'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnectFromWarp() async {
    setState(() {
      _isDisconnecting = true;
    });

    try {
      await _warpService.disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🛑 Disconnected from WARP')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDisconnecting = false;
        });
      }
    }
  }

  Future<void> _resetWarpAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset WARP Account?'),
        content: const Text(
          'This will delete your current WARP account and register a new one. '
          'You will be disconnected if currently connected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _warpService.resetWarpAccount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WARP account reset successfully')),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error resetting account: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = _warpService.isConnected;

    return Scaffold(
      appBar: AppBar(title: const Text('Cloudflare WARP'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // WARP Logo/Header
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Cloudflare WARP',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Route all app traffic through Cloudflare\'s global network',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Connection Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isConnected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isConnected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentStatus,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isConnected ? Colors.green : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🌐 All traffic is secure and routed through WARP',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Connect/Disconnect Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isConnecting || _isDisconnecting
                  ? null
                  : (isConnected ? _disconnectFromWarp : _connectToWarp),
              icon: _isConnecting || _isDisconnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isConnected ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isConnecting
                    ? 'Connecting...'
                    : _isDisconnecting
                    ? 'Disconnecting...'
                    : isConnected
                    ? 'Disconnect'
                    : 'Connect to WARP',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Information Cards
          _buildInfoCard(
            context,
            icon: Icons.speed,
            title: 'Faster Internet',
            description:
                'WARP optimizes your connection using Cloudflare\'s global network',
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            icon: Icons.lock_outline,
            title: 'Privacy & Security',
            description:
                'Encrypts all traffic between your device and the internet',
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            icon: Icons.public,
            title: 'Bypass Restrictions',
            description: 'Access blocked content by routing through Cloudflare',
          ),

          const SizedBox(height: 24),

          // Advanced Options
          Text(
            'Advanced',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: colorScheme.primary),
                  title: const Text('Account Status'),
                  subtitle: Text(
                    _warpService.hasWarpAccount()
                        ? 'WARP account registered'
                        : 'No WARP account (will auto-register)',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.orange),
                  title: const Text('Reset WARP Account'),
                  subtitle: const Text('Delete and create new account'),
                  onTap: _resetWarpAccount,
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // How it works
          _buildHowItWorksSection(context),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'How WARP Works',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStep('1', 'Creates a secure VPN tunnel using WireGuard'),
            const SizedBox(height: 12),
            _buildStep('2', 'Routes ALL app traffic through Cloudflare'),
            const SizedBox(height: 12),
            _buildStep('3', 'Encrypts data and bypasses restrictions'),
            const SizedBox(height: 12),
            _buildStep('4', 'Optimizes connection for better performance'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: colorScheme.secondary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WARP is powered by WireGuard and Cloudflare\'s global network',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}

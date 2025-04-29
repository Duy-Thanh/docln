import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wireguard_service.dart';
import '../screens/custom_toast.dart';
import 'dart:async';

class WireGuardSettingsScreen extends StatefulWidget {
  const WireGuardSettingsScreen({Key? key}) : super(key: key);

  @override
  State<WireGuardSettingsScreen> createState() =>
      _WireGuardSettingsScreenState();
}

class _WireGuardSettingsScreenState extends State<WireGuardSettingsScreen> {
  final WireGuardService _wireGuardService = WireGuardService();
  final _serverAddressController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _presharedKeyController = TextEditingController();
  final _dnsServersController = TextEditingController(text: '1.1.1.1, 8.8.8.8');

  bool _isLoading = true;
  bool _isSupported = false;
  String _connectionStatus = 'disconnected';
  String _errorMessage = '';
  StreamSubscription? _statusSubscription;

  bool get isConnected => _connectionStatus == 'connected';

  @override
  void initState() {
    super.initState();
    _initializeWireGuard();
  }

  Future<void> _initializeWireGuard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _wireGuardService.initialize();

      _isSupported = _wireGuardService.isSupported;

      if (_isSupported) {
        _statusSubscription = _wireGuardService.statusStream.listen(
          (status) {
            setState(() {
              _connectionStatus = status;
            });
          },
          onError: (e) {
            setState(() {
              _errorMessage = 'Status stream error: $e';
              _connectionStatus = 'error';
            });
          },
        );

        // Get current status
        final currentStatus = await _wireGuardService.getStatus();
        setState(() {
          _connectionStatus = currentStatus;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'WireGuard is not supported on this platform.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSupported = false;
        _errorMessage = 'Failed to initialize WireGuard: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    _privateKeyController.dispose();
    _publicKeyController.dispose();
    _presharedKeyController.dispose();
    _dnsServersController.dispose();
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _connectWireGuard() async {
    if (!_isSupported) {
      CustomToast.show(context, 'WireGuard is not supported on this device');
      return;
    }

    if (_serverAddressController.text.isEmpty ||
        _privateKeyController.text.isEmpty ||
        _publicKeyController.text.isEmpty) {
      CustomToast.show(context, 'Please fill all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _wireGuardService.connect(
        serverAddress: _serverAddressController.text,
        privateKey: _privateKeyController.text,
        publicKey: _publicKeyController.text,
        presharedKey: _presharedKeyController.text,
        dnsServers: _dnsServersController.text,
      );

      if (success) {
        CustomToast.show(context, 'WireGuard connection established');
      } else {
        CustomToast.show(context, 'Failed to connect WireGuard');
      }
    } catch (e) {
      CustomToast.show(context, 'Error connecting WireGuard: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnectWireGuard() async {
    if (!_isSupported) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _wireGuardService.disconnect();
      if (success) {
        CustomToast.show(context, 'WireGuard disconnected');
      } else {
        CustomToast.show(context, 'Failed to disconnect WireGuard');
      }
    } catch (e) {
      CustomToast.show(context, 'Error disconnecting WireGuard: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pasteFromClipboard(TextEditingController controller) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      controller.text = clipboardData.text!;
    }
  }

  void _importFromConfig() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Import WireGuard Config'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Paste your WireGuard configuration below:'),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '[Interface]\nPrivateKey = xxx\n...',
                  ),
                  onChanged: (text) {
                    _parseWireGuardConfig(text);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Import'),
              ),
            ],
          ),
    );
  }

  void _parseWireGuardConfig(String config) {
    // Very basic parsing - a production version would be more robust
    final lines = config.split('\n');
    String? privateKey, publicKey, presharedKey, endpoint, dns;

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.startsWith('PrivateKey')) {
        privateKey = trimmedLine.split('=')[1].trim();
      } else if (trimmedLine.startsWith('PublicKey')) {
        publicKey = trimmedLine.split('=')[1].trim();
      } else if (trimmedLine.startsWith('PresharedKey')) {
        presharedKey = trimmedLine.split('=')[1].trim();
      } else if (trimmedLine.startsWith('Endpoint')) {
        endpoint = trimmedLine.split('=')[1].trim();
      } else if (trimmedLine.startsWith('DNS')) {
        dns = trimmedLine.split('=')[1].trim();
      }
    }

    if (privateKey != null) _privateKeyController.text = privateKey;
    if (publicKey != null) _publicKeyController.text = publicKey;
    if (presharedKey != null) _presharedKeyController.text = presharedKey;
    if (endpoint != null) _serverAddressController.text = endpoint;
    if (dns != null) _dnsServersController.text = dns;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WireGuard Settings')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_isSupported
              ? _buildUnsupportedView()
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildConfigForm(),
                  ],
                ),
              ),
      floatingActionButton:
          !_isSupported || _isLoading
              ? null
              : FloatingActionButton.extended(
                onPressed:
                    isConnected ? _disconnectWireGuard : _connectWireGuard,
                icon: Icon(isConnected ? Icons.link_off : Icons.link),
                label: Text(isConnected ? 'Disconnect' : 'Connect'),
                backgroundColor: isConnected ? Colors.red : Colors.blue,
              ),
    );
  }

  Widget _buildUnsupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.vpn_lock_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'WireGuard Not Available',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'WireGuard VPN is not supported on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Text(
              'WireGuard requires Android 5.0+ or iOS 14.0+ with appropriate VPN permissions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final Color statusColor =
        _connectionStatus == 'connected'
            ? Colors.green
            : _connectionStatus == 'connecting'
            ? Colors.orange
            : Colors.red;

    String statusText;
    IconData statusIcon;

    switch (_connectionStatus) {
      case 'connected':
        statusText = 'Connected';
        statusIcon = Icons.check_circle;
        break;
      case 'connecting':
        statusText = 'Connecting...';
        statusIcon = Icons.pending;
        break;
      case 'disconnecting':
        statusText = 'Disconnecting...';
        statusIcon = Icons.pending;
        break;
      case 'authenticating':
        statusText = 'Authenticating...';
        statusIcon = Icons.security;
        break;
      case 'denied':
        statusText = 'Permission Denied';
        statusIcon = Icons.block;
        break;
      case 'reconnect':
        statusText = 'Reconnecting...';
        statusIcon = Icons.autorenew;
        break;
      case 'error':
        statusText = 'Error';
        statusIcon = Icons.error;
        break;
      default:
        statusText = 'Disconnected';
        statusIcon = Icons.cancel;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Status: $statusText',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'WireGuard creates an encrypted tunnel for your app traffic, '
              'helping bypass network restrictions while maintaining security.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _importFromConfig,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextFieldWithPaste(
              controller: _serverAddressController,
              label: 'Server Endpoint',
              hint: 'vpn.example.com:51820',
              icon: Icons.dns,
            ),
            const SizedBox(height: 12),
            _buildTextFieldWithPaste(
              controller: _privateKeyController,
              label: 'Private Key',
              hint: 'Your WireGuard private key',
              icon: Icons.vpn_key,
            ),
            const SizedBox(height: 12),
            _buildTextFieldWithPaste(
              controller: _publicKeyController,
              label: 'Server Public Key',
              hint: 'Remote peer public key',
              icon: Icons.key,
            ),
            const SizedBox(height: 12),
            _buildTextFieldWithPaste(
              controller: _presharedKeyController,
              label: 'Preshared Key (Optional)',
              hint: 'Preshared key for additional security',
              icon: Icons.security,
              required: false,
            ),
            const SizedBox(height: 12),
            _buildTextFieldWithPaste(
              controller: _dnsServersController,
              label: 'DNS Servers',
              hint: '1.1.1.1, 8.8.8.8',
              icon: Icons.dns,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldWithPaste({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool required = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.content_paste),
          onPressed: () => _pasteFromClipboard(controller),
          tooltip: 'Paste from clipboard',
        ),
      ),
    );
  }
}

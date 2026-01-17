import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';

/// A service to manage WireGuard tunnel connections
/// This service creates a WireGuard tunnel for secure traffic routing
/// that only affects app traffic and not the entire device
class WireGuardService {
  static final WireGuardService _instance = WireGuardService._internal();
  factory WireGuardService() => _instance;
  WireGuardService._internal();

  final WireGuardFlutterInterface _wireGuard = WireGuardFlutter.instance;
  bool _isInitialized = false;
  bool _isSupported = false;
  final StreamController<String> _statusStreamController =
      StreamController<String>.broadcast();

  /// Current connection status stream
  Stream<String> get statusStream => _statusStreamController.stream;

  /// Check if WireGuard is supported on this platform
  bool get isSupported => _isSupported;

  /// Initialize the WireGuard service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check platform support
      if (!Platform.isAndroid && !Platform.isIOS) {
        debugPrint('WireGuard is only supported on Android and iOS');
        _isSupported = false;
        return;
      }

      // Initialize WireGuard with a tunnel name
      await _wireGuard.initialize(interfaceName: 'docln_tunnel');

      // Set up listener for tunnel status changes
      _wireGuard.vpnStageSnapshot.listen(
        (stage) {
          _statusStreamController.add(_vpnStageToString(stage));
        },
        onError: (e) {
          debugPrint('WireGuard status stream error: $e');
          _statusStreamController.add('error');
        },
      );

      _isInitialized = true;
      _isSupported = true;
    } catch (e) {
      debugPrint('Failed to initialize WireGuard: $e');
      _isSupported = false;
      // Add error state to stream
      _statusStreamController.add('error');
      rethrow;
    }
  }

  /// Convert VpnStage enum to String
  String _vpnStageToString(VpnStage stage) {
    return stage.toString().split('.').last.toLowerCase();
  }

  /// Connect to WireGuard tunnel using provided configuration
  Future<bool> connect({
    required String serverAddress,
    required String privateKey,
    required String publicKey,
    String presharedKey = '',
    String dnsServers = '1.1.1.1, 8.8.8.8',
  }) async {
    if (!_isSupported) {
      debugPrint('WireGuard is not supported on this platform');
      return false;
    }

    if (!_isInitialized) {
      try {
        await initialize();
        if (!_isSupported) return false;
      } catch (e) {
        debugPrint('Failed to initialize WireGuard: $e');
        return false;
      }
    }

    try {
      // Generate WireGuard configuration
      final config = _generateWireGuardConfig(
        serverAddress: serverAddress,
        privateKey: privateKey,
        publicKey: publicKey,
        presharedKey: presharedKey,
        dnsServers: dnsServers,
      );

      // Connect with the generated configuration
      await _wireGuard.startVpn(
        wgQuickConfig: config,
        providerBundleIdentifier: 'com.docln.app',
        serverAddress: serverAddress,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to connect to WireGuard: $e');
      return false;
    }
  }

  /// Disconnect from WireGuard tunnel
  Future<bool> disconnect() async {
    if (!_isSupported || !_isInitialized) return false;

    try {
      await _wireGuard.stopVpn();
      return true;
    } catch (e) {
      debugPrint('Failed to disconnect WireGuard: $e');
      return false;
    }
  }

  /// Get current connection status
  Future<String> getStatus() async {
    if (!_isSupported) return 'unsupported';
    if (!_isInitialized) return 'disconnected';

    try {
      final status = await _wireGuard.stage();
      return _vpnStageToString(status);
    } catch (e) {
      debugPrint('Failed to get WireGuard status: $e');
      return 'unknown';
    }
  }

  String _generateWireGuardConfig({
    required String serverAddress,
    required String privateKey,
    required String publicKey,
    String presharedKey = '',
    String dnsServers = '1.1.1.1, 8.8.8.8',
  }) {
    // Extract host and port from server address
    String host = serverAddress;
    String port = '51820'; // Default WireGuard port

    if (serverAddress.contains(':')) {
      final parts = serverAddress.split(':');
      host = parts[0];
      port = parts[1];
    }

    // Build configuration string
    String config = '''
[Interface]
PrivateKey = $privateKey
Address = 10.0.0.2/32
DNS = $dnsServers

[Peer]
PublicKey = $publicKey
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $host:$port
''';

    // Add preshared key if provided
    if (presharedKey.isNotEmpty) {
      config = config.replaceFirst(
        '[Peer]',
        '[Peer]\nPresharedKey = $presharedKey',
      );
    }

    return config;
  }

  /// Dispose resources
  void dispose() {
    _statusStreamController.close();
  }
}

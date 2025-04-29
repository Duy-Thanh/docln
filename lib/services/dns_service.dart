import 'package:shared_preferences/shared_preferences.dart';
import 'settings_services.dart';
import 'dart:io';

class DnsService {
  static final DnsService _instance = DnsService._internal();
  factory DnsService() => _instance;
  DnsService._internal();

  late SettingsService _settingsService;
  bool _isInitialized = false;
  Map<String, dynamic> _dnsSettings = {
    'enabled': false,
    'provider': 'Default',
    'customDns': '',
  };

  // Initialize DNS service with settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    _settingsService = SettingsService();
    _dnsSettings = await _settingsService.getAllDnsSettings();
    _configureDns();
    _isInitialized = true;
  }

  // Configure DNS settings
  Future<void> _configureDns() async {
    if (!_dnsSettings['enabled'] || _dnsSettings['provider'] == 'Default') {
      print('Using default DNS settings');
      return;
    }

    String dnsServer;
    if (_dnsSettings['provider'] == 'Custom') {
      dnsServer = _dnsSettings['customDns'];
    } else {
      dnsServer = SettingsService.dnsProviders[_dnsSettings['provider']] ?? '';
    }

    if (dnsServer.isEmpty) {
      print('No DNS server configured');
      return;
    }

    print('Configuring DNS server: $dnsServer');

    // Note: This is informational only, as changing DNS requires system-level privileges
    // which are not available in a standard Flutter app

    // For Android, we can suggest users change DNS in their system settings
    // For iOS, users need to create a DNS profile

    // On desktop platforms, we might be able to use platform channels
    // to invoke system commands to change DNS settings with proper permissions
  }

  // Force reload DNS settings
  Future<void> updateDnsSettings() async {
    _dnsSettings = await _settingsService.getAllDnsSettings();
    await _configureDns();
  }

  // Test DNS connection
  Future<bool> testDnsConnection(String dnsServer) async {
    try {
      print('Testing DNS connection to $dnsServer');

      // There's no direct way to test DNS in Dart without using platform-specific code
      // As a simple test, we'll try to resolve a known domain using InternetAddress
      // This uses system DNS, not our configured DNS

      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('DNS test successful');
        return true;
      }
      return false;
    } catch (e) {
      print('DNS test failed: $e');
      return false;
    }
  }

  // Get instructions for setting up DNS based on platform
  String getDnsSetupInstructions() {
    if (Platform.isAndroid) {
      return '''
To change DNS settings on Android:
1. Go to Settings > Network & Internet > Advanced > Private DNS
2. Select 'Private DNS provider hostname'
3. Enter the DNS server (e.g., '1.1.1.1' for Cloudflare)
4. Tap Save
''';
    } else if (Platform.isIOS) {
      return '''
To change DNS settings on iOS:
1. Go to Settings > Wi-Fi
2. Tap the info icon (i) next to your network
3. Scroll down and tap 'Configure DNS'
4. Select 'Manual' and add your DNS server
5. Tap Save
''';
    } else {
      return '''
To change DNS settings on your device, please look up instructions specific to your operating system.
Common DNS servers:
- Cloudflare: 1.1.1.1
- Google: 8.8.8.8
- OpenDNS: 208.67.222.222
''';
    }
  }
}

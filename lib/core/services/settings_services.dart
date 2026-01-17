import 'preferences_service.dart';

class SettingsService {
  static const String _serverKey = 'current_server';
  static const String _dataSaverKey = 'data_saver';
  static const String _proxyEnabledKey = 'proxy_enabled';
  static const String _proxyTypeKey = 'proxy_type';
  static const String _proxyAddressKey = 'proxy_address';
  static const String _proxyPortKey = 'proxy_port';
  static const String _proxyUsernameKey = 'proxy_username';
  static const String _proxyPasswordKey = 'proxy_password';
  static const String _dnsEnabledKey = 'dns_enabled';
  static const String _dnsProviderKey = 'dns_provider';
  static const String _customDnsKey = 'custom_dns';

  // Proxy presets
  static const Map<String, Map<String, dynamic>> proxyPresets = {
    'None': {'address': '', 'port': ''},
    'Open Proxy 1': {'address': '91.92.209.35', 'port': '3128'},
    'Open Proxy 2': {'address': '45.173.6.5', 'port': '999'},
    'Open Proxy 3': {'address': '103.151.40.25', 'port': '80'},
    'Google Proxy': {'address': '34.124.225.130', 'port': '8080'},
    'Microsoft Azure': {'address': '20.205.0.121', 'port': '8123'},
    'HTTP SOCKS5': {'address': '216.137.184.253', 'port': '80'},
    'Custom': {'address': '', 'port': ''},
  };

  // DNS providers
  static const Map<String, String> dnsProviders = {
    'Default': '',
    'Cloudflare': '1.1.1.1',
    'Cloudflare Secondary': '1.0.0.1',
    'Google': '8.8.8.8',
    'Google Secondary': '8.8.4.4',
    'OpenDNS': '208.67.222.222',
    'OpenDNS Secondary': '208.67.220.220',
    'Quad9': '9.9.9.9',
    'Custom': '',
  };

  static final SettingsService _instance = SettingsService._internal();

  // Preferences service instance
  final PreferencesService _prefsService = PreferencesService();

  // Flag to track initialization
  bool _initialized = false;

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  // Initialize the preferences service
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _prefsService.initialize();
      _initialized = true;
    }
  }

  Future<void> saveCurrentServer(String server) async {
    await _ensureInitialized();
    await _prefsService.setString(_serverKey, server);
  }

  Future<String> getCurrentServer() async {
    await _ensureInitialized();
    return _prefsService.getString(_serverKey);
  }

  Future<void> setDataSaver(bool enabled) async {
    await _ensureInitialized();
    await _prefsService.setBool(_dataSaverKey, enabled);
  }

  Future<bool> getDataSaver() async {
    await _ensureInitialized();
    return _prefsService.getBool(_dataSaverKey, defaultValue: false);
  }

  // Proxy settings
  Future<bool> isProxyEnabled() async {
    await _ensureInitialized();
    return _prefsService.getBool(_proxyEnabledKey, defaultValue: false);
  }

  Future<void> setProxyEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefsService.setBool(_proxyEnabledKey, enabled);
  }

  Future<String> getProxyType() async {
    await _ensureInitialized();
    return _prefsService.getString(_proxyTypeKey, defaultValue: 'None');
  }

  Future<void> setProxyType(String type) async {
    await _ensureInitialized();
    await _prefsService.setString(_proxyTypeKey, type);
  }

  Future<String> getProxyAddress() async {
    await _ensureInitialized();
    return _prefsService.getString(_proxyAddressKey, defaultValue: '');
  }

  Future<void> setProxyAddress(String address) async {
    await _ensureInitialized();
    await _prefsService.setString(_proxyAddressKey, address);
  }

  Future<String> getProxyPort() async {
    await _ensureInitialized();
    return _prefsService.getString(_proxyPortKey, defaultValue: '');
  }

  Future<void> setProxyPort(String port) async {
    await _ensureInitialized();
    await _prefsService.setString(_proxyPortKey, port);
  }

  Future<String> getProxyUsername() async {
    await _ensureInitialized();
    return _prefsService.getString(_proxyUsernameKey, defaultValue: '');
  }

  Future<void> setProxyUsername(String username) async {
    await _ensureInitialized();
    await _prefsService.setString(_proxyUsernameKey, username);
  }

  Future<String> getProxyPassword() async {
    await _ensureInitialized();
    return _prefsService.getString(_proxyPasswordKey, defaultValue: '');
  }

  Future<void> setProxyPassword(String password) async {
    await _ensureInitialized();
    await _prefsService.setString(_proxyPasswordKey, password);
  }

  // DNS settings
  Future<bool> isDnsEnabled() async {
    await _ensureInitialized();
    return _prefsService.getBool(_dnsEnabledKey, defaultValue: false);
  }

  Future<void> setDnsEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefsService.setBool(_dnsEnabledKey, enabled);
  }

  Future<String> getDnsProvider() async {
    await _ensureInitialized();
    return _prefsService.getString(_dnsProviderKey, defaultValue: 'Default');
  }

  Future<void> setDnsProvider(String provider) async {
    await _ensureInitialized();
    await _prefsService.setString(_dnsProviderKey, provider);
  }

  Future<String> getCustomDns() async {
    await _ensureInitialized();
    return _prefsService.getString(_customDnsKey, defaultValue: '');
  }

  Future<void> setCustomDns(String dns) async {
    await _ensureInitialized();
    await _prefsService.setString(_customDnsKey, dns);
  }

  // Helper method to get all proxy settings at once
  Future<Map<String, dynamic>> getAllProxySettings() async {
    final enabled = await isProxyEnabled();
    final type = await getProxyType();
    final address = await getProxyAddress();
    final port = await getProxyPort();
    final username = await getProxyUsername();
    final password = await getProxyPassword();

    return {
      'enabled': enabled,
      'type': type,
      'address': address,
      'port': port,
      'username': username,
      'password': password,
    };
  }

  // Helper method to get all DNS settings at once
  Future<Map<String, dynamic>> getAllDnsSettings() async {
    final enabled = await isDnsEnabled();
    final provider = await getDnsProvider();
    final customDns = await getCustomDns();

    return {'enabled': enabled, 'provider': provider, 'customDns': customDns};
  }
}

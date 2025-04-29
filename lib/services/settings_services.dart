import 'package:shared_preferences/shared_preferences.dart';

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

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  Future<void> saveCurrentServer(String server) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, server);
  }

  Future<String?> getCurrentServer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverKey);
  }

  Future<void> setDataSaver(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataSaverKey, enabled);
  }

  Future<bool> getDataSaver() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dataSaverKey) ?? false;
  }

  // Proxy settings
  Future<bool> isProxyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proxyEnabledKey) ?? false;
  }

  Future<void> setProxyEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proxyEnabledKey, enabled);
  }

  Future<String> getProxyType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_proxyTypeKey) ?? 'None';
  }

  Future<void> setProxyType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyTypeKey, type);
  }

  Future<String> getProxyAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_proxyAddressKey) ?? '';
  }

  Future<void> setProxyAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyAddressKey, address);
  }

  Future<String> getProxyPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_proxyPortKey) ?? '';
  }

  Future<void> setProxyPort(String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyPortKey, port);
  }

  Future<String> getProxyUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_proxyUsernameKey) ?? '';
  }

  Future<void> setProxyUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyUsernameKey, username);
  }

  Future<String> getProxyPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_proxyPasswordKey) ?? '';
  }

  Future<void> setProxyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyPasswordKey, password);
  }

  // DNS settings
  Future<bool> isDnsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dnsEnabledKey) ?? false;
  }

  Future<void> setDnsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dnsEnabledKey, enabled);
  }

  Future<String> getDnsProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dnsProviderKey) ?? 'Default';
  }

  Future<void> setDnsProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dnsProviderKey, provider);
  }

  Future<String> getCustomDns() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customDnsKey) ?? '';
  }

  Future<void> setCustomDns(String dns) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customDnsKey, dns);
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

import 'package:flutter/material.dart';
import 'package:docln/core/services/settings_services.dart';
import 'package:docln/core/services/proxy_service.dart';
import 'package:docln/core/services/dns_service.dart';
import 'package:flutter/foundation.dart';

class NetworkSettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  final ProxyService _proxyService = ProxyService();
  final DnsService _dnsService = DnsService();

  // Proxy State
  bool _isProxyEnabled = false;
  String _proxyType = 'None';
  String _proxyAddress = '';
  String _proxyPort = '';
  String _proxyUsername = '';
  String _proxyPassword = '';

  // DNS State
  bool _isDnsEnabled = false;
  String _dnsProvider = 'Default';
  String _customDns = '';

  // Loading State
  bool _isLoading = false;

  // Getters
  bool get isProxyEnabled => _isProxyEnabled;
  String get proxyType => _proxyType;
  String get proxyAddress => _proxyAddress;
  String get proxyPort => _proxyPort;
  String get proxyUsername => _proxyUsername;
  String get proxyPassword => _proxyPassword;

  bool get isDnsEnabled => _isDnsEnabled;
  String get dnsProvider => _dnsProvider;
  String get customDns => _customDns;

  bool get isLoading => _isLoading;

  // Constructor
  NetworkSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load Proxy
      _isProxyEnabled = await _settingsService.isProxyEnabled();
      _proxyType = await _settingsService.getProxyType();
      _proxyAddress = await _settingsService.getProxyAddress();
      _proxyPort = await _settingsService.getProxyPort();
      _proxyUsername = await _settingsService.getProxyUsername();
      _proxyPassword = await _settingsService.getProxyPassword();

      // Load DNS
      _isDnsEnabled = await _settingsService.isDnsEnabled();
      _dnsProvider = await _settingsService.getDnsProvider();
      _customDns = await _settingsService.getCustomDns();
    } catch (e) {
      debugPrint('Error loading network settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Proxy Actions
  void setProxyEnabled(bool value) {
    _isProxyEnabled = value;
    notifyListeners();
  }

  void setProxyType(String value) {
    _proxyType = value;
    if (value != 'Custom') {
      final preset = SettingsService.proxyPresets[value];
      if (preset != null) {
        _proxyAddress = preset['address'] as String;
        _proxyPort = preset['port'] as String;
      }
    }
    notifyListeners();
  }

  void setProxyAddress(String value) {
    _proxyAddress = value;
    notifyListeners();
  }

  void setProxyPort(String value) {
    _proxyPort = value;
    notifyListeners();
  }

  void setProxyUsername(String value) {
    _proxyUsername = value;
    notifyListeners();
  }

  void setProxyPassword(String value) {
    _proxyPassword = value;
    notifyListeners();
  }

  // DNS Actions
  void setDnsEnabled(bool value) {
    _isDnsEnabled = value;
    notifyListeners();
  }

  void setDnsProvider(String value) {
    _dnsProvider = value;
    notifyListeners();
  }

  void setCustomDns(String value) {
    _customDns = value;
    notifyListeners();
  }

  // Save changes
  Future<void> saveSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _settingsService.setProxyEnabled(_isProxyEnabled),
        _settingsService.setProxyType(_proxyType),
        _settingsService.setProxyAddress(_proxyAddress),
        _settingsService.setProxyPort(_proxyPort),
        _settingsService.setProxyUsername(_proxyUsername),
        _settingsService.setProxyPassword(_proxyPassword),

        _settingsService.setDnsEnabled(_isDnsEnabled),
        _settingsService.setDnsProvider(_dnsProvider),
        _settingsService.setCustomDns(_customDns),
      ]);

      // Apply changes
      await _proxyService.updateProxySettings();
      await _dnsService.updateDnsSettings();
    } catch (e) {
      debugPrint("Error saving network settings: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Revert settings
  Future<void> revertSettings() async {
    await _loadSettings();
  }

  // Test Proxy
  Future<int> testProxyConnection() async {
    if (!_isProxyEnabled) return -1; // Not enabled

    try {
      // Temporarily apply current state to test (simulated by saving to a temp service instance usually,
      // but here we might need to actually apply them to the service to test)

      // We will misuse the main service for testing as in the original code
      await _settingsService.setProxyEnabled(true);
      await _settingsService.setProxyType(_proxyType);
      await _settingsService.setProxyAddress(_proxyAddress);
      await _settingsService.setProxyPort(_proxyPort);
      await _settingsService.setProxyUsername(_proxyUsername);
      await _settingsService.setProxyPassword(_proxyPassword);

      await _proxyService.updateProxySettings();

      final response = await _proxyService.get(
        Uri.parse('https://www.google.com'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        },
      );
      return response.statusCode;
    } catch (e) {
      debugPrint('Proxy Test Error: $e');
      return 0; // Error
    }
  }
}

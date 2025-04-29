import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_services.dart';
import 'dart:async';

class ProxyService {
  static final ProxyService _instance = ProxyService._internal();
  factory ProxyService() => _instance;
  ProxyService._internal();

  late SettingsService _settingsService;
  late http.Client _client;
  bool _isInitialized = false;
  Map<String, dynamic> _proxySettings = {
    'enabled': false,
    'type': 'None',
    'address': '',
    'port': '',
    'username': '',
    'password': '',
  };

  // Initialize proxy service with settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    _settingsService = SettingsService();
    _proxySettings = await _settingsService.getAllProxySettings();
    _configureClient();
    _isInitialized = true;
  }

  // Configure HTTP client with proxy settings
  void _configureClient() {
    if (!_proxySettings['enabled'] || _proxySettings['type'] == 'None') {
      _client = http.Client();
      return;
    }

    // Configure proxy settings
    final httpClient = HttpClient();
    final address = _proxySettings['address'];
    final port = int.tryParse(_proxySettings['port'] ?? '0') ?? 0;

    if (address.isNotEmpty && port > 0) {
      // Use a proper proxy URL format
      final proxyUrl = '$address:$port';
      final proxyType = _proxySettings['type'];
      print('Configuring proxy: $proxyUrl (Type: $proxyType)');

      // Set the proxy based on type
      httpClient.findProxy = (uri) {
        // For different proxy types
        if (proxyType.contains('SOCKS')) {
          return 'SOCKS $proxyUrl';
        } else {
          return 'PROXY $proxyUrl';
        }
      };

      // Configure proxy credentials if provided
      final username = _proxySettings['username'];
      final password = _proxySettings['password'];
      if (username.isNotEmpty && password.isNotEmpty) {
        httpClient.authenticate = (uri, scheme, realm) {
          httpClient.addCredentials(
            Uri.parse('${uri.scheme}://${uri.host}:${uri.port}'),
            realm ?? '',
            HttpClientBasicCredentials(username, password),
          );
          return Future.value(true);
        };
      }
    }

    // Configure for better reliability
    httpClient.idleTimeout = const Duration(seconds: 15);
    httpClient.connectionTimeout = const Duration(seconds: 30);
    httpClient.maxConnectionsPerHost = 8;

    // Configure SSL settings to be more permissive to handle various scenarios
    httpClient.badCertificateCallback = (cert, host, port) => true;

    _client = IOClient(httpClient);
  }

  // Force reload proxy settings
  Future<void> updateProxySettings() async {
    _proxySettings = await _settingsService.getAllProxySettings();
    _configureClient();
  }

  // Get method with proxy support
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    if (!_isInitialized) await initialize();

    // Ensure URI has a proper scheme
    final fixedUrl = _ensureProperUri(url);

    // Add default headers if none provided or merge with existing
    final Map<String, String> modifiedHeaders = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Connection': 'keep-alive',
      ...?headers,
    };

    try {
      return await _client
          .get(fixedUrl, headers: modifiedHeaders)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );
    } catch (e) {
      // If request fails, try with fallback client (direct connection)
      if (_proxySettings['enabled']) {
        print('Request failed with proxy, trying direct connection: $e');
        return http
            .get(fixedUrl, headers: modifiedHeaders)
            .timeout(
              const Duration(seconds: 15),
              onTimeout:
                  () => throw TimeoutException('Direct request timed out'),
            );
      }
      rethrow;
    }
  }

  // Post method with proxy support
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    if (!_isInitialized) await initialize();

    // Ensure URI has a proper scheme
    final fixedUrl = _ensureProperUri(url);

    // Add default headers if none provided or merge with existing
    final Map<String, String> modifiedHeaders = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Connection': 'keep-alive',
      'Content-Type': 'application/x-www-form-urlencoded',
      ...?headers,
    };

    try {
      return await _client
          .post(
            fixedUrl,
            headers: modifiedHeaders,
            body: body,
            encoding: encoding,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );
    } catch (e) {
      // If request fails, try with fallback client (direct connection)
      if (_proxySettings['enabled']) {
        print('Request failed with proxy, trying direct connection: $e');
        return http
            .post(
              fixedUrl,
              headers: modifiedHeaders,
              body: body,
              encoding: encoding,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout:
                  () => throw TimeoutException('Direct request timed out'),
            );
      }
      rethrow;
    }
  }

  // Helper method to fix URI issues
  Uri _ensureProperUri(Uri uri) {
    // Check for URI without scheme and fix it
    if (uri.scheme.isEmpty) {
      final fixedUri = Uri.parse(
        'https://${uri.toString().replaceAll(RegExp('^//'), '')}',
      );
      print('Fixed URI scheme: $uri -> $fixedUri');
      return fixedUri;
    }
    return uri;
  }

  // Close the client when done
  void close() {
    _client.close();
  }
}

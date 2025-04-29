import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'proxy_service.dart';

/// A wrapper around HTTP client that enforces using the proxy service
/// Other services should use this instead of directly using http client
class AppHttpClient {
  static final AppHttpClient _instance = AppHttpClient._internal();
  factory AppHttpClient() => _instance;
  AppHttpClient._internal();

  final ProxyService _proxyService = ProxyService();
  bool _isInitialized = false;

  /// Initialize the HTTP client with proxy settings
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _proxyService.initialize();
      _isInitialized = true;
    }
  }

  /// Make a GET request using the proxy settings
  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    if (!_isInitialized) await initialize();

    // Ensure URL has a scheme (http:// or https://)
    String formattedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      formattedUrl = 'https://${url.replaceAll(RegExp('^//'), '')}';
      print('Fixed URL format: $url -> $formattedUrl');
    }

    return _proxyService.get(Uri.parse(formattedUrl), headers: headers);
  }

  /// Make a POST request using the proxy settings
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    if (!_isInitialized) await initialize();

    // Ensure URL has a scheme (http:// or https://)
    String formattedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      formattedUrl = 'https://${url.replaceAll(RegExp('^//'), '')}';
      print('Fixed URL format: $url -> $formattedUrl');
    }

    return _proxyService.post(
      Uri.parse(formattedUrl),
      headers: headers,
      body: body,
      encoding: encoding,
    );
  }

  /// Update proxy settings (call this after settings change)
  Future<void> updateProxySettings() async {
    await _proxyService.updateProxySettings();
  }
}

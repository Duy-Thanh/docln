import 'dart:convert';
import 'package:flutter/material.dart';
import 'preferences_service.dart';

/// Server Management Service
/// 
/// Handles server selection, URL resolution, and prevents data corruption
/// from server changes. All novel URLs are stored as relative paths and
/// resolved dynamically based on the current server.
class ServerManagementService extends ChangeNotifier {
  static final ServerManagementService _instance =
      ServerManagementService._internal();
  factory ServerManagementService() => _instance;
  ServerManagementService._internal();

  final PreferencesService _prefsService = PreferencesService();
  
  static const String _serverKey = 'current_server';
  static const String _serverHistoryKey = 'server_history';
  
  // Available servers - must match CrawlerService.servers
  static const List<String> availableServers = [
    'https://docln.sbs',
    'https://ln.hako.vn',
    'https://docln.net',
    'https://hako.re',
    'https://ln.hako.re',
    'https://ln.hako.vip',
    'https://docln.org',
    'https://docln.co',
    'https://docln.cc',
    'https://docln.me',
  ];
  
  static const String defaultServer = 'https://ln.hako.vn';
  
  String _currentServer = defaultServer;
  List<String> _serverHistory = [];
  bool _isInitialized = false;

  String get currentServer => _currentServer;
  List<String> get serverHistory => _serverHistory;
  bool get isInitialized => _isInitialized;

  /// Initialize server service and load saved server
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _prefsService.initialize();
      
      // Load current server
      final savedServer = _prefsService.getString(
        _serverKey,
        defaultValue: defaultServer,
      );
      
      // Validate saved server
      if (availableServers.contains(savedServer)) {
        _currentServer = savedServer;
      } else {
        debugPrint('⚠️ Invalid saved server: $savedServer, using default');
        _currentServer = defaultServer;
        await _prefsService.setString(_serverKey, defaultServer);
      }
      
      // Load server history
      final historyJson = _prefsService.getString(
        _serverHistoryKey,
        defaultValue: '[]',
      );
      final historyList = jsonDecode(historyJson) as List<dynamic>;
      _serverHistory = historyList.cast<String>();
      
      _isInitialized = true;
      debugPrint('✅ ServerManagementService initialized: $_currentServer');
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing ServerManagementService: $e');
      _currentServer = defaultServer;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Change the current server
  Future<bool> setServer(String server) async {
    try {
      if (!availableServers.contains(server)) {
        debugPrint('❌ Invalid server: $server');
        return false;
      }

      if (_currentServer == server) {
        debugPrint('ℹ️ Server already set to: $server');
        return true;
      }

      final oldServer = _currentServer;
      _currentServer = server;
      
      // Save to preferences
      await _prefsService.setString(_serverKey, server);
      
      // Add to history
      if (!_serverHistory.contains(oldServer)) {
        _serverHistory.add(oldServer);
        final historyJson = jsonEncode(_serverHistory);
        await _prefsService.setString(_serverHistoryKey, historyJson);
      }
      
      debugPrint('✅ Server changed: $oldServer → $server');
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('❌ Error setting server: $e');
      return false;
    }
  }

  /// Convert absolute URL to relative path
  /// 
  /// Examples:
  /// - https://ln.hako.vn/truyen/123 → /truyen/123
  /// - https://docln.net/truyen/456 → /truyen/456
  String toRelativePath(String absoluteUrl) {
    try {
      // Already relative
      if (!absoluteUrl.startsWith('http')) {
        return absoluteUrl.startsWith('/') ? absoluteUrl : '/$absoluteUrl';
      }

      final uri = Uri.parse(absoluteUrl);
      String path = uri.path;
      
      // Include query parameters if present
      if (uri.query.isNotEmpty) {
        path += '?${uri.query}';
      }
      
      // Ensure leading slash
      if (!path.startsWith('/')) {
        path = '/$path';
      }
      
      return path;
    } catch (e) {
      debugPrint('⚠️ Error converting to relative path: $absoluteUrl, $e');
      return absoluteUrl;
    }
  }

  /// Convert relative path to absolute URL using current server
  /// 
  /// Examples:
  /// - /truyen/123 → https://ln.hako.vn/truyen/123
  /// - truyen/456 → https://ln.hako.vn/truyen/456
  String toAbsoluteUrl(String relativePath) {
    try {
      // Already absolute
      if (relativePath.startsWith('http')) {
        return relativePath;
      }

      // Ensure leading slash
      String path = relativePath.startsWith('/') 
          ? relativePath 
          : '/$relativePath';
      
      return '$_currentServer$path';
    } catch (e) {
      debugPrint('⚠️ Error converting to absolute URL: $relativePath, $e');
      return '$_currentServer/$relativePath';
    }
  }

  /// Extract server domain from URL
  /// 
  /// Examples:
  /// - https://ln.hako.vn/truyen/123 → https://ln.hako.vn
  /// - https://docln.net/truyen/456 → https://docln.net
  String extractServerFromUrl(String url) {
    try {
      if (!url.startsWith('http')) {
        return _currentServer;
      }

      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}';
    } catch (e) {
      debugPrint('⚠️ Error extracting server from URL: $url, $e');
      return _currentServer;
    }
  }

  /// Check if URL belongs to current server
  bool isCurrentServer(String url) {
    try {
      if (!url.startsWith('http')) {
        return true; // Relative URLs always belong to current server
      }

      final server = extractServerFromUrl(url);
      return server == _currentServer;
    } catch (e) {
      debugPrint('⚠️ Error checking server: $url, $e');
      return false;
    }
  }

  /// Migrate URL to current server
  /// 
  /// This converts URLs from other servers to use the current server
  String migrateUrl(String url) {
    try {
      // Get relative path
      final relativePath = toRelativePath(url);
      
      // Convert back to absolute using current server
      return toAbsoluteUrl(relativePath);
    } catch (e) {
      debugPrint('⚠️ Error migrating URL: $url, $e');
      return url;
    }
  }

  /// Validate a server URL
  Future<bool> validateServer(String server) async {
    if (!availableServers.contains(server)) {
      return false;
    }

    // Add ping check if needed in future
    return true;
  }

  /// Reset to default server
  Future<void> resetToDefault() async {
    await setServer(defaultServer);
  }

  /// Clear server history
  Future<void> clearHistory() async {
    try {
      _serverHistory.clear();
      await _prefsService.setString(_serverHistoryKey, '[]');
      debugPrint('✅ Server history cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing history: $e');
    }
  }
}

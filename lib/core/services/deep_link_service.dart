import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

/// Deep Link Service
/// 
/// Handles custom URL schemes like docln:// and hako://
/// Examples:
/// - docln://              -> Opens app
/// - docln://novel/123     -> Opens novel with ID 123
/// - docln://search?q=text -> Opens search with query
/// - hako://               -> Opens app (alternative scheme)
class DeepLinkService {
  // Singleton pattern
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  Uri? _initialLink;
  bool _initialized = false;

  /// Callback for handling deep links
  Function(Uri)? onLinkReceived;

  /// Initialize the deep link service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _appLinks = AppLinks();

      // Get the initial link if app was opened via URL
      _initialLink = await _appLinks.getInitialLink();
      
      if (_initialLink != null) {
        debugPrint('🔗 App opened with initial link: $_initialLink');
        _handleDeepLink(_initialLink!);
      }

      // Listen for links while app is running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          debugPrint('🔗 Received deep link: $uri');
          _handleDeepLink(uri);
        },
        onError: (err) {
          debugPrint('❌ Error receiving deep link: $err');
        },
      );

      _initialized = true;
      debugPrint('✅ DeepLinkService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize deep links: $e');
    }
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri) {
    try {
      // Log the parsed URL
      debugPrint('📍 Deep link details:');
      debugPrint('   Scheme: ${uri.scheme}');
      debugPrint('   Host: ${uri.host}');
      debugPrint('   Path: ${uri.path}');
      debugPrint('   Query: ${uri.query}');

      // Call the callback if registered
      if (onLinkReceived != null) {
        onLinkReceived!(uri);
      } else {
        debugPrint('⚠️ No deep link handler registered');
      }
    } catch (e) {
      debugPrint('❌ Error handling deep link: $e');
    }
  }

  /// Get the initial link (if app was opened via URL)
  Uri? get initialLink => _initialLink;

  /// Clear the initial link after it's been handled
  void clearInitialLink() {
    _initialLink = null;
  }

  /// Dispose the service
  void dispose() {
    _linkSubscription?.cancel();
    _initialized = false;
  }
}

/// Extension for easy navigation based on deep links
extension DeepLinkNavigation on Uri {
  /// Parse and navigate based on the deep link structure
  /// 
  /// Supported patterns:
  /// - docln://              -> Home
  /// - docln://novel/123     -> Novel details
  /// - docln://search?q=text -> Search
  /// - docln://bookmarks     -> Bookmarks
  /// - docln://history       -> Reading history
  void navigate(BuildContext context) {
    debugPrint('🧭 Navigating based on deep link: $this');

    // Handle empty path (just open app)
    if (path.isEmpty || path == '/') {
      debugPrint('✅ Opening app (no specific route)');
      return;
    }

    // Parse the path segments
    final segments = pathSegments;

    if (segments.isEmpty) {
      debugPrint('✅ Opening app (no specific route)');
      return;
    }

    // Route based on first segment
    switch (segments[0]) {
      case 'novel':
        if (segments.length > 1) {
          final novelId = segments[1];
          debugPrint('📖 Opening novel: $novelId');
          // TODO: Navigate to novel details
          // Navigator.pushNamed(context, '/novel', arguments: novelId);
        }
        break;

      case 'search':
        final query = queryParameters['q'] ?? '';
        debugPrint('🔍 Opening search with query: $query');
        // TODO: Navigate to search
        // Navigator.pushNamed(context, '/search', arguments: query);
        break;

      case 'bookmarks':
        debugPrint('🔖 Opening bookmarks');
        // TODO: Navigate to bookmarks
        // Navigator.pushNamed(context, '/bookmarks');
        break;

      case 'history':
        debugPrint('📚 Opening reading history');
        // TODO: Navigate to history
        // Navigator.pushNamed(context, '/history');
        break;

      default:
        debugPrint('⚠️ Unknown deep link route: ${segments[0]}');
    }
  }
}

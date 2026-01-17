import 'package:docln/core/services/settings_services.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:docln/core/services/adguard_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io' show Platform, File;
import 'package:flutter/services.dart';

import 'package:docln/core/services/history_service_v2.dart';
import 'package:docln/core/services/preferences_recovery_service.dart';
import 'package:docln/core/widgets/custom_toast.dart';
import 'package:docln/core/services/preferences_service.dart';
import 'package:provider/provider.dart';
import 'package:docln/core/models/light_novel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:docln/features/reader/ui/reader_screen.dart';

class WebViewScreen extends StatefulWidget {
  final String url;

  const WebViewScreen({super.key, required this.url});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;

  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isReaderMode = false;
  bool _isDarkMode = false;
  double _textZoom = 100.0;
  bool _isAdBlockEnabled = true;
  bool _preferencesBackedUp = false;

  // List of allowed domains
  final List<String> _allowedDomains = [
    'ln.hako.vn',
    'docln.net',
    'docln.sbs',
    'i.docln.net',
    'i.hako.vn',
  ];

  @override
  void initState() {
    super.initState();
    _backupPreferencesSafely();
    _loadSettings();
    _loadAdBlockRules();
    _initWebView();
  }

  Future<void> _loadSettings() async {
    // Settings loading stub
  }

  Future<void> _loadAdBlockRules() async {
    // AdBlock stub
  }

  @override
  void dispose() {
    _checkForCorruptionOnExit();
    super.dispose();
  }

  Future<void> _backupPreferencesSafely() async {
    try {
      final recoveryService = PreferencesRecoveryService();
      final success = await recoveryService.backupPreferences();

      if (mounted) {
        setState(() {
          _preferencesBackedUp = success;
        });
      }

      if (success) {
        debugPrint('Preferences backed up successfully before WebView session');
      } else {
        debugPrint('Failed to backup preferences before WebView session');
      }
    } catch (e) {
      debugPrint('Error backing up preferences: $e');
    }
  }

  Future<void> _checkForCorruptionOnExit() async {
    if (!_preferencesBackedUp) return;

    try {
      final recoveryService = PreferencesRecoveryService();
      final prefsService = PreferencesService();
      await prefsService.initialize();
      final recoveryNeeded =
          prefsService.getKeys().isNotEmpty && Platform.isIOS;

      if (recoveryNeeded && mounted) {
        debugPrint('Proactively checking preferences after WebView session');

        CustomToast.show(
          context,
          'Verifying preferences integrity after WebView...',
          duration: const Duration(seconds: 3),
        );

        final repaired = await recoveryService.recoverPreferences(context);

        if (repaired && mounted) {
          debugPrint('Successfully verified preferences after WebView');
        } else if (mounted) {
          debugPrint('Failed to verify preferences after WebView');
        }
      }

      // Clean up the AdBlock cache file when we're done with it
      await _cleanupAdBlockCache();
    } catch (e) {
      debugPrint('Error checking for preferences corruption: $e');
    }
  }

  Future<void> _cleanupAdBlockCache() async {
    try {
      // We don't delete the cache file outright, but we can trim it if it's too large
      final directory = await getApplicationDocumentsDirectory();
      final cacheFile = File('${directory.path}/adblock_cache.js');

      if (await cacheFile.exists()) {
        final fileSize = await cacheFile.length();
        debugPrint(
          'AdBlock cache file size: ${(fileSize / 1024).toStringAsFixed(2)} KB',
        );

        // If the cache file is larger than 500KB, trim it to avoid excessive storage usage
        if (fileSize > 500 * 1024) {
          // Instead of deleting, we'll just store the basic version
          await cacheFile.writeAsString(AdBlockService.getFallbackScript());
          debugPrint('Trimmed AdBlock cache file to a smaller version');
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up AdBlock cache: $e');
    }
  }

  Future<void> _toggleAdBlock() async {
    // Ad blocking is now handled purely by URL filtering in NavigationDelegate
    // or by custom headers if supported. No script injection.

    final newState = !_isAdBlockEnabled;

    // Save preference
    final prefsService = PreferencesService();
    await prefsService.initialize();
    await prefsService.setBool('ad_block_enabled', newState);

    if (mounted) {
      setState(() {
        _isAdBlockEnabled = newState;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ad blocker ${newState ? 'enabled' : 'disabled'}'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'RELOAD',
            onPressed: () => _controller?.reload(),
          ),
        ),
      );
    }
  }

  Future<String> _ensureFullUrl(String url) async {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final settingsService = SettingsService();
    final baseUrl = await settingsService.getCurrentServer();
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanPath';
  }

  Future<void> _initWebView() async {
    // Make sure the URL is properly formatted
    final fullUrl = await _ensureFullUrl(widget.url);

    debugPrint('Loading URL: $fullUrl');
    final controller = WebViewController()
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final Uri uri = Uri.parse(request.url);

            // STRICT KIOSK MODE: Only allow specific domains
            bool isAllowed = _allowedDomains.any(
              (domain) => uri.host == domain || uri.host.endsWith('.$domain'),
            );

            // Block all external links (Facebook, Discord, etc.)
            if (!isAllowed) {
              debugPrint('🚫 Blocked navigation to: ${request.url}');
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
            _updateNavigationState();
            // Removed shim injection
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _updateNavigationState();
            // No scripts injected

            // Add to history
            _addToHistory(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              'WebResourceError: ${error.description}, Code: ${error.errorCode}, Type: ${error.errorType}',
            );
            // Ignore common harmless errors
            if (error.description.contains('net::ERR_BLOCKED_BY_CLIENT'))
              return;

            if (mounted) {
              setState(() {
                _isLoading = false;
                // Don't show full error screen for minor resource failures
                if (error.errorCode != -10 && error.errorCode != -11) {
                  // generic errors
                  _hasError = true;
                }
              });
            }
          },
        ),
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        // Aggressively filter console noise
        final msg = message.message;
        if (msg.contains('DOMException') ||
            msg.contains('querySelector') ||
            msg.contains('properties of null') ||
            msg.contains('ERR_'))
          return;

        debugPrint('🌐 Content: $msg');
      });

    controller.loadRequest(Uri.parse(fullUrl));

    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  Future<void> _updateNavigationState() async {
    if (_controller == null) return;

    final canGoBack = await _controller!.canGoBack();
    final canGoForward = await _controller!.canGoForward();

    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    }
  }

  Widget _buildErrorView() {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load page',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _controller?.reload();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    try {
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'action_view',
          data: url,
          package: 'com.android.chrome', // Try Chrome first
        );
        await intent.launch().catchError((e) async {
          // If Chrome fails, try the default browser
          final defaultIntent = AndroidIntent(action: 'action_view', data: url);
          await defaultIntent.launch();
        });
      } else {
        // For iOS and other platforms
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      print('Error opening URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open in browser'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleDarkMode() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dark mode via script injection is disabled.'),
        ),
      );
    }
  }

  void _showTranslateOptions() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation via script injection is disabled.'),
        ),
      );
    }
  }

  void _showMoreOptions() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Add this
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, // Start at 60% of screen height
        minChildSize: 0.3, // Min 30% of screen height
        maxChildSize: 0.9, // Max 90% of screen height
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar and header (fixed)
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'More options',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surfaceVariant
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildOptionTile(
                      icon: Icons.block,
                      title: 'Ad Blocker',
                      subtitle: _isAdBlockEnabled
                          ? 'Blocking ads (enabled)'
                          : 'Not blocking ads (disabled)',
                      onTap: () {
                        Navigator.pop(context);
                        _toggleAdBlock();
                      },
                      isActive: _isAdBlockEnabled,
                    ),
                    _buildOptionTile(
                      icon: Icons.text_fields_rounded,
                      title: 'Text size',
                      subtitle: 'Adjust reading text size',
                      onTap: () {
                        Navigator.pop(context);
                        _showTextSizeDialog();
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.chrome_reader_mode_rounded,
                      title: 'Reader mode',
                      subtitle: 'Clean, simplified view',
                      onTap: () {
                        Navigator.pop(context);
                        _toggleReaderMode();
                      },
                      isActive: _isReaderMode,
                    ),
                    _buildOptionTile(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark mode',
                      subtitle: 'Toggle dark appearance',
                      onTap: () {
                        Navigator.pop(context);
                        _toggleDarkMode();
                      },
                      isActive: _isDarkMode,
                    ),
                    _buildOptionTile(
                      icon: Icons.translate_rounded,
                      title: 'Translate',
                      subtitle: 'Translate page content',
                      onTap: () {
                        Navigator.pop(context);
                        _showTranslateOptions();
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.share_rounded,
                      title: 'Share',
                      subtitle: 'Share this page with others',
                      onTap: () async {
                        final url = await _controller?.currentUrl();
                        if (url != null) {
                          await Share.share(url);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.open_in_browser_rounded,
                      title: 'Open in browser',
                      subtitle: 'View in external browser',
                      onTap: () async {
                        final url = await _controller?.currentUrl();
                        if (url != null) {
                          Navigator.pop(context);
                          _openInBrowser(url);
                        }
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Page info',
                      subtitle: 'View page information',
                      onTap: () {
                        Navigator.pop(context);
                        _showPageInfo();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isActive ? FontWeight.w600 : null,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTextSizeDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.text_fields_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Text Size'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TextSizeOption(
              label: 'Small',
              size: 90,
              currentSize: _textZoom,
              onSelect: _setTextSize,
            ),
            _TextSizeOption(
              label: 'Normal',
              size: 100,
              currentSize: _textZoom,
              onSelect: _setTextSize,
            ),
            _TextSizeOption(
              label: 'Large',
              size: 110,
              currentSize: _textZoom,
              onSelect: _setTextSize,
            ),
            _TextSizeOption(
              label: 'Extra Large',
              size: 120,
              currentSize: _textZoom,
              onSelect: _setTextSize,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setTextSize(double size) async {
    // JS Injection removed.
    // To support this without JS, we would need to reload the page with a different UserAgent or settings,
    // which is overkill. Disabling for now.
    if (mounted) {
      setState(() {
        _textZoom = size;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text Zoom via Script is disabled.')),
      );
    }
  }

  void _showPageInfo() async {
    final url = await _controller?.currentUrl();
    if (!mounted || url == null) return;

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Page Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'URL:',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(url, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text(
              'Domain:',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              Uri.parse(url).host,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URL copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Copy URL'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_canGoBack,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_controller != null && await _controller!.canGoBack()) {
          _controller!.goBack();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: theme.colorScheme.surface,
          leading: IconButton.filledTonal(
            icon: Icon(
              Icons.close_rounded,
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
          titleSpacing: 8,
          title: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _NavButton(
                        icon: Icons.arrow_back_ios_rounded,
                        enabled: _canGoBack,
                        onPressed: () => _controller?.goBack(),
                        tooltip: 'Back',
                      ),
                      _VerticalDivider(theme: theme),
                      _NavButton(
                        icon: Icons.arrow_forward_ios_rounded,
                        enabled: _canGoForward,
                        onPressed: () => _controller?.goForward(),
                        tooltip: 'Forward',
                      ),
                      _VerticalDivider(theme: theme),
                      _NavButton(
                        icon: _isLoading
                            ? Icons.close_rounded
                            : Icons.refresh_rounded,
                        enabled: true,
                        onPressed: () {
                          if (_isLoading) {
                            // Instead of stopLoading, we'll just reload the page
                            _controller?.reload();
                          } else {
                            _controller?.reload();
                          }
                        },
                        tooltip: _isLoading ? 'Stop' : 'Refresh',
                        isLoading: _isLoading,
                      ),
                      _VerticalDivider(theme: theme),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildUrlBar(),
                        ),
                      ),
                      _VerticalDivider(theme: theme),
                      _NavButton(
                        icon: Icons.more_vert_rounded,
                        enabled: true,
                        onPressed: _showMoreOptions,
                        tooltip: 'More options',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: const [],
        ),
        body: Stack(
          children: [
            if (_controller == null)
              _buildLoadingView()
            else if (_hasError)
              _buildErrorView()
            else
              WebViewWidget(controller: _controller!),
            if (_isLoading && !_hasError && _controller != null)
              _buildProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlBar() {
    return FutureBuilder<String?>(
      future: _controller?.currentUrl(),
      builder: (context, snapshot) {
        final url = snapshot.data ?? widget.url;
        return Text(
          Uri.parse(url).host,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
          minHeight: 2,
        ),
      ],
    );
  }

  // Function to add the current novel to history
  void _addToHistory(String url) {
    if (!mounted) return;

    try {
      // Extract novel info from the URL only
      final Uri uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.contains('truyen') || pathSegments.contains('novel')) {
        String novelId = '';
        String novelTitle = 'Unknown Novel';
        String? chapterTitle;

        // Roughly parse structure: /truyen/ID-Slug/cID-Chapter
        // Example: docln.net/truyen/123-ten-truyen/c456-ten-chuong

        // Find 'truyen' index
        int truyenIndex = pathSegments.indexOf('truyen');
        if (truyenIndex == -1) truyenIndex = pathSegments.indexOf('novel');

        if (truyenIndex != -1 && pathSegments.length > truyenIndex + 1) {
          String slug = pathSegments[truyenIndex + 1];
          List<String> parts = slug.split('-');
          if (parts.isNotEmpty) {
            novelId = parts[0];
            // Restore title from slug if possible, poorly
            novelTitle = slug
                .substring(novelId.length)
                .replaceAll('-', ' ')
                .trim();
            novelTitle = novelTitle.isEmpty ? slug : novelTitle;
          } else {
            novelId = slug;
          }
        }

        // Check chapter
        // Usually next segment
        // ... /c123-chapter-title
        if (truyenIndex != -1 && pathSegments.length > truyenIndex + 2) {
          String chSlug = pathSegments[truyenIndex + 2];
          if (chSlug.startsWith('c') || chSlug.startsWith('chapter')) {
            chapterTitle = chSlug.replaceAll('-', ' ');
          }
        }

        final novel = LightNovel(
          id: novelId,
          title: novelTitle,
          coverUrl: 'https://docln.sbs/img/nocover.jpg',
          url: url,
        );

        final historyService = Provider.of<HistoryServiceV2>(
          context,
          listen: false,
        );
        historyService.addToHistory(novel, chapterTitle);
      }
    } catch (e) {
      print('Error adding to history: $e');
    }
  }

  Future<void> _toggleReaderMode() async {
    if (_controller == null) return;

    final currentUrl = await _controller!.currentUrl();
    if (currentUrl == null) return;

    // Use default title since we can't scrape
    final pageTitle = "Light Novel";

    // Create minimal LightNovel for ReaderScreen
    Uri? uri = Uri.tryParse(currentUrl);
    String novelSlug =
        uri?.pathSegments.length != null && uri!.pathSegments.length > 1
        ? uri.pathSegments[1]
        : 'unknown-novel';

    final lightNovel = LightNovel(
      id: novelSlug.split('-').first,
      title: pageTitle,
      coverUrl: 'https://docln.net/img/nocover.png',
      url: currentUrl,
    );

    // ... Navigation logic ...
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(
            url: currentUrl,
            title: 'Reader Mode',
            novel: lightNovel,
            chapterTitle: 'Current Chapter',
          ),
        ),
      );
    }
  }
}

class _VerticalDivider extends StatelessWidget {
  final ThemeData theme;

  const _VerticalDivider({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: theme.colorScheme.outline.withOpacity(0.1),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool isLoading;

  const _NavButton({
    required this.icon,
    required this.enabled,
    this.onPressed,
    required this.tooltip,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: enabled && !isLoading
                  ? theme.colorScheme.surfaceVariant.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : AnimatedScale(
                    scale: enabled ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      icon,
                      size: 20,
                      color: enabled
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurfaceVariant.withOpacity(
                              0.38,
                            ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TextSizeOption extends StatelessWidget {
  final String label;
  final double size;
  final double currentSize;
  final Function(double) onSelect;

  const _TextSizeOption({
    required this.label,
    required this.size,
    required this.currentSize,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = size == currentSize;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(size),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : null,
                      ),
                    ),
                    Text(
                      '${size.toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                AnimatedScale(
                  scale: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

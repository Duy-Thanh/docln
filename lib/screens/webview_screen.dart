import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/adguard_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

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
  String? _adBlockScript;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isReaderMode = false;
  bool _isDarkMode = false;
  double _textZoom = 100.0;

  // List of allowed domains
  final List<String> _allowedDomains = [
    'ln.hako.vn',
    'docln.net',
    'i.docln.net',
    'i.hako.vn',
  ];

  // Navbar removal script
  final String _navbarRemovalScript = """
    function removeNavbar(){
      var e=document.getElementById("navbar");
      e&&e.parentNode.removeChild(e);
      
      // Also remove other potential navigation elements
      ['#header', '.header', '.nav-wrapper', '.navigation'].forEach(selector => {
        const element = document.querySelector(selector);
        if(element) element.remove();
      });
    }
    
    function setupObserver(){
      if(document.body){
        let e=new MutationObserver(e=>{e.forEach(e=>{removeNavbar()})});
        e.observe(document.body,{childList:!0,subtree:!0});
        let r=setInterval(()=>{removeNavbar()},500);
        setTimeout(()=>{clearInterval(r),e.disconnect()},5e3)
      } else setTimeout(setupObserver,1)
    }
    
    removeNavbar();
    setupObserver();
  """;

  @override
  void initState() {
    super.initState();
    _loadAdBlockRules();
  }

  Future<void> _loadAdBlockRules() async {
    try {
      _adBlockScript = await AdBlockService.getAdBlockScript();
    } catch (e) {
      print('Error loading ad block rules: $e');
      _adBlockScript = AdBlockService.getFallbackScript();
    } finally {
      if (mounted) {
        _initWebView();
      }
    }
  }

 void _initWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final Uri uri = Uri.parse(request.url);
            bool isAllowed = _allowedDomains.any((domain) => 
              uri.host.contains(domain)
            );
            return isAllowed 
              ? NavigationDecision.navigate 
              : NavigationDecision.prevent;
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
            _updateNavigationState();
            _injectScripts();
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _updateNavigationState();
            _injectScripts();
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      );

    controller.loadRequest(Uri.parse(widget.url));
    
    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  Future<void> _toggleReaderMode() async {
    const readerModeScript = '''
      (function() {
        const existingStyle = document.getElementById('reader-mode-styles');
        if (existingStyle) {
          existingStyle.remove();
          return false;
        }

        const style = document.createElement('style');
        style.id = 'reader-mode-styles';
        style.innerHTML = `
          body {
            max-width: 800px !important;
            margin: 0 auto !important;
            padding: 20px !important;
            background: #fafafa !important;
            color: #2c3e50 !important;
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif !important;
            line-height: 1.8 !important;
            font-size: 18px !important;
          }
          
          .chapter-content, .content, article, .chapter-c, #chapter-content {
            font-size: 18px !important;
            line-height: 1.8 !important;
            color: #2c3e50 !important;
            padding: 0 16px !important;
          }
          
          p, li {
            font-size: 18px !important;
            line-height: 1.8 !important;
            color: #2c3e50 !important;
            margin: 1em 0 !important;
          }
          
          h1, h2, h3, h4, h5, h6 {
            color: #1a1a1a !important;
            line-height: 1.4 !important;
            margin: 1.5em 0 0.8em !important;
            font-weight: 600 !important;
          }
          
          img {
            max-width: 100% !important;
            height: auto !important;
            margin: 1.5em auto !important;
            display: block !important;
            border-radius: 8px !important;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1) !important;
          }
          
          a {
            color: #3498db !important;
            text-decoration: none !important;
            border-bottom: 1px solid #3498db44 !important;
            transition: all 0.2s ease !important;
          }
          
          a:hover {
            color: #2980b9 !important;
            border-bottom-color: #2980b9 !important;
          }
          
          header, footer, nav, aside, .ads, .banner, .social-share,
          [class*="advertisement"], [class*="sidebar"], [class*="related"],
          [class*="recommended"], [class*="popup"], [class*="modal"] {
            display: none !important;
          }
        `;
        document.head.appendChild(style);
        return true;
      })();
    ''';

    try {
      final result = await _controller?.runJavaScriptReturningResult(readerModeScript);
      setState(() {
        _isReaderMode = result as bool;
      });
    } catch (e) {
      print('Error toggling reader mode: $e');
    }
  }

  Future<void> _enableTextSelection() async {
    const script = '''
      document.documentElement.style.webkitUserSelect = 'text';
      document.documentElement.style.userSelect = 'text';
      
      // Enable long press menu
      document.addEventListener('selectionchange', function() {
        const selection = window.getSelection();
        if (selection.toString().length > 0) {
          window.flutter_inappwebview.callHandler('onTextSelected', selection.toString());
        }
      });
    ''';
    
    await _controller?.runJavaScript(script);
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

  Future<void> _injectScripts() async {
    if (_controller == null) return;
    
    try {
      // Inject ad blocking script
      if (_adBlockScript != null) {
        await _controller!.runJavaScript(_adBlockScript!);
      }
      
      // Inject navbar removal script
      await _controller!.runJavaScript(_navbarRemovalScript);
      
      // Additional cleanup
      await _controller!.runJavaScript('''
        // Remove floating elements and popups
        document.querySelectorAll('[class*="float"], [class*="popup"], [class*="modal"]')
          .forEach(el => el.remove());
          
        // Remove overflow:hidden from body and html
        document.body.style.overflow = 'auto';
        document.documentElement.style.overflow = 'auto';
      ''');
    } catch (e) {
      print('Error injecting scripts: $e');
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
          final defaultIntent = AndroidIntent(
            action: 'action_view',
            data: url,
          );
          await defaultIntent.launch();
        });
      } else {
        // For iOS and other platforms
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
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
    const darkModeScript = '''
      (function() {
        const existingStyle = document.getElementById('dark-mode-styles');
        if (existingStyle) {
          existingStyle.remove();
          return false;
        }

        const style = document.createElement('style');
        style.id = 'dark-mode-styles';
        style.innerHTML = `
          body {
            background: #1a1a1a !important;
            color: #e0e0e0 !important;
          }
          
          .chapter-content, .content, article, .chapter-c, #chapter-content {
            color: #e0e0e0 !important;
            background: #1a1a1a !important;
          }
          
          p, div, span, li {
            color: #e0e0e0 !important;
            background: transparent !important;
          }
          
          h1, h2, h3, h4, h5, h6 {
            color: #ffffff !important;
            font-weight: 600 !important;
          }
          
          a {
            color: #64b5f6 !important;
            text-decoration: none !important;
            border-bottom: 1px solid #64b5f644 !important;
            transition: all 0.2s ease !important;
          }
          
          a:hover {
            color: #90caf9 !important;
            border-bottom-color: #90caf9 !important;
          }
          
          pre, code {
            background: #2d2d2d !important;
            color: #e0e0e0 !important;
            border-radius: 4px !important;
            padding: 0.2em 0.4em !important;
          }
          
          blockquote {
            background: #2d2d2d !important;
            border-left: 4px solid #64b5f6 !important;
            margin: 1em 0 !important;
            padding: 0.5em 1em !important;
            border-radius: 0 4px 4px 0 !important;
          }
          
          hr {
            border: none !important;
            border-top: 1px solid #404040 !important;
            margin: 2em 0 !important;
          }
          
          img {
            opacity: 0.9 !important;
            border-radius: 8px !important;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3) !important;
          }
          
          table {
            border-collapse: collapse !important;
            border: 1px solid #404040 !important;
            background: #2d2d2d !important;
            border-radius: 4px !important;
            overflow: hidden !important;
          }
          
          th, td {
            border: 1px solid #404040 !important;
            padding: 8px 12px !important;
          }
          
          th {
            background: #333333 !important;
            color: #ffffff !important;
          }
        `;
        document.head.appendChild(style);
        return true;
      })();
    ''';

    try {
      final result = await _controller?.runJavaScriptReturningResult(darkModeScript);
      setState(() {
        _isDarkMode = result as bool;
      });
    } catch (e) {
      print('Error toggling dark mode: $e');
    }
  }

  void _showTranslateOptions() {
    // Implement translation options
    // You can use packages like translator or google_translator
  }

  Future<void> _saveForOffline() async {
    // Implement offline saving functionality
    // This would require additional setup for local storage
  }

  void _showMoreOptions() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
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
                        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
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
              const SizedBox(height: 8), // Bottom padding
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
            Icon(Icons.text_fields_rounded, 
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
    try {
      await _controller?.runJavaScript(
        'document.body.style.zoom = "${size}%"'
      );
      setState(() {
        _textZoom = size;
      });
      Navigator.pop(context);
    } catch (e) {
      print('Error setting text size: $e');
    }
  }

  void _showFindInPage() {
    // Add find in page functionality
    // This will require additional JavaScript injection
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
            Icon(Icons.info_outline_rounded, 
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
            Text('URL:', 
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              url,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Domain:', 
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
                        icon: _isLoading ? Icons.close_rounded : Icons.refresh_rounded,
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

  @override
  void dispose() {
    super.dispose();
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
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.38),
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
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
    final readerModeScript = '''
      function enableReaderMode() {
        // Save original styles
        if (!document.querySelector('#reader-mode-styles')) {
          const style = document.createElement('style');
          style.id = 'reader-mode-styles';
          style.textContent = `
            body {
              max-width: 800px !important;
              margin: 0 auto !important;
              padding: 20px !important;
              background: #fff !important;
              color: #333 !important;
              font-family: system-ui, -apple-system, sans-serif !important;
              line-height: 1.8 !important;
              font-size: 18px !important;
            }
            
            p, li {
              font-size: 18px !important;
              line-height: 1.8 !important;
              color: #333 !important;
            }
            
            h1, h2, h3, h4, h5, h6 {
              color: #111 !important;
              line-height: 1.4 !important;
              margin: 1.5em 0 0.8em !important;
            }
            
            img {
              max-width: 100% !important;
              height: auto !important;
              margin: 1em 0 !important;
            }
            
            /* Hide unnecessary elements */
            header, footer, nav, aside, .ads, .banner, .social-share,
            [class*="advertisement"], [class*="sidebar"], [class*="related"],
            [class*="recommended"], [class*="popup"], [class*="modal"] {
              display: none !important;
            }
          `;
          document.head.appendChild(style);
        }
        
        // Toggle styles
        const styleSheet = document.querySelector('#reader-mode-styles');
        styleSheet.disabled = !styleSheet.disabled;
        return !styleSheet.disabled;
      }
      enableReaderMode();
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
      function toggleDarkMode() {
        if (!document.querySelector('#dark-mode-styles')) {
          const style = document.createElement('style');
          style.id = 'dark-mode-styles';
          style.textContent = `
            body {
              background: #1a1a1a !important;
            }
            
            .chapter-content, .content, article, .chapter-c, #chapter-content {
              color: #d4d4d4 !important;
              background: #1a1a1a !important;
            }
            
            p, div, span, li {
              color: #d4d4d4 !important;
              background: transparent !important;
            }
            
            h1, h2, h3, h4, h5, h6 {
              color: #ffffff !important;
            }
          `;
          document.head.appendChild(style);
        }
        
        const styleSheet = document.querySelector('#dark-mode-styles');
        styleSheet.disabled = !styleSheet.disabled;
        return !styleSheet.disabled;
      }
      toggleDarkMode();
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
      backgroundColor: theme.colorScheme.surface,
      builder: (context) => SafeArea(
        child: SingleChildScrollView( // Add this
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'More options',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () async {
                  final url = await _controller?.currentUrl();
                  if (url != null) {
                    await Share.share(url);
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser_rounded),
                title: const Text('Open in browser'),
                onTap: () async {
                  final url = await _controller?.currentUrl();
                  if (url != null) {
                    Navigator.pop(context);
                    if (Platform.isAndroid) {
                      final intent = AndroidIntent(
                        action: 'action_view',
                        data: url,
                        package: 'com.android.chrome',
                      );
                      await intent.launch().catchError((e) async {
                        final defaultIntent = AndroidIntent(
                          action: 'action_view',
                          data: url,
                        );
                        await defaultIntent.launch();
                      });
                    } else {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  _isReaderMode ? Icons.chrome_reader_mode : Icons.chrome_reader_mode_outlined,
                  color: _isReaderMode ? theme.colorScheme.primary : null,
                ),
                title: const Text('Reader mode'),
                subtitle: const Text('Clean layout for better reading'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleReaderMode();
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_fields_rounded),
                title: const Text('Text size'),
                onTap: () {
                  Navigator.pop(context);
                  _showTextSizeDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Page info'),
                onTap: () async {
                  final url = await _controller?.currentUrl();
                  if (!mounted || url == null) return;
                  Navigator.pop(context);
                  _showPageInfo();
                },
              ),
              ListTile(
                leading: Icon(
                  _isDarkMode ? Icons.dark_mode : Icons.dark_mode_outlined,
                  color: _isDarkMode ? theme.colorScheme.primary : null,
                ),
                title: const Text('Dark mode'),
                subtitle: Text(_isDarkMode ? 'On' : 'Off'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleDarkMode();
                },
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
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: isLoading 
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Icon(
                  icon,
                  size: 18,
                  color: enabled 
                    ? theme.colorScheme.onSurfaceVariant 
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.38),
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

    return ListTile(
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
      selected: isSelected,
      onTap: () => onSelect(size),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/adguard_service.dart';

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
            _injectScripts();
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Failed to load page',
            style: TextStyle(color: Colors.red),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasError = false;
                _isLoading = true;
              });
              _controller?.reload();
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(''),
          actions: [
            if (_controller != null)
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () => _controller?.reload(),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (_controller == null)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_hasError)
              _buildErrorView()
            else
              WebViewWidget(controller: _controller!),
            if (_isLoading && !_hasError && _controller != null)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
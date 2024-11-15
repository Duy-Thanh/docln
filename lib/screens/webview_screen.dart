import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;

  WebViewScreen({required this.url});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            print('Navigating to: ${request.url}');
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            // Forcefully remove the navbar
            String removeNavbarScript = """
              function removeNavbar() {
                var navbar = document.getElementById('navbar');
                if (navbar) {
                  console.log("Navbar found, removing...");
                  navbar.parentNode.removeChild(navbar);
                } else {
                  console.log("Navbar not found, checking again...");
                }
              }

              // Attempt to remove the navbar immediately
              removeNavbar();

              // Function to set up the MutationObserver
              function setupObserver() {
                if (document.body) {
                  // Use MutationObserver to watch for future changes
                  const observer = new MutationObserver((mutations) => {
                    mutations.forEach((mutation) => {
                      removeNavbar(); // Check for navbar on each mutation
                    });
                  });

                  observer.observe(document.body, { childList: true, subtree: true });

                  // Set a repeated check every 500ms for 5 seconds
                  let checkInterval = setInterval(() => {
                    removeNavbar();
                  }, 500);

                  // Stop checking after 5 seconds
                  setTimeout(() => {
                    clearInterval(checkInterval);
                    observer.disconnect(); // Stop observing
                  }, 5000);
                } else {
                  // Retry after a short delay if document.body is not available
                  setTimeout(setupObserver, 1);
                }
              }

              // Start the observer setup
              setupObserver();
            """;
            _controller.runJavaScript(removeNavbarScript);
          },
          onPageFinished: (String url) {
            // Optionally, you can also attempt to remove the navbar here
            String removeNavbarScript = """
              removeNavbar(); // Call the function again to ensure removal
            """;
            _controller.runJavaScript(removeNavbarScript);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url)); // Load the initial URL
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Web View'),
      ),
      body: WebViewWidget(controller: _controller), // Use WebViewWidget
    );
  }
}
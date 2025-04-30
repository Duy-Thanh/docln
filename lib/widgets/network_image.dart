import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';

class OptimizedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Widget? placeholder;
  final int? maxHeight;
  final int? maxWidth;
  final Color? color;

  const OptimizedNetworkImage({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
    this.placeholder,
    this.maxHeight,
    this.maxWidth,
    this.color,
  }) : super(key: key);

  @override
  State<OptimizedNetworkImage> createState() => _OptimizedNetworkImageState();
}

class _OptimizedNetworkImageState extends State<OptimizedNetworkImage> {
  String _currentUrl = '';
  bool _isLoading = true;
  bool _hasError = false;
  dynamic _error;
  int _fallbackAttempt = 0;
  List<String> _attemptedUrls = [];
  final Map<String, List<String>> _domainFallbacks = {
    'i.docln.net': ['i.hako.vn', 'i2.docln.net', 'i3.docln.net'],
    'i2.docln.net': ['i.docln.net', 'i.hako.vn', 'i3.docln.net'],
    'i3.docln.net': ['i.docln.net', 'i2.docln.net', 'i.hako.vn'],
    'i.hako.vn': ['i.docln.net', 'i2.docln.net', 'ln.hako.re'],
    'i2.hako.vn': ['i.hako.vn', 'i.docln.net', 'i2.docln.net'],
    'i3.hako.vn': ['i.hako.vn', 'i.docln.net', 'i2.docln.net'],
    'i.hako.vip': ['i.hako.vn', 'i.docln.net', 'i2.docln.net'],
    'i2.hako.vip': ['i.hako.vn', 'i.docln.net', 'i2.docln.net'],
    'i3.hako.vip': ['i.hako.vn', 'i.docln.net', 'i2.docln.net'],
  };

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.imageUrl;
    _attemptedUrls.add(widget.imageUrl);
    _checkUrlReachability();
  }

  @override
  void didUpdateWidget(OptimizedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _fallbackAttempt = 0;
      _currentUrl = widget.imageUrl;
      _attemptedUrls = [widget.imageUrl];
      _checkUrlReachability();
    }
  }

  // Special handler for u6440 image pattern
  String _getU6440Fallback(String url) {
    if (_fallbackAttempt == 0) {
      // Try i2.docln.net first for these images
      return url.replaceFirst('i.hako.vn', 'i2.docln.net');
    } else if (_fallbackAttempt == 1) {
      // Then try i.docln.net directly (skip i3.docln.net which has connectivity issues)
      return url.replaceFirst('i.hako.vn', 'i.docln.net');
    } else if (_fallbackAttempt == 2) {
      // Then try ln.hako.re
      return url.replaceFirst('i.hako.vn', 'ln.hako.re');
    } else {
      // Try a completely different structure
      final filename = url.split('/').last;
      return 'https://ln.hako.re/images/$filename';
    }
  }

  // Find the next fallback domain
  String _getNextFallbackUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      final String host = uri.host;

      // Special case for u6440 pattern
      if (url.contains('u6440-') && url.contains('lightnovel/illusts/')) {
        final fallbackUrl = _getU6440Fallback(url);
        print('Special fallback for u6440: $url -> $fallbackUrl');
        return fallbackUrl;
      }

      // Standard fallback logic
      final fallbacks = _domainFallbacks[host];
      if (fallbacks != null && _fallbackAttempt < fallbacks.length) {
        final newHost = fallbacks[_fallbackAttempt];
        final fallbackUrl = url.replaceFirst(host, newHost);
        print('Standard fallback: $url -> $fallbackUrl');
        return fallbackUrl;
      }
    } catch (e) {
      print('Error getting fallback URL: $e');
    }
    return url; // No more fallbacks, return original
  }

  // Check if URL is reachable and handle redirects - use HEAD request
  Future<void> _checkUrlReachability() async {
    if (_currentUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _error = 'Empty URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Only check if it's an HTTP URL
      if (_currentUrl.startsWith('http')) {
        final request = http.Request('HEAD', Uri.parse(_currentUrl));
        request.followRedirects = true;
        request.headers.addAll({
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/avif,image/webp,image/png,image/*',
          'Referer': 'https://ln.hako.vn/',
        });

        final client = http.Client();
        try {
          final streamedResponse = await client.send(request);

          // Handle successful response (including redirects that were followed)
          if (streamedResponse.statusCode >= 200 &&
              streamedResponse.statusCode < 300) {
            setState(() {
              _isLoading = false;
            });
            return;
          }

          // Handle redirect that needs to be followed manually
          if (streamedResponse.isRedirect ||
              (streamedResponse.statusCode >= 300 &&
                  streamedResponse.statusCode < 400)) {
            final location = streamedResponse.headers['location'];
            if (location != null && location.isNotEmpty) {
              String redirectUrl;
              if (location.startsWith('http')) {
                redirectUrl = location;
              } else {
                // Handle relative URLs
                final baseUri = Uri.parse(_currentUrl);
                redirectUrl =
                    Uri(
                      scheme: baseUri.scheme,
                      host: baseUri.host,
                      path: location.startsWith('/') ? location : '/$location',
                    ).toString();
              }

              print('Following redirect: $_currentUrl -> $redirectUrl');

              // Use the redirect URL
              if (!_attemptedUrls.contains(redirectUrl)) {
                _attemptedUrls.add(redirectUrl);
                setState(() {
                  _currentUrl = redirectUrl;
                  _isLoading = false;
                });
                return;
              }
            }
          }

          // Handle 404 by immediately trying fallback
          if (streamedResponse.statusCode == 404) {
            _tryNextFallback();
            return;
          }

          // For other errors, just show error state
          setState(() {
            _isLoading = false;
            _hasError = true;
            _error = 'HTTP Error: ${streamedResponse.statusCode}';
          });
        } finally {
          client.close();
        }
      } else {
        // Non-HTTP URL, just proceed with loading
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking URL: $e');

      // For connection errors, try fallback
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        _tryNextFallback();
        return;
      }

      setState(() {
        _isLoading = false;
        _hasError = true;
        _error = e.toString();
      });
    }
  }

  // Try the next fallback URL
  void _tryNextFallback() {
    _fallbackAttempt++;
    final nextUrl = _getNextFallbackUrl(_currentUrl);

    // Don't try the same URL twice
    if (_attemptedUrls.contains(nextUrl) || nextUrl == _currentUrl) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _error = 'All fallbacks failed';
      });
      return;
    }

    print('Trying fallback #$_fallbackAttempt: $nextUrl');
    _attemptedUrls.add(nextUrl);

    // Ensure cache is cleared for this URL
    CachedNetworkImage.evictFromCache(nextUrl);

    setState(() {
      _currentUrl = nextUrl;
      _isLoading = true;
      _hasError = false;
    });

    // Check if the new URL is reachable
    _checkUrlReachability();
  }

  // Handle image loading errors - mainly 404s
  void _handleImageError(dynamic error) {
    print('Image error: $error for URL $_currentUrl');

    if (error.toString().contains('404') ||
        error.toString().contains('HttpException: Invalid statusCode: 404') ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup')) {
      _tryNextFallback();
    } else {
      setState(() {
        _hasError = true;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    if (_hasError && _fallbackAttempt > 3) {
      return Container(
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'Failed to load image',
              style: TextStyle(color: Colors.grey),
            ),
            Text(
              _currentUrl.split('/').last,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Use CachedNetworkImage with the current (potentially fallback) URL
    return CachedNetworkImage(
      imageUrl: _currentUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      maxHeightDiskCache: widget.maxHeight,
      maxWidthDiskCache: widget.maxWidth,
      color: widget.color,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),

      // Complete HTTP headers
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'image/avif,image/webp,image/png,image/*',
        'Referer': 'https://ln.hako.vn/',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cache-Control': 'max-age=0',
      },

      // Placeholder
      placeholder:
          (context, url) =>
              widget.placeholder ??
              Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),

      // Handle errors - including 404s
      errorWidget:
          widget.errorWidget ??
          (context, url, error) {
            // If there's a custom error widget, use it
            if (widget.errorWidget != null) {
              return widget.errorWidget!(context, url, error);
            }

            // Otherwise handle the error, especially 404s
            _handleImageError(error);

            // Show loading while trying fallbacks
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
    );
  }
}

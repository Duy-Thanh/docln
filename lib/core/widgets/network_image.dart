import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Widget? placeholder;
  final int? maxHeight;
  final int? maxWidth;
  final int? memCacheHeight;
  final int? memCacheWidth;
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
    this.memCacheHeight,
    this.memCacheWidth,
    this.color,
  }) : super(key: key);

  @override
  State<OptimizedNetworkImage> createState() => _OptimizedNetworkImageState();
}

class _OptimizedNetworkImageState extends State<OptimizedNetworkImage> {
  late String _currentUrl;
  int _fallbackAttempt = 0;
  final List<String> _attemptedUrls = [];
  bool _hasError = false;

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
  }

  @override
  void didUpdateWidget(OptimizedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _fallbackAttempt = 0;
      _currentUrl = widget.imageUrl;
      _attemptedUrls.clear();
      _attemptedUrls.add(widget.imageUrl);
      _hasError = false;
    }
  }

  String _getU6440Fallback(String url) {
    if (_fallbackAttempt == 0) {
      return url.replaceFirst('i.hako.vn', 'i2.docln.net');
    } else if (_fallbackAttempt == 1) {
      return url.replaceFirst('i.hako.vn', 'i.docln.net');
    } else if (_fallbackAttempt == 2) {
      return url.replaceFirst('i.hako.vn', 'ln.hako.re');
    } else {
      final filename = url.split('/').last;
      return 'https://ln.hako.re/images/$filename';
    }
  }

  String? _getNextFallbackUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      final String host = uri.host;

      if (url.contains('u6440-') && url.contains('lightnovel/illusts/')) {
        return _getU6440Fallback(url);
      }

      final fallbacks = _domainFallbacks[host];
      if (fallbacks != null && _fallbackAttempt < fallbacks.length) {
        final newHost = fallbacks[_fallbackAttempt];
        return url.replaceFirst(host, newHost);
      }
    } catch (e) {
      debugPrint('Error getting fallback URL: $e');
    }
    return null;
  }

  void _handleError(dynamic error) {
    if (_hasError) return; // Prevent loop if already failed

    final nextUrl = _getNextFallbackUrl(_currentUrl);

    if (nextUrl != null && !_attemptedUrls.contains(nextUrl)) {
      print('Image load failed for $_currentUrl, trying fallback: $nextUrl');
      _fallbackAttempt++;
      _attemptedUrls.add(nextUrl);

      // Schedule rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentUrl = nextUrl;
            // Clear cache for the failed URL if needed, but CachedNetworkImage handles it mostly
            CachedNetworkImage.evictFromCache(_currentUrl);
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget?.call(context, _currentUrl, 'Failed to load') ??
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          );
    }

    // Pass cache dimensions to CachedNetworkImage for RAM optimization
    // Use widget.maxHeight or a default for memCacheHeight if strictly needed,
    // but typically CachedNetworkImage uses memCacheHeight for RAM.
    // Here we map 'maxHeight' (which was likely intended for disk or memory) to memCacheHeight
    // to ensure RAM savings.

    return CachedNetworkImage(
      imageUrl: _currentUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      // Prioritize explicit memCache params, then fall back to maxHeight/Width mapping
      memCacheHeight:
          widget.memCacheHeight ??
          widget.maxHeight ??
          ((widget.height != null && widget.height!.isFinite)
              ? (widget.height! * 2).toInt()
              : null),
      memCacheWidth: widget.memCacheWidth ?? widget.maxWidth,

      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),

      placeholder: (context, url) =>
          widget.placeholder ??
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),

      errorWidget: (context, url, error) {
        _handleError(error);
        // While trying fallback, show placeholder or keep spinning
        return widget.placeholder ??
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
      },

      httpHeaders: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://ln.hako.vn/',
      },
    );
  }
}

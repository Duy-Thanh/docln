import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:ui' as ui;
import '../../modules/light_novel.dart';

class LightNovelCard extends StatefulWidget {
  final LightNovel novel;
  final VoidCallback onTap;
  final bool showRating;
  final bool showChapterInfo;

  const LightNovelCard({
    Key? key,
    required this.novel,
    required this.onTap,
    this.showRating = false,
    this.showChapterInfo = false,
  }) : super(key: key);

  @override
  State<LightNovelCard> createState() => _LightNovelCardState();
}

class _LightNovelCardState extends State<LightNovelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;
  bool _isLoading = true;
  bool _isHovered = false;
  bool _hasError = false;
  bool _isImagePrecached = false;
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.01,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _imageProvider = NetworkImage(widget.novel.coverUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isImagePrecached && _imageProvider != null) {
      precacheImage(_imageProvider!, context)
          .then((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isImagePrecached = true;
              });
            }
          })
          .catchError((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _isImagePrecached = true;
              });
            }
          });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => mounted ? setState(() => _isHovered = true) : null,
      onExit: (_) => mounted ? setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _controller,
            _scaleAnimation,
            _rotationAnimation,
          ]),
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.identity()
                    ..scale(_scaleAnimation.value)
                    ..rotateZ(_rotationAnimation.value),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black : Colors.black54)
                          .withOpacity(_isHovered ? 0.3 : 0.1),
                      blurRadius: _isHovered ? 16 : 8,
                      offset: Offset(0, _isHovered ? 8 : 4),
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Theme.of(context).cardColor,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 55,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildCoverImage(isDark),
                              _buildGradientOverlay(),
                              if (widget.showRating &&
                                  widget.novel.rating != null)
                                _buildRatingBadge(
                                  colorScheme,
                                  textTheme,
                                  isDark,
                                ),
                              if (widget.novel.latestChapter != null)
                                _buildStatusIndicator(
                                  colorScheme,
                                  textTheme,
                                  isDark,
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 45,
                          child: _buildInfoContainer(
                            colorScheme,
                            textTheme,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCoverImage(bool isDark) {
    if (_isLoading) {
      return _buildShimmer(isDark);
    }

    if (_hasError) {
      return _buildErrorWidget(isDark);
    }

    return Image(
      image: _imageProvider!,
      fit: BoxFit.cover,
      frameBuilder: (_, child, frame, __) {
        if (frame == null) return _buildShimmer(isDark);
        return child;
      },
      errorBuilder: (_, __, ___) => _buildErrorWidget(isDark),
    );
  }

  Widget _buildShimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[850] : Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 32,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 4),
          Text(
            'Failed to load image',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.0, 0.6, 0.75, 0.85, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingBadge(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black87 : Colors.white).withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 14, color: Colors.amber[600]),
            const SizedBox(width: 4),
            Text(
              widget.novel.rating!.toStringAsFixed(1),
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.new_releases, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Mới',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoContainer(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey[900] : Colors.white)!.withOpacity(0.9),
            border: Border(
              top: BorderSide(color: colorScheme.primary.withOpacity(0.1)),
            ),
          ),
          child: _buildInfoContent(colorScheme, textTheme),
        ),
      ),
    );
  }

  Widget _buildInfoContent(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.novel.title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            height: 1.2,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        if (widget.showChapterInfo && widget.novel.latestChapter != null)
          Row(
            children: [
              Icon(
                Icons.bookmark_outline,
                size: 12,
                color: colorScheme.primary.withOpacity(0.8),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.novel.latestChapter!,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

        if (widget.novel.volumeTitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 12,
                  color: colorScheme.primary.withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.novel.volumeTitle!,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        const Spacer(),

        if (widget.novel.chapters != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.novel.chapters} chương',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

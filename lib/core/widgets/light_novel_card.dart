import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:docln/core/models/light_novel.dart';

class LightNovelCard extends StatelessWidget {
  final LightNovel novel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showRating;
  final bool showChapterInfo;

  const LightNovelCard({
    Key? key,
    required this.novel,
    required this.onTap,
    this.onLongPress,
    this.showRating = false,
    this.showChapterInfo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image with Caching and Resizing
            Hero(
              tag: 'novel_cover_${novel.id}',
              child: CachedNetworkImage(
                imageUrl: novel.coverUrl,
                fit: BoxFit.cover,
                // CRITICAL: Resize image in memory to save RAM
                memCacheHeight: 450,
                filterQuality: FilterQuality.medium,
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
              ),
            ),

            // Gradient Overlay for Text Legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Rating Badge (Top Right)
            if (showRating && novel.rating != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        novel.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Novel Info (Bottom)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    novel.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),

                  if (showChapterInfo && novel.latestChapter != null) ...[
                    const SizedBox(height: 4),
                    // Latest Chapter
                    Row(
                      children: [
                        Icon(
                          Icons.history_edu_rounded,
                          size: 10,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            novel.latestChapter!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Stats row (optional, simplified)
                  if (!showChapterInfo &&
                      novel.chapters != null &&
                      novel.chapters! > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${novel.chapters} chương',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../modules/chapter.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/network_image.dart';

class ChapterCard extends StatefulWidget {
  final Chapter chapter;
  final VoidCallback? onTap;

  const ChapterCard({Key? key, required this.chapter, this.onTap})
    : super(key: key);

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Validate if chapter has required data
    if (widget.chapter.title.isEmpty || widget.chapter.seriesTitle.isEmpty) {
      return const SizedBox.shrink(); // Don't show empty cards
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.chapter.url.isNotEmpty
            ? widget.onTap
            : null, // Disable tap if no URL
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              // Cover image
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image with fallback
                    OptimizedNetworkImage(
                      imageUrl: widget.chapter.coverUrl.isNotEmpty
                          ? widget.chapter.coverUrl
                          : 'https://docln.sbs/img/nocover.jpg', // Fallback image
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                    // Volume badge (if exists and not empty)
                    if (widget.chapter.volumeTitle?.isNotEmpty == true)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: Text(
                            widget.chapter.volumeTitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Info section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chapter title
                      Text(
                        widget.chapter.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Series title with icon
                      Row(
                        children: [
                          Icon(
                            Icons.book,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.chapter.seriesTitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (widget.chapter.volumeTitle != null) ...[
                        const SizedBox(height: 2),
                        // Volume info with icon
                        Row(
                          children: [
                            Icon(
                              Icons.bookmark,
                              size: 12,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.chapter.volumeTitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../modules/light_novel.dart';

class LightNovelCard extends StatelessWidget {
  final LightNovel novel;
  final VoidCallback onTap;

  const LightNovelCard({
    Key? key,
    required this.novel,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      clipBehavior: Clip.hardEdge, // Add this
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Image.network(
                  novel.coverUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isDarkMode ? Colors.grey[850] : Colors.grey[400],
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: isDarkMode ? Colors.grey[850] : Colors.grey[400],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                color: isDarkMode ? Colors.grey[900] : Colors.transparent,
                child: Text(
                  novel.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

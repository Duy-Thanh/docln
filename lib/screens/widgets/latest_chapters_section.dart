import 'package:flutter/material.dart';
import '../../modules/chapter.dart';
import 'package:shimmer/shimmer.dart';
import '../../screens/webview_screen.dart';
import '../../screens/reader_screen.dart';
import '../widgets/chapter_card.dart';

class LatestChaptersSection extends StatelessWidget {
  final List<Chapter> chapters;
  final bool isLoading;
  final VoidCallback? onSeeMoreTapped;

  const LatestChaptersSection({
    Key? key,
    required this.chapters,
    this.isLoading = false,
    this.onSeeMoreTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Latest Chapters',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSeeMoreTapped,
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: isLoading ? 6 : chapters.length,
            itemBuilder: (context, index) {
              if (isLoading) {
                return _buildShimmerItem();
              }
              return _buildChapterItem(chapters[index], context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChapterItem(Chapter chapter, BuildContext context) {
    return ChapterCard(
      chapter: chapter,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ReaderScreen(
                  url: chapter.url,
                  title: chapter.seriesTitle,
                  chapterTitle: chapter.title,
                  // novel is optional and we might not have the complete novel object from just a chapter
                ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerItem() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/light_novel.dart';
import '../blocs/chapter/chapter_bloc.dart';
import '../blocs/light_novel/light_novel_bloc.dart';
import '../blocs/light_novel/light_novel_event.dart';
import '../blocs/light_novel/light_novel_state.dart';
import '../widgets/chapter_list.dart';
import '../../core/di/injection.dart';

class NovelDetailPage extends StatelessWidget {
  final String novelId;

  const NovelDetailPage({
    super.key,
    required this.novelId,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChapterBloc>(
          create: (context) => getIt<ChapterBloc>(),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Novel Details'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: () {
                // TODO: Implement bookmark functionality
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                // TODO: Implement share functionality
              },
            ),
          ],
        ),
        body: BlocBuilder<LightNovelBloc, LightNovelState>(
          builder: (context, state) {
            if (state is LightNovelDetailLoaded) {
              return _buildNovelDetail(context, state.novel);
            } else if (state is LightNovelLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is LightNovelError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${state.message}'),
                    ElevatedButton(
                      onPressed: () {
                        context.read<LightNovelBloc>().add(LoadLightNovel(novelId));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            } else {
              // Load novel detail if not loaded
              context.read<LightNovelBloc>().add(LoadLightNovel(novelId));
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Widget _buildNovelDetail(BuildContext context, LightNovelEntity novel) {
    return CustomScrollView(
      slivers: [
        // Novel Header
        SliverToBoxAdapter(
          child: _buildNovelHeader(context, novel),
        ),

        // Chapters Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Chapters',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),

        // Chapter List
        SliverFillRemaining(
          child: ChapterList(
            novelId: novel.id,
            onChapterTap: (chapter) {
              // TODO: Navigate to chapter reader
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Selected: ${chapter.title}')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNovelHeader(BuildContext context, LightNovelEntity novel) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image
          Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(novel.coverUrl),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  // Handle image loading error
                },
              ),
            ),
            child: novel.coverUrl.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.book,
                      size: 60,
                      color: Colors.grey,
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 16),

          // Novel Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  novel.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 8),

                // Author (if available)
                // TODO: Add author field to entity

                // Stats Row
                Row(
                  children: [
                    if (novel.rating != null) ...[
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        novel.rating!.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                    ],

                    if (novel.chapters != null) ...[
                      const Icon(Icons.book, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${novel.chapters} chapters',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Latest Chapter
                if (novel.latestChapter != null)
                  Text(
                    'Latest: ${novel.latestChapter}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Start reading from first chapter
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Reading'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        // TODO: Toggle bookmark
                      },
                      icon: const Icon(Icons.bookmark_border),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chapter.dart';
import '../blocs/chapter/chapter_bloc.dart';
import '../blocs/chapter/chapter_event.dart';
import '../blocs/chapter/chapter_state.dart';

class ChapterList extends StatelessWidget {
  final String novelId;
  final Function(ChapterEntity)? onChapterTap;

  const ChapterList({
    super.key,
    required this.novelId,
    this.onChapterTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChapterBloc, ChapterState>(
      builder: (context, state) {
        if (state is ChapterInitial) {
          // Load chapters when widget is first built
          context.read<ChapterBloc>().add(LoadChapters(novelId));
          return const Center(child: CircularProgressIndicator());
        } else if (state is ChapterLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ChaptersLoaded) {
          return _buildChapterList(context, state.chapters);
        } else if (state is ChapterError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${state.message}'),
                ElevatedButton(
                  onPressed: () {
                    context.read<ChapterBloc>().add(LoadChapters(novelId));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return const Center(child: Text('Unknown state'));
      },
    );
  }

  Widget _buildChapterList(BuildContext context, List<ChapterEntity> chapters) {
    if (chapters.isEmpty) {
      return const Center(
        child: Text('No chapters available'),
      );
    }

    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return ChapterListItem(
          chapter: chapter,
          onTap: () => onChapterTap?.call(chapter),
        );
      },
    );
  }
}

class ChapterListItem extends StatelessWidget {
  final ChapterEntity chapter;
  final VoidCallback? onTap;

  const ChapterListItem({
    super.key,
    required this.chapter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        chapter.title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: chapter.chapterNumber != null
          ? Text('Chapter ${chapter.chapterNumber}')
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

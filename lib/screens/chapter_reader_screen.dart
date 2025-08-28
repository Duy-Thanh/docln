import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../presentation/blocs/chapter/chapter_bloc.dart';
import '../presentation/blocs/chapter/chapter_event.dart';
import '../presentation/blocs/chapter/chapter_state.dart';
import '../widgets/chapter_content_view.dart';
import '../widgets/loading_indicator.dart';

class ChapterReaderScreen extends StatelessWidget {
  final String chapterId;
  final String novelTitle;
  final String chapterTitle;

  const ChapterReaderScreen({
    Key? key,
    required this.chapterId,
    required this.novelTitle,
    required this.chapterTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ChapterBloc>()
        ..add(LoadChapterContent(chapterId)),
      child: ChapterReaderView(
        chapterId: chapterId,
        novelTitle: novelTitle,
        chapterTitle: chapterTitle,
      ),
    );
  }
}

class ChapterReaderView extends StatefulWidget {
  final String chapterId;
  final String novelTitle;
  final String chapterTitle;

  const ChapterReaderView({
    Key? key,
    required this.chapterId,
    required this.novelTitle,
    required this.chapterTitle,
  }) : super(key: key);

  @override
  State<ChapterReaderView> createState() => _ChapterReaderViewState();
}

class _ChapterReaderViewState extends State<ChapterReaderView> {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        _scrollProgress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.novelTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            Text(
              widget.chapterTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          // Reading progress indicator
          Container(
            width: 60,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: _scrollProgress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showReaderSettings(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      body: BlocBuilder<ChapterBloc, ChapterState>(
        builder: (context, state) {
          if (state is ChapterLoading) {
            return const LoadingIndicator();
          }

          if (state is ChapterError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load chapter',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ChapterBloc>().add(LoadChapterContent(widget.chapterId));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ChapterContentLoaded) {
            return ChapterContentView(
              content: state.content,
              scrollController: _scrollController,
            );
          }

          if (state is ChapterNavigationSuccess) {
            // Navigate to the new chapter
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => ChapterReaderScreen(
                    chapterId: state.chapter.id,
                    novelTitle: widget.novelTitle,
                    chapterTitle: state.chapter.title,
                  ),
                ),
              );
            });
            return const LoadingIndicator();
          }

          if (state is NoNextChapter) {
            // Show a snackbar indicating no next chapter
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No next chapter available')),
              );
            });
            return ChapterContentView(
              content: (state as ChapterContentLoaded).content,
              scrollController: _scrollController,
            );
          }

          if (state is NoPreviousChapter) {
            // Show a snackbar indicating no previous chapter
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No previous chapter available')),
              );
            });
            return ChapterContentView(
              content: (state as ChapterContentLoaded).content,
              scrollController: _scrollController,
            );
          }

          return const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: () => _navigateToPreviousChapter(context),
            tooltip: 'Previous Chapter',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => _toggleBookmark(context),
            tooltip: 'Bookmark',
          ),
          IconButton(
            icon: const Icon(Icons.comment),
            onPressed: () => _showComments(context),
            tooltip: 'Comments',
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: () => _navigateToNextChapter(context),
            tooltip: 'Next Chapter',
          ),
        ],
      ),
    );
  }

  void _showReaderSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const ReaderSettingsSheet(),
    );
  }

  void _navigateToPreviousChapter(BuildContext context) {
    // TODO: Get novelId from the chapter or pass it as parameter
    // For now, we'll show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Previous chapter navigation coming soon')),
    );
  }

  void _navigateToNextChapter(BuildContext context) {
    // TODO: Get novelId from the chapter or pass it as parameter
    // For now, we'll show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Next chapter navigation coming soon')),
    );
  }

  void _toggleBookmark(BuildContext context) {
    // TODO: Implement bookmark functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark functionality not implemented yet')),
    );
  }

  void _showComments(BuildContext context) {
    // TODO: Implement comments functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comments functionality not implemented yet')),
    );
  }
}

class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({Key? key}) : super(key: key);

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  double _fontSize = 16.0;
  double _lineHeight = 1.5;
  bool _nightMode = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reader Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),

          // Font Size
          Text(
            'Font Size: ${_fontSize.toInt()}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _fontSize,
            min: 12,
            max: 24,
            divisions: 12,
            onChanged: (value) => setState(() => _fontSize = value),
          ),

          const SizedBox(height: 16),

          // Line Height
          Text(
            'Line Height: ${_lineHeight.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _lineHeight,
            min: 1.0,
            max: 2.0,
            divisions: 10,
            onChanged: (value) => setState(() => _lineHeight = value),
          ),

          const SizedBox(height: 16),

          // Night Mode
          SwitchListTile(
            title: const Text('Night Mode'),
            value: _nightMode,
            onChanged: (value) => setState(() => _nightMode = value),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

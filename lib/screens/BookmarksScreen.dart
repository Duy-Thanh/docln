import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bookmark_service.dart';
import '../modules/light_novel.dart';
import './widgets/light_novel_card.dart';
import './LightNovelDetailsScreen.dart';
import './custom_toast.dart';
import '../screens/HomeScreen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  _BookmarksScreenState createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure bookmarks are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookmarkService>(context, listen: false).loadBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bookmarks',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
              CustomToast.show(context, 'Search functionality coming soon');
            },
          ),
        ],
      ),
      body: Consumer<BookmarkService>(
        builder: (context, bookmarkService, child) {
          final bookmarks = bookmarkService.bookmarkedNovels;

          if (bookmarks.isEmpty) {
            return _buildEmptyState(colorScheme);
          }

          return _buildBookmarksList(bookmarks);
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No bookmarks yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Bookmark your favorite novels to access them quickly here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Use our NavigationService to navigate to the Library tab (index 0)
              NavigationService().navigateToTab(0);
            },
            icon: const Icon(Icons.explore),
            label: const Text('Discover Novels'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList(List<LightNovel> bookmarks) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: bookmarks.length,
        itemBuilder: (context, index) {
          final novel = bookmarks[index];
          return LightNovelCard(
            novel: novel,
            onTap: () => _openNovelDetails(novel),
            onLongPress: () => _showBookmarkOptions(novel),
          );
        },
      ),
    );
  }

  void _openNovelDetails(LightNovel novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                LightNovelDetailsScreen(novel: novel, novelUrl: novel.url),
      ),
    );
  }

  void _showBookmarkOptions(LightNovel novel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle at the top of bottom sheet
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Read novel'),
                onTap: () {
                  Navigator.pop(context);
                  _openNovelDetails(novel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_remove),
                title: const Text('Remove from bookmarks'),
                onTap: () {
                  Navigator.pop(context);
                  _removeBookmark(novel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement share functionality
                  CustomToast.show(context, 'Share functionality coming soon');
                },
              ),
            ],
          ),
    );
  }

  void _removeBookmark(LightNovel novel) {
    final bookmarkService = Provider.of<BookmarkService>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Bookmark'),
            content: Text('Remove "${novel.title}" from your bookmarks?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  bookmarkService.removeBookmark(novel.id).then((_) {
                    CustomToast.show(
                      context,
                      '${novel.title} removed from bookmarks',
                    );
                  });
                },
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }
}

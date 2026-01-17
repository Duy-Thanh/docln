import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:docln/core/services/bookmark_service_v2.dart';
import 'package:docln/core/models/light_novel.dart';
import 'package:docln/core/widgets/light_novel_card.dart';
import 'package:docln/features/reader/ui/LightNovelDetailsScreen.dart';
import 'package:docln/core/widgets/custom_toast.dart';
import 'package:docln/features/home/ui/HomeScreen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  _BookmarksScreenState createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _animationHeight;

  // For category filtering
  String? _selectedCategory;
  final List<String> _allCategories = [
    'All',
    'Fantasy',
    'Action',
    'Romance',
    'Adventure',
    'School Life',
    'Drama',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize animation controller first
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animationHeight = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Ensure bookmarks are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Load bookmarks from database
        Provider.of<BookmarkServiceV2>(context, listen: false).loadBookmarks();
      }
    });

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Filter bookmarks based on search query and category
  List<LightNovel> _filterBookmarks(List<LightNovel> bookmarks) {
    List<LightNovel> filteredList = bookmarks;

    // Apply text search filter
    if (_searchQuery.isNotEmpty) {
      filteredList = filteredList.where((novel) {
        final title = novel.title.toLowerCase();
        final author = novel.alternativeTitles?.join(' ').toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return title.contains(query) || author.contains(query);
      }).toList();
    }

    // Apply category filter if selected
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filteredList = filteredList.where((novel) {
        // LightNovel doesn't have genres property, so we'll check title and alt titles
        // for potential category matches as a simple fallback
        final title = novel.title.toLowerCase();
        final altTitles =
            novel.alternativeTitles?.join(' ').toLowerCase() ?? '';
        final category = _selectedCategory!.toLowerCase();

        return title.contains(category) || altTitles.contains(category);
      }).toList();
    }

    return filteredList;
  }

  void _toggleSearch() {
    if (!mounted) return;

    // Additional safety check - if controller is not initialized, do nothing
    if (!_animationController.isAnimating && mounted) {
      setState(() {
        _isSearching = !_isSearching;
        if (_isSearching) {
          _animationController.forward();
        } else {
          _animationController.reverse();
          _searchController.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if controller is initialized before building UI
    if (!mounted) return Container();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? _buildSearchField()
            : Text(
                'Bookmarks',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
        centerTitle: !_isSearching,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _toggleSearch,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search bookmarks',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by category',
            onPressed: _showCategoryFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          if (_selectedCategory != null)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return SizeTransition(
                  sizeFactor: _animationHeight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                    child: Row(
                      children: [
                        Text('Filter: ', style: theme.textTheme.bodySmall),
                        Chip(
                          label: Text(_selectedCategory ?? 'All'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                          backgroundColor: colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Main content
          Expanded(
            child: Consumer<BookmarkServiceV2>(
              builder: (context, bookmarkService, child) {
                final allBookmarks = bookmarkService.bookmarkedNovels;
                final filteredBookmarks = _filterBookmarks(allBookmarks);

                if (allBookmarks.isEmpty) {
                  return _buildEmptyState(colorScheme);
                }

                if (filteredBookmarks.isEmpty &&
                    (_searchQuery.isNotEmpty || _selectedCategory != null)) {
                  return _buildNoSearchResultsState(colorScheme);
                }

                return _buildBookmarksList(filteredBookmarks);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter by Category'),
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _allCategories.length,
              itemBuilder: (context, index) {
                final category = _allCategories[index];
                return RadioListTile<String>(
                  title: Text(category),
                  value: category,
                  groupValue: _selectedCategory ?? 'All',
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value == 'All' ? null : value;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Clear Filter'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search bookmarks...',
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black45,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchController.clear();
          },
        ),
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
        fontSize: 16,
      ),
      onSubmitted: (value) {
        // Optionally handle submission if needed
      },
    );
  }

  // Modify _buildBookmarksList to highlight search matches
  Widget _buildBookmarksList(List<LightNovel> bookmarks) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          key: ValueKey<int>(bookmarks.length), // Add key for animation
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final novel = bookmarks[index];
            // Apply search animation for items matching the search
            final bool isMatched =
                _searchQuery.isNotEmpty &&
                novel.title.toLowerCase().contains(_searchQuery.toLowerCase());

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              transform: isMatched
                  ? (Matrix4.identity()..scale(1.05))
                  : Matrix4.identity(),
              child: LightNovelCard(
                novel: novel,
                onTap: () => _openNovelDetails(novel),
                onLongPress: () => _showBookmarkOptions(novel),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openNovelDetails(LightNovel novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
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
      builder: (context) => Column(
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
    final bookmarkService = Provider.of<BookmarkServiceV2>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  Widget _buildNoSearchResultsState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No matching novels found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Try using different keywords or check your spelling',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear Search'),
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
}

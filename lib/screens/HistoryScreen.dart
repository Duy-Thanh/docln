import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../modules/light_novel.dart';
import './widgets/light_novel_card.dart';
import './LightNovelDetailsScreen.dart';
import './custom_toast.dart';
import '../screens/HomeScreen.dart';

// Create a History service
class HistoryService extends ChangeNotifier {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  List<HistoryItem> _historyItems = [];
  List<HistoryItem> get historyItems => _historyItems;

  static const String _historyKey = 'reading_history';

  // Add a history item
  void addToHistory(LightNovel novel, String? chapterTitle) {
    // Check if already exists
    final existingIndex = _historyItems.indexWhere(
      (item) => item.novel.id == novel.id,
    );

    final newItem = HistoryItem(
      novel: novel,
      lastReadChapter: chapterTitle ?? 'Unknown Chapter',
      timestamp: DateTime.now(),
    );

    if (existingIndex != -1) {
      // Update existing entry
      _historyItems[existingIndex] = newItem;
    } else {
      // Add new entry
      _historyItems.add(newItem);
    }

    // Limit history to 100 items
    if (_historyItems.length > 100) {
      _historyItems.removeLast();
    }

    notifyListeners();
    _saveHistory();
  }

  // Remove from history
  void removeFromHistory(String novelId) {
    _historyItems.removeWhere((item) => item.novel.id == novelId);
    notifyListeners();
    _saveHistory();
  }

  // Clear history
  void clearHistory() {
    _historyItems.clear();
    notifyListeners();
    _saveHistory();
  }

  // Load history from storage
  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_historyKey);

      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _historyItems =
            historyList.map((json) => HistoryItem.fromJson(json)).toList();

        // Sort by most recent first
        _historyItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      notifyListeners();
    } catch (e) {
      print('Error loading history: $e');
      _historyItems = [];
      notifyListeners();
    }
  }

  // Save history to storage
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String historyJson = jsonEncode(
        _historyItems.map((item) => item.toJson()).toList(),
      );

      await prefs.setString(_historyKey, historyJson);
    } catch (e) {
      print('Error saving history: $e');
    }
  }
}

// History item model
class HistoryItem {
  final LightNovel novel;
  final String lastReadChapter;
  final DateTime timestamp;

  HistoryItem({
    required this.novel,
    required this.lastReadChapter,
    required this.timestamp,
  });

  // Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'novel': novel.toJson(),
      'lastReadChapter': lastReadChapter,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Deserialize from JSON
  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      novel: LightNovel.fromJson(json['novel']),
      lastReadChapter: json['lastReadChapter'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AnimationController? _animationController;
  Animation<double>? _animationHeight;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller safely
    try {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );

      _animationHeight = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
      );
    } catch (e) {
      print('Error initializing animation: $e');
    }

    // Setup search controller
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
    _animationController?.dispose();
    super.dispose();
  }

  // Filter history based on search query
  List<HistoryItem> _filterHistory(List<HistoryItem> historyItems) {
    if (_searchQuery.isEmpty) return historyItems;

    return historyItems.where((item) {
      final title = item.novel.title.toLowerCase();
      final chapter = item.lastReadChapter.toLowerCase();
      final query = _searchQuery.toLowerCase();

      return title.contains(query) || chapter.contains(query);
    }).toList();
  }

  void _toggleSearch() {
    if (!mounted) return;

    // Make sure animation controller is initialized
    if (_animationController != null && mounted) {
      setState(() {
        _isSearching = !_isSearching;
        if (_isSearching) {
          _animationController!.forward();
        } else {
          _animationController!.reverse();
          _searchController.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't build if animation controller isn't ready
    if (_animationController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title:
            _isSearching
                ? _buildSearchField()
                : Text(
                  'Reading History',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
        centerTitle: !_isSearching,
        leading:
            _isSearching
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _toggleSearch,
                )
                : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search history',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear history',
            onPressed: () => _showClearHistoryDialog(),
          ),
        ],
      ),
      body: Consumer<HistoryService>(
        builder: (context, historyService, _) {
          final historyItems = historyService.historyItems;
          final filteredItems = _filterHistory(historyItems);

          if (historyItems.isEmpty) {
            return _buildEmptyState(colorScheme);
          }

          if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
            return _buildNoSearchResultsState(colorScheme);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return _buildHistoryItem(item, colorScheme);
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search history...',
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

  Widget _buildHistoryItem(HistoryItem item, ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final timeAgo = _getTimeAgo(item.timestamp);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openNovelDetails(item.novel),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Novel cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.novel.coverUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 80,
                        height: 120,
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 16),
              // Novel info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.novel.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last read: ${item.lastReadChapter}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.book, size: 16),
                          label: const Text('Continue Reading'),
                          onPressed: () => _openNovelDetails(item.novel),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _removeHistoryItem(item),
                          tooltip: 'Remove from history',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  void _removeHistoryItem(HistoryItem item) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove from History'),
            content: Text(
              'Remove "${item.novel.title}" from your reading history?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Get the history service from provider
                  Provider.of<HistoryService>(
                    context,
                    listen: false,
                  ).removeFromHistory(item.novel.id);
                  CustomToast.show(context, 'Removed from history');
                },
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear History'),
            content: const Text(
              'Are you sure you want to clear your entire reading history? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Provider.of<HistoryService>(
                    context,
                    listen: false,
                  ).clearHistory();
                  CustomToast.show(context, 'History cleared');
                },
                child: const Text('Clear'),
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
            Icons.history,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No reading history',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Novels you read will appear here for easy access',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to Library tab
              NavigationService().navigateToTab(1); // Navigate to Search tab
            },
            icon: const Icon(Icons.search),
            label: const Text('Find Novels'),
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
            'No matching history found',
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

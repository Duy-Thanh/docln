import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import 'package:docln/core/services/api_service.dart'; // Dùng cái này
import 'package:docln/core/models/search_result.dart';
import 'package:provider/provider.dart';
import 'package:docln/core/services/theme_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:docln/core/widgets/webview_screen.dart';
import 'dart:math' as math;
import 'package:docln/features/reader/ui/LightNovelDetailsScreen.dart';
import 'package:docln/core/models/light_novel.dart';
import 'package:docln/core/widgets/light_novel_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // DÙNG API SERVICE MỚI
  final ApiService _apiService = ApiService();

  // Initialize controllers explicitly, not using late
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;

  bool _isLoading = false;
  String _errorMessage = '';
  SearchResponse? _searchResponse;
  int _currentPage = 1;
  bool _isDisposed = false; // Track if widget is disposed

  // Popular searches for suggestions
  final List<String> _popularSearches = [
    'Overlord',
    'Re:Zero',
    'Mushoku Tensei',
    'Sword Art Online',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animations safely
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );

    // Start the animation when screen loads - with safety check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _animationController != null) {
        _animationController!.forward();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _animationController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch({int page = 1}) async {
    if (!mounted) return;

    final String searchTerm = page == 1
        ? _searchController.text.trim()
        : (_searchResponse?.keyword ?? _searchController.text.trim());

    if (searchTerm.isEmpty) return;

    if (page == 1 && _searchResponse?.keyword != searchTerm) {
      _searchController.text = searchTerm;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        if (page == 1) {
          _searchResponse = null;
        }
        _currentPage = page;
      });
    }

    try {
      HapticFeedback.mediumImpact();

      // GỌI API SEARCH MỚI
      final response = await _apiService.search(searchTerm, page: page);

      if (mounted && _animationController != null) {
        _animationController!.reset();
        setState(() {
          _searchResponse = response;
          _isLoading = false;
        });
        _animationController!.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Search error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _launchUrl(String url, SearchResult result) async {
    if (!mounted) return;

    if (await canLaunchUrl(Uri.parse(url))) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LightNovelDetailsScreen(
            novel: LightNovel(
              id: url.split('/').last,
              title: result.seriesTitle,
              coverUrl: result.coverUrl,
              url: url,
            ),
            novelUrl: url,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safety check for animation controller
    if (_animationController == null ||
        _fadeAnimation == null ||
        _scaleAnimation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeService = Provider.of<ThemeServices>(context);
    final isDarkMode = themeService.themeMode == ThemeMode.dark;
    final primaryColor = isDarkMode
        ? Colors.deepOrangeAccent
        : Colors.deepOrange;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: AnimatedBuilder(
                animation: _animationController!,
                builder: (context, child) {
                  final scale = _scaleAnimation!.value.clamp(0.5, 1.0);
                  final opacity = _fadeAnimation!.value.clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: _buildM3SearchBar(isDarkMode, primaryColor),
              ),
            ),

            // Suggestions
            if (_searchController.text.isEmpty && _searchResponse == null)
              _buildSafeAnimatedSuggestions(isDarkMode, primaryColor),

            // Search results
            Expanded(
              child: AnimatedBuilder(
                animation: _animationController!,
                builder: (context, child) {
                  final opacity = _fadeAnimation!.value.clamp(0.0, 1.0);
                  // Ensure offset is valid
                  final offsetVal = 20.0 * (1.0 - opacity);

                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, offsetVal),
                      child: child,
                    ),
                  );
                },
                child: _buildSearchResults(isDarkMode, primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Safe version of the animated suggestions with proper value clamping
  Widget _buildSafeAnimatedSuggestions(bool isDarkMode, Color primaryColor) {
    return AnimatedBuilder(
      animation: _animationController!,
      builder: (context, child) {
        // Ensure opacity is clamped to valid range
        final opacity = _fadeAnimation!.value.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: _buildSearchSuggestions(isDarkMode, primaryColor),
    );
  }

  Widget _buildM3SearchBar(bool isDarkMode, Color primaryColor) {
    return SearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: 'Search for light novels...',
      elevation: MaterialStateProperty.all(2.0),
      backgroundColor: MaterialStateProperty.all(
        isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
      ),
      leading: Icon(
        Icons.search_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      trailing: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchResponse = null;
              });
              // Keep focus if you want, or unfocus
            },
          ),
      ],
      onSubmitted: (_) => _performSearch(page: 1),
    );
  }

  Widget _buildSearchSuggestions(bool isDarkMode, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggestions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches
                .map(
                  (search) => FilterChip(
                    label: Text(search),
                    onSelected: (_) {
                      _searchController.text = search;
                      _performSearch();
                    },
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDarkMode, Color primaryColor) {
    if (_isLoading && _searchResponse == null) {
      return _buildLoadingShimmer(isDarkMode);
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState(isDarkMode, primaryColor);
    }

    if (_searchResponse == null) {
      return _buildEmptyState(isDarkMode, primaryColor);
    }

    if (!_searchResponse!.hasResults) {
      return _buildNoResultsState(isDarkMode, primaryColor);
    }

    // Build search results grid with staggered animation
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                // Use fixed height instead of aspect ratio
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _searchResponse!.results.length + (_isLoading ? 2 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index >= _searchResponse!.results.length) {
                  return _buildLoadingItemShimmer(isDarkMode);
                }

                final result = _searchResponse!.results[index];

                return _buildSafeAnimatedResultItem(
                  index,
                  result,
                  isDarkMode,
                  primaryColor,
                );
              },
            ),
          ),
        ),
        // Enhanced pagination controls
        if (_searchResponse!.totalPages > 1)
          _buildEnhancedPaginationControls(isDarkMode, primaryColor),
      ],
    );
  }

  // Safe error state with proper animation values
  Widget _buildErrorState(bool isDarkMode, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, child) {
              // Ensure values are valid
              final safeValue = value.clamp(0.0, 1.0);
              final safeScale = (0.5 + (safeValue * 0.5)).clamp(0.5, 1.0);

              return Transform.scale(
                scale: safeScale,
                child: Opacity(opacity: safeValue, child: child),
              );
            },
            child: Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Colors.redAccent.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _performSearch(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Safe empty state with proper animation values
  Widget _buildEmptyState(bool isDarkMode, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut, // Changed from elasticOut for safety
            builder: (context, value, child) {
              // Ensure values are valid
              final safeValue = value.clamp(0.0, 1.0);

              return Transform.scale(
                scale: safeValue,
                child: Opacity(opacity: safeValue, child: child),
              );
            },
            child: Icon(
              Icons.auto_stories_rounded,
              size: 100,
              color: primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Find your next adventure',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for light novels to read',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Safe no results state with proper animation values
  Widget _buildNoResultsState(bool isDarkMode, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut, // Changed from elasticOut for safety
            builder: (context, value, child) {
              // Ensure values are valid
              final safeValue = value.clamp(0.0, 1.0);
              final safeAngle = ((1 - safeValue) * math.pi / 10).clamp(
                0.0,
                math.pi / 10,
              );

              return Transform.scale(
                scale: safeValue,
                child: Transform.rotate(
                  angle: safeAngle,
                  child: Opacity(opacity: safeValue, child: child),
                ),
              );
            },
            child: Icon(
              Icons.search_off_rounded,
              size: 80,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Try different keywords or check your spelling',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (mounted) {
                _searchController.clear();
                FocusScope.of(context).requestFocus(_searchFocusNode);
                setState(() {
                  _searchResponse = null;
                });
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Safe animated result item with proper value clamping
  Widget _buildSafeAnimatedResultItem(
    int index,
    SearchResult result,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index % 10) * 50),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // Ensure values are valid
        final safeValue = value.clamp(0.0, 1.0);
        final safeScale = (0.8 + (0.2 * safeValue)).clamp(0.8, 1.0);

        return Transform.scale(
          scale: safeScale,
          child: Opacity(
            opacity: safeValue,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - safeValue)),
              child: child,
            ),
          ),
        );
      },
      child: _buildAnimatedSearchResultItem(result, isDarkMode, primaryColor),
    );
  }

  Widget _buildAnimatedSearchResultItem(
    SearchResult result,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return LightNovelCard(
      novel: LightNovel(
        id: result.url.split('/').last,
        title: result.seriesTitle.isNotEmpty
            ? result.seriesTitle
            : result.title,
        coverUrl: result.coverUrl,
        url: result.url,
        latestChapter: result.chapterTitle,
        // Since SearchResult doesn't have rating/stats, we omit them
      ),
      showChapterInfo: true,
      onTap: () {
        if (result.seriesUrl.isNotEmpty) {
          HapticFeedback.mediumImpact();
          _launchUrl(result.seriesUrl, result);
        } else {
          _launchUrl(result.url, result);
        }
      },
    );
  }

  Widget _buildLoadingShimmer(bool isDarkMode) {
    return Shimmer.fromColors(
      baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: double.infinity * 0.8,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: double.infinity * 0.5,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingItemShimmer(bool isDarkMode) {
    return Shimmer.fromColors(
      baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: double.infinity * 0.8,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: double.infinity * 0.5,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedPaginationControls(bool isDarkMode, Color primaryColor) {
    // Build pagination controls with safety checks
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [Colors.grey[900]!.withOpacity(0.0), Colors.grey[900]!]
              : [Colors.white.withOpacity(0.0), Colors.white],
        ),
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Page ${_searchResponse!.currentPage} of ${_searchResponse!.totalPages}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pagination buttons
                _buildPageButton(
                  icon: Icons.first_page_rounded,
                  onTap: _searchResponse!.currentPage > 1
                      ? () => _performSearch(page: 1)
                      : null,
                  isActive: _searchResponse!.currentPage > 1,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                _buildPageButton(
                  icon: Icons.navigate_before_rounded,
                  onTap: _searchResponse!.currentPage > 1
                      ? () => _performSearch(
                          page: _searchResponse!.currentPage - 1,
                        )
                      : null,
                  isActive: _searchResponse!.currentPage > 1,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                _buildPageNumbers(isDarkMode, primaryColor),
                _buildPageButton(
                  icon: Icons.navigate_next_rounded,
                  onTap:
                      _searchResponse!.currentPage < _searchResponse!.totalPages
                      ? () => _performSearch(
                          page: _searchResponse!.currentPage + 1,
                        )
                      : null,
                  isActive:
                      _searchResponse!.currentPage <
                      _searchResponse!.totalPages,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                _buildPageButton(
                  icon: Icons.last_page_rounded,
                  onTap:
                      _searchResponse!.currentPage < _searchResponse!.totalPages
                      ? () => _performSearch(page: _searchResponse!.totalPages)
                      : null,
                  isActive:
                      _searchResponse!.currentPage <
                      _searchResponse!.totalPages,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required Function()? onTap,
    required bool isActive,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isActive
              ? () {
                  HapticFeedback.lightImpact();
                  onTap?.call();
                }
              : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDarkMode ? Colors.grey[800] : Colors.grey[100])
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? (isDarkMode ? primaryColor : primaryColor)
                  : (isDarkMode ? Colors.grey[700] : Colors.grey[400]),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageNumbers(bool isDarkMode, Color primaryColor) {
    if (_searchResponse == null) return const SizedBox();

    final currentPage = _searchResponse!.currentPage;
    final totalPages = _searchResponse!.totalPages;

    // Dynamically adjust visible pages based on screen width
    int maxVisiblePages = 3;
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 400) {
      maxVisiblePages = 5;
    }

    int startPage = (currentPage - (maxVisiblePages ~/ 2)).clamp(1, totalPages);
    int endPage = (startPage + maxVisiblePages - 1).clamp(1, totalPages);

    if (endPage == totalPages) {
      startPage = (endPage - maxVisiblePages + 1).clamp(1, totalPages);
    }

    List<Widget> pageButtons = [];

    for (int i = startPage; i <= endPage; i++) {
      final isCurrentPage = i == currentPage;

      pageButtons.add(
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Transform.scale(
              scale: isCurrentPage ? value : 1.0,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isCurrentPage
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _performSearch(page: i);
                      },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrentPage
                        ? primaryColor
                        : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(
                      isCurrentPage ? 12 : 18,
                    ),
                    boxShadow: isCurrentPage
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: isCurrentPage
                            ? Colors.white
                            : (isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[700]),
                        fontWeight: isCurrentPage
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: pageButtons);
  }
}

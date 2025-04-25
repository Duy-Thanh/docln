import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../services/search_service.dart';
import '../models/search_result.dart';
import 'package:provider/provider.dart';
import '../services/theme_services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/webview_screen.dart';
import 'dart:math' as math;

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Initialize controllers explicitly, not using late
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;
  
  bool _isLoading = false;
  String _errorMessage = '';
  SearchResponse? _searchResponse;
  int _currentPage = 1;
  bool _isSearchBarFocused = false;
  bool _isDisposed = false; // Track if widget is disposed
  
  // Popular searches for suggestions
  final List<String> _popularSearches = ['Overlord', 'Re:Zero', 'Mushoku Tensei', 'Sword Art Online'];

  @override
  void initState() {
    super.initState();
    
    // Initialize animations safely
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOut,
      )
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOut,
      )
    );
    
    _searchFocusNode.addListener(_onFocusChange);
    
    // Start the animation when screen loads - with safety check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _animationController != null) {
        _animationController!.forward();
      }
    });
  }
  
  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isSearchBarFocused = _searchFocusNode.hasFocus;
      });
    }
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

    // If it's a new search (page 1), update the search field
    if (page == 1 && _searchResponse?.keyword != searchTerm) {
      _searchController.text = searchTerm;
    }
    // If navigating pages with existing response, ensure search field matches
    else if (_searchResponse != null && page > 1) {
      _searchController.text = _searchResponse!.keyword;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        if (page == 1) {
          // Only reset search results if it's a new search
          _searchResponse = null;
        }
        _currentPage = page;
      });
    }

    try {
      // Add haptic feedback when searching
      HapticFeedback.mediumImpact();
      
      final response = await _searchService.search(searchTerm, page: page);
      
      // Use the animation controller for smooth transition of results
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
          _errorMessage = 'Error performing search: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _launchUrl(String url) async {
    if (!mounted) return;
    
    if (await canLaunchUrl(Uri.parse(url))) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewScreen(url: url),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  // Attempt to fix image URLs that might be causing issues
  String _getFixedImageUrl(String originalUrl) {
    try {
      // First apply the domain fix from SearchService
      String url = SearchService.fixImageUrl(originalUrl);
      
      // If the URL still contains docln.net, apply a more aggressive fix
      if (url.contains('docln.net')) {
        // Try a different domain if the original is from docln.net
        Uri uri = Uri.parse(url);
        String path = uri.path;
        
        // Replace with hako.vip domain 
        if (uri.host.startsWith('i.')) {
          return 'https://i.hako.vip$path';
        } else if (uri.host.startsWith('i2.')) {
          return 'https://i2.hako.vip$path';
        }
      }
      
      return url;
    } catch (e) {
      // If anything goes wrong with URL manipulation, return default
      return 'https://ln.hako.vn/img/nocover.jpg';
    }
  }

  // Try multiple fallback image URLs when the primary one fails
  Widget _buildCoverImage(String imageUrl, double height, bool isDarkMode) {
    // List of possible domains to try
    final domains = [
      '',  // Original URL
      'i.hako.vip',
      'i2.hako.vip',
      'ln.hako.vn',
    ];
    
    // Create a fixed URL
    String fixedUrl = _getFixedImageUrl(imageUrl);
    
    return CachedNetworkImage(
      imageUrl: fixedUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      maxHeightDiskCache: 1000, // Limit cache size
      fadeInDuration: const Duration(milliseconds: 300),
      placeholderFadeInDuration: const Duration(milliseconds: 300),
      errorListener: (error) {
        print('Image error: $error for URL: $fixedUrl');
      },
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36',
      },
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          height: height,
          color: Colors.white,
        ),
      ),
      errorWidget: (context, url, error) {
        // Try each domain in sequence if the original fails
        for (int i = 1; i < domains.length; i++) {
          if (!url.contains(domains[i])) {
            try {
              Uri uri = Uri.parse(url);
              String path = uri.path;
              String newUrl = 'https://${domains[i]}$path';
              
              // Return a new CachedNetworkImage with the next domain
              return CachedNetworkImage(
                imageUrl: newUrl,
                height: height,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    height: height,
                    color: Colors.white,
                  ),
                ),
                // Final fallback is a generic image placeholder
                errorWidget: (context, url, error) => Container(
                  height: height,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                      size: height / 3,
                    ),
                  ),
                ),
              );
            } catch (e) {
              continue; // Try next domain if URI parsing fails
            }
          }
        }
        
        // If all domains fail, show a placeholder
        return Container(
          height: height,
          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
          child: Center(
            child: Icon(
              Icons.image_not_supported,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              size: height / 3,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safety check for animation controller
    if (_animationController == null || _fadeAnimation == null || _scaleAnimation == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final themeService = Provider.of<ThemeServices>(context);
    final isDarkMode = themeService.themeMode == ThemeMode.dark;
    final primaryColor = isDarkMode ? Colors.deepOrangeAccent : Colors.deepOrange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        systemOverlayStyle: isDarkMode 
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode 
              ? [Colors.grey[900]!, Colors.grey[850]!]
              : [Colors.white, Colors.grey[50]!],
          ),
        ),
        child: Column(
          children: [
            // Enhanced Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: AnimatedBuilder(
                animation: _animationController!,
                builder: (context, child) {
                  // Ensure values are clamped to valid ranges
                  final scale = _scaleAnimation!.value.clamp(0.5, 1.0);
                  final opacity = _fadeAnimation!.value.clamp(0.0, 1.0);
                  
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  );
                },
                child: _buildAnimatedSearchBar(isDarkMode, primaryColor),
              ),
            ),
            
            // Popular searches or suggestions with proper animation safety
            if (_searchController.text.isEmpty && _searchResponse == null)
              _buildSafeAnimatedSuggestions(isDarkMode, primaryColor),
              
            // Search results
            Expanded(
              child: AnimatedBuilder(
                animation: _animationController!,
                builder: (context, child) {
                  // Ensure values are clamped to valid ranges
                  final opacity = _fadeAnimation!.value.clamp(0.0, 1.0);
                  
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _fadeAnimation!.value.clamp(0.0, 1.0))),
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
  
  Widget _buildAnimatedSearchBar(bool isDarkMode, Color primaryColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 56,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(_isSearchBarFocused ? 16 : 28),
        boxShadow: [
          BoxShadow(
            color: _isSearchBarFocused
                ? primaryColor.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            blurRadius: _isSearchBarFocused ? 8 : 4,
            offset: const Offset(0, 2),
            spreadRadius: _isSearchBarFocused ? 1 : 0,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search for light novels...',
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
            fontSize: 16,
          ),
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.search_rounded,
              color: _isSearchBarFocused
                  ? primaryColor
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              size: 24,
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    // Ensure value is valid
                    final safeValue = value.clamp(0.0, 1.0);
                    
                    return Transform.scale(
                      scale: safeValue,
                      child: Opacity(
                        opacity: safeValue,
                        child: IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _searchController.clear();
                                _searchResponse = null;
                                // Provide haptic feedback
                                HapticFeedback.lightImpact();
                              });
                            }
                          },
                          splashRadius: 20,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    );
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          fillColor: Colors.transparent,
        ),
        cursorColor: primaryColor,
        cursorRadius: const Radius.circular(8),
        cursorWidth: 2.0,
        onSubmitted: (_) => _performSearch(page: 1),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSearchSuggestions(bool isDarkMode, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              'Popular searches',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_popularSearches.length, (index) {
              return _buildSafeSuggestionItem(index, isDarkMode, primaryColor);
            }),
          ),
        ],
      ),
    );
  }

  // Safe version of suggestion item with proper value clamping
  Widget _buildSafeSuggestionItem(int index, bool isDarkMode, Color primaryColor) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        // Ensure values are valid
        final safeValue = value.clamp(0.0, 1.0);
        
        return Transform.scale(
          scale: safeValue,
          child: Opacity(
            opacity: safeValue,
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () {
          if (mounted) {
            setState(() {
              _searchController.text = _popularSearches[index];
              _performSearch(page: 1);
            });
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Chip(
          label: Text(_popularSearches[index]),
          avatar: Icon(
            Icons.trending_up,
            size: 16,
            color: primaryColor,
          ),
          backgroundColor: isDarkMode 
              ? Colors.grey[800]!.withOpacity(0.7) 
              : Colors.grey[200]!.withOpacity(0.7),
          side: BorderSide(
            width: 1,
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!
          ),
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
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
                
                // Staggered animation for grid items with proper safety
                return _buildSafeAnimatedResultItem(index, result, isDarkMode, primaryColor);
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
              final safeAngle = ((1 - safeValue) * math.pi / 10).clamp(0.0, math.pi / 10);
              
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Safe animated result item with proper value clamping
  Widget _buildSafeAnimatedResultItem(int index, SearchResult result, bool isDarkMode, Color primaryColor) {
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

  Widget _buildAnimatedSearchResultItem(SearchResult result, bool isDarkMode, Color primaryColor) {
    return Hero(
      tag: 'search_${result.seriesTitle}_${result.chapterUrl}',
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (result.url.isNotEmpty) {
              HapticFeedback.mediumImpact();
              _launchUrl(result.url);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Cover image with gradient overlay
                  Container(
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Novel cover with fixed height instead of AspectRatio
                        SizedBox(
                          height: 120, // Reduced to give even more room for text
                          child: Stack(
                            children: [
                              // Cover image
                              SizedBox.expand(
                                child: _buildCoverImage(result.coverUrl, 0, isDarkMode),
                              ),
                              
                              // Gradient overlay at bottom of cover
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 40, // Smaller gradient
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Original tag with animation
                              if (result.isOriginal)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOut,
                                    builder: (context, value, child) {
                                      final safeValue = value.clamp(0.0, 1.0);
                                      final safeAngle = ((1 - safeValue) * math.pi / 10).clamp(0.0, math.pi / 10);
                                      
                                      return Transform.scale(
                                        scale: safeValue,
                                        child: Transform.rotate(
                                          angle: safeAngle,
                                          child: Opacity(opacity: safeValue, child: child),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Original',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              
                              // Volume info at bottom of cover
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 8,
                                child: Text(
                                  result.volumeTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Info section that uses remaining card space
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            color: isDarkMode ? Colors.grey[850] : Colors.white,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Series title
                                Text(
                                  result.seriesTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                
                                const SizedBox(height: 4),
                                
                                // Chapter title that fills remaining space
                                Expanded(
                                  child: Text(
                                    result.chapterTitle,
                                    style: TextStyle(
                                      fontSize: 13, 
                                      height: 1.2,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    // Allow as many lines as fit in the available space
                                    maxLines: 5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Ripple effect container
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: primaryColor.withOpacity(0.1),
                        highlightColor: primaryColor.withOpacity(0.05),
                        onTap: () {
                          if (result.url.isNotEmpty) {
                            HapticFeedback.mediumImpact();
                            _launchUrl(result.url);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
        border: Border(top: BorderSide(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 0.5,
        )),
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
                      ? () => _performSearch(page: _searchResponse!.currentPage - 1)
                      : null,
                  isActive: _searchResponse!.currentPage > 1,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                _buildPageNumbers(isDarkMode, primaryColor),
                _buildPageButton(
                  icon: Icons.navigate_next_rounded,
                  onTap: _searchResponse!.currentPage < _searchResponse!.totalPages
                      ? () => _performSearch(page: _searchResponse!.currentPage + 1)
                      : null,
                  isActive: _searchResponse!.currentPage < _searchResponse!.totalPages,
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                _buildPageButton(
                  icon: Icons.last_page_rounded,
                  onTap: _searchResponse!.currentPage < _searchResponse!.totalPages
                      ? () => _performSearch(page: _searchResponse!.totalPages)
                      : null,
                  isActive: _searchResponse!.currentPage < _searchResponse!.totalPages,
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
          onTap: isActive ? () {
            HapticFeedback.lightImpact();
            onTap?.call();
          } : null,
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
                onTap: isCurrentPage ? null : () {
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
                    borderRadius: BorderRadius.circular(isCurrentPage ? 12 : 18),
                    boxShadow: isCurrentPage
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: isCurrentPage
                            ? Colors.white
                            : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                        fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
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
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: pageButtons,
    );
  }
}
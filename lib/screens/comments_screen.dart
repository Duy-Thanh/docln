import 'package:flutter/material.dart';
import '../modules/comment.dart';
import '../services/crawler_service.dart';
import '../widgets/network_image.dart';

class CommentsScreen extends StatefulWidget {
  final String url;
  final String title;

  const CommentsScreen({Key? key, required this.url, required this.title})
    : super(key: key);

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final CrawlerService _crawlerService = CrawlerService();
  final List<Comment> _comments = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _hasMoreComments = false;
  String _nextPageUrl = '';
  bool _hasPrevPage = false;
  String _prevPageUrl = '';
  bool _isLoadingMore = false;
  String _errorMessage = '';
  int _currentPage = 1; // Track current page
  bool _recentlyChangedPage =
      false; // Prevent auto-loading right after page change
  DateTime _lastLoadTime = DateTime.now(); // Track when we last loaded comments
  double _lastScrollPosition =
      0; // Track last scroll position to determine direction

  @override
  void initState() {
    super.initState();
    _loadComments();
    // Add scroll listener for more reliable pagination
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Dedicated scroll handler for pagination
  void _handleScroll() {
    // Skip if no clients or content
    if (!_scrollController.hasClients) return;

    // Return if conditions aren't right for loading more
    if (_isLoadingMore || !_hasMoreComments || _recentlyChangedPage) {
      return;
    }

    // We define "near the bottom" as within 500 pixels OR when scroll position is 70% of the way down
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.7; // 70% threshold

    final isNearBottom =
        currentScroll >= threshold ||
        (maxScroll > 0 && maxScroll - currentScroll <= 500);

    if (isNearBottom) {
      // Debounce to prevent multiple calls
      final now = DateTime.now();
      if (now.difference(_lastLoadTime).inMilliseconds < 200) {
        return;
      }

      print("Auto-loading next page from scroll handler");
      _loadMoreComments();
    }
  }

  // The rest of the existing code for tracking scroll position can remain
  void _onScroll() {
    setState(() {
      _lastScrollPosition = _scrollController.position.pixels;
    });
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentPage =
          1; // We'll update this with the actual value from the response
    });

    try {
      final commentsList = await _crawlerService.getChapterComments(
        widget.url,
        context,
      );

      if (!mounted) return;

      final List<Comment> comments =
          commentsList.map((json) => Comment.fromJson(json)).toList();

      setState(() {
        _comments.clear();
        _comments.addAll(comments);
        _isLoading = false;
        _recentlyChangedPage = true; // Set flag to prevent auto-loading
        _lastLoadTime = DateTime.now(); // Update last load time

        // Check if there are more pages
        if (comments.isNotEmpty) {
          _hasMoreComments = comments.last.hasMorePages;
          _nextPageUrl = comments.last.nextPageUrl;
          _hasPrevPage = comments.last.hasPrevPage;
          _prevPageUrl = comments.last.prevPageUrl;
          _currentPage =
              comments.last.currentPage; // Get actual page number from API
        }
      });

      // Make sure we scroll to top after loading initial data
      _scrollToTop();

      // Reset the recently changed page flag after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _recentlyChangedPage = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải bình luận: ${e.toString()}';
      });
      print('Error loading comments: $e');
    }
  }

  Future<void> _loadMoreComments() async {
    // Don't load more if we're already loading, have no more comments, or just changed pages
    if (_isLoadingMore || !_hasMoreComments || _nextPageUrl.isEmpty) return;

    // Update loading state
    setState(() {
      _isLoadingMore = true;
      _recentlyChangedPage = true; // Set this flag to prevent recursive loading
      _lastLoadTime = DateTime.now(); // Update last load time
    });

    print("Loading more comments from: $_nextPageUrl");

    try {
      final commentsList = await _crawlerService.getChapterComments(
        _nextPageUrl,
        context,
      );

      if (!mounted) return;

      final List<Comment> comments =
          commentsList.map((json) => Comment.fromJson(json)).toList();

      setState(() {
        _comments.clear(); // Clear and replace with new comments
        _comments.addAll(comments);
        _isLoadingMore = false;

        // Update pagination info
        if (comments.isNotEmpty) {
          _hasMoreComments = comments.last.hasMorePages;
          _nextPageUrl = comments.last.nextPageUrl;
          _hasPrevPage = comments.last.hasPrevPage;
          _prevPageUrl = comments.last.prevPageUrl;
          _currentPage =
              comments.last.currentPage; // Get actual page number from API
          print("Loaded page: $_currentPage, has more: $_hasMoreComments");
        } else {
          _hasMoreComments = false;
        }
      });

      // Scroll to top after loading new page
      _scrollToTop();

      // Reset the recently changed page flag after a very short delay
      // This prevents immediate loading of the next page after this one
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _recentlyChangedPage = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _recentlyChangedPage = false;
        _errorMessage = 'Không thể tải thêm bình luận: ${e.toString()}';
      });
      print('Error loading more comments: $e');
    }
  }

  Future<void> _loadPreviousComments() async {
    // Don't load previous if we're already loading, have no previous page, or just changed pages
    if (_isLoadingMore || !_hasPrevPage || _prevPageUrl.isEmpty) return;

    // Add debounce to prevent rapid loading
    final now = DateTime.now();
    if (now.difference(_lastLoadTime).inMilliseconds < 300) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _recentlyChangedPage = true; // Set flag to prevent auto-loading
      _lastLoadTime = now; // Update last load time
    });

    try {
      final commentsList = await _crawlerService.getChapterComments(
        _prevPageUrl,
        context,
      );

      if (!mounted) return;

      final List<Comment> comments =
          commentsList.map((json) => Comment.fromJson(json)).toList();

      setState(() {
        _comments.clear(); // Clear and replace with previous page
        _comments.addAll(comments);
        _isLoadingMore = false;

        // Update pagination info
        if (comments.isNotEmpty) {
          _hasMoreComments = comments.last.hasMorePages;
          _nextPageUrl = comments.last.nextPageUrl;
          _hasPrevPage = comments.last.hasPrevPage;
          _prevPageUrl = comments.last.prevPageUrl;
          _currentPage =
              comments.last.currentPage; // Get actual page number from API
        } else {
          _hasPrevPage = false;
        }
      });

      // Scroll to top after loading previous page
      _scrollToTop();

      // Reset the recently changed page flag after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _recentlyChangedPage = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _recentlyChangedPage = false;
        _errorMessage = 'Không thể tải trang trước: ${e.toString()}';
      });
      print('Error loading previous comments: $e');
    }
  }

  // Helper method to scroll to top
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      // Set the flag right before scrolling to prevent auto-loading
      setState(() {
        _recentlyChangedPage = true;
      });

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // Reset the flag after a longer delay to give time for the animation to complete
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _recentlyChangedPage = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bình luận: ${widget.title}'), elevation: 1),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? _buildErrorState()
              : _comments.isEmpty
              ? _buildEmptyState()
              : _comments.length == 1 && _comments.first.isEmptyPage
              ? _buildEmptyState()
              : _comments.length == 1 && _comments.first.isErrorPage
              ? _buildErrorState()
              : _buildCommentsList(),
      bottomNavigationBar: _buildPaginationBar(),
    );
  }

  Widget _buildEmptyState() {
    // Use actual empty page message if it exists
    String emptyMessage = 'Không có bình luận nào';
    String subMessage = 'Hãy là người đầu tiên bình luận';

    if (_comments.isNotEmpty && _comments.first.isEmptyPage) {
      emptyMessage =
          _comments.first.content.isNotEmpty
              ? _comments.first.content
              : 'Không có bình luận nào';

      // If we're on a page > 1, customize the message
      if (_comments.first.currentPage > 1) {
        subMessage =
            'Không có bình luận trên trang ${_comments.first.currentPage}';
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.comment_bank_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    // Use actual error message if it exists
    String errorTitle = 'Có lỗi xảy ra';
    String errorDetail =
        _errorMessage.isNotEmpty
            ? _errorMessage
            : 'Không thể tải bình luận, vui lòng thử lại sau';

    if (_comments.isNotEmpty && _comments.first.isErrorPage) {
      errorDetail =
          _comments.first.content.isNotEmpty
              ? _comments.first.content
              : errorDetail;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            errorTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              errorDetail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadComments,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      // Each comment can have multiple items (the comment itself + its replies)
      itemCount: _calculateTotalItemCount() + (_hasMoreComments ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator if we're at the end and have more comments to load
        if (index == _calculateTotalItemCount() && _hasMoreComments) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Find which comment and/or reply this index refers to
        final indexInfo = _getCommentAtIndex(index);
        if (indexInfo == null) return const SizedBox.shrink();

        final comment = indexInfo['comment'] as Comment;
        final isReply = indexInfo['isReply'] as bool;

        if (isReply) {
          // This is a reply, render it as indented
          return _buildReplyItem(comment);
        } else {
          // This is a top-level comment
          return _buildCommentItem(comment);
        }
      },
    );
  }

  // Helper to get comment at the given flattened index
  Map<String, dynamic>? _getCommentAtIndex(int index) {
    int currentIndex = 0;

    // Special case: if we have no comments, return null
    if (_comments.isEmpty) return null;

    // Special case: if our only comment is an empty page indicator
    if (_comments.length == 1 && _comments.first.isEmptyPage) {
      return index == 0 ? {'comment': _comments.first, 'isReply': false} : null;
    }

    for (final comment in _comments) {
      // Skip empty page indicators
      if (comment.isEmptyPage) continue;

      // Check if this is the comment we're looking for
      if (currentIndex == index) {
        return {'comment': comment, 'isReply': false};
      }
      currentIndex++;

      // Check replies
      if (comment.replies.isNotEmpty) {
        for (final reply in comment.replies) {
          if (currentIndex == index) {
            return {'comment': reply, 'isReply': true};
          }
          currentIndex++;
        }
      }
    }

    return null;
  }

  // Helper to calculate total number of items (comments + replies)
  int _calculateTotalItemCount() {
    int count = 0;

    // Special case: if we have no comments, return 0
    if (_comments.isEmpty) return 0;

    // Special case: if our only comment is an empty page indicator
    if (_comments.length == 1 && _comments.first.isEmptyPage) {
      return 1; // Just show the empty state
    }

    for (final comment in _comments) {
      // Skip empty page indicators when counting
      if (comment.isEmptyPage) continue;

      // Add 1 for the comment itself
      count++;
      // Add the number of replies
      count += comment.replies.length;
    }
    return count;
  }

  // Build a reply comment with indentation
  Widget _buildReplyItem(Comment reply) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 40.0, bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply indicator line with improved visual design
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              // Use a gradient to make the connecting line fade at the top
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.2),
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDarkMode
                        ? Colors.grey.shade800.withOpacity(0.6)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                // Add a subtle border to better distinguish replies
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  width: 1,
                ),
                // Add a subtle shadow for depth
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Avatar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: OptimizedNetworkImage(
                          imageUrl: reply.user.image,
                          fit: BoxFit.cover,
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.person, size: 16),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reply Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Username and badges with reply indicator
                          Row(
                            children: [
                              Text(
                                reply.user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Add "reply" indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Trả lời',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              if (reply.user.badges.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                ...reply.user.badges.map(
                                  (badge) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      badge,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Comment time
                          Text(
                            reply.timestamp,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Comment content
                          Text(
                            reply.content,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color:
            isDarkMode
                ? Colors.grey.shade800.withOpacity(0.6)
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 40,
                height: 40,
                child: OptimizedNetworkImage(
                  imageUrl: comment.user.image,
                  fit: BoxFit.cover,
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.person),
                      ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Comment Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username and badges
                  Row(
                    children: [
                      Text(
                        comment.user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (comment.user.badges.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            comment.user.badges.first,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Comment time
                  Text(
                    comment.timestamp,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 8),

                  // Comment content
                  Text(comment.content, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildPaginationBar() {
    // Don't show pagination bar when loading or no comments
    if (_isLoading ||
        _comments.isEmpty ||
        (_comments.length == 1 &&
            _comments.first.isEmptyPage &&
            _comments.first.currentPage <= 1)) {
      return null;
    }

    // Get current page number
    int currentPage = 1;
    bool hasMorePages = false;
    bool hasPrevPage = false;

    if (_comments.isNotEmpty) {
      if (_comments.first.isEmptyPage) {
        // If it's an empty page, use its page number
        currentPage = _comments.first.currentPage;
        hasPrevPage = currentPage > 1;
        hasMorePages = false; // Empty pages don't have "more"
      } else {
        // Use the last comment for pagination info
        final lastComment = _comments.last;
        currentPage = lastComment.currentPage;
        hasMorePages = lastComment.hasMorePages;
        hasPrevPage = lastComment.hasPrevPage;
      }
    }

    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous page button
            ElevatedButton.icon(
              onPressed:
                  _isLoadingMore || !hasPrevPage ? null : _loadPreviousComments,
              icon:
                  _isLoadingMore && hasPrevPage
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.arrow_back_ios_new, size: 16),
              label: const Text('Trước'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hasPrevPage && !_isLoadingMore
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                foregroundColor: Colors.white,
              ),
            ),

            // Page indicator with loading state
            _isLoadingMore
                ? Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Đang tải...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                )
                : Text(
                  'Trang $currentPage',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

            // Next page button
            ElevatedButton.icon(
              onPressed:
                  _isLoadingMore || !hasMorePages ? null : _loadMoreComments,
              icon:
                  _isLoadingMore && hasMorePages
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
              label: const Text('Sau'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hasMorePages && !_isLoadingMore
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

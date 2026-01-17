import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:docln/core/models/light_novel.dart';
import 'package:docln/core/widgets/light_novel_card.dart';
import 'package:docln/core/widgets/chapter_card.dart';
import 'package:docln/core/widgets/custom_toast.dart';
import 'package:docln/core/widgets/webview_screen.dart';
import 'package:docln/features/reader/ui/reader_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:docln/core/services/bookmark_service_v2.dart';
import 'package:docln/core/services/history_service_v2.dart';
import 'package:docln/core/services/background_notification_service.dart';
import 'package:docln/core/services/novel_database_service.dart';
import 'package:provider/provider.dart';
import 'package:docln/core/widgets/network_image.dart';
import 'package:docln/core/services/api_service.dart';
import 'package:docln/core/models/hako_models.dart';

class LightNovelDetailsScreen extends StatefulWidget {
  final LightNovel novel;
  final String novelUrl;

  const LightNovelDetailsScreen({
    Key? key,
    required this.novel,
    required this.novelUrl,
  }) : super(key: key);

  @override
  _LightNovelDetailsScreenState createState() =>
      _LightNovelDetailsScreenState();
}

class _LightNovelDetailsScreenState extends State<LightNovelDetailsScreen> {
  final BackgroundNotificationService _backgroundService =
      BackgroundNotificationService();
  bool _isLoading = true;
  bool _notificationEnabled = true;
  List<String> _genres = [];
  String _description = '';
  List<Map<String, dynamic>> _chapters = [];
  String _author = '';
  String _status = '';
  List<String> _alternativeTitles = [];
  int? _wordCount;
  int? _views;
  String? _lastUpdated;
  String _novelType = '';
  bool _loadError = false;
  double? _rating;
  int? _reviews;

  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNovelDetails();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    final enabled = await _backgroundService.isNovelNotificationEnabled(
      widget.novel.id,
    );
    if (mounted) {
      setState(() {
        _notificationEnabled = enabled;
      });
    }
  }

  final ApiService _apiService = ApiService();

  Future<void> _loadNovelDetails() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });

    try {
      // GỌI API THAY VÌ CRAWL
      final NovelDetail detail = await _apiService.fetchNovelDetail(
        widget.novelUrl,
      );

      if (mounted) {
        // Flatten chapters from volumes to match UI expectation
        final List<Map<String, dynamic>> flatChapters = [];
        for (var vol in detail.volumes) {
          for (var chap in vol.chapters) {
            flatChapters.add({
              'title': chap.title,
              'url': chap.url,
              'date': chap.time,
              'volume': vol.title, // Nếu mày muốn hiện tên tập
            });
          }
        }

        // Tạo object LightNovel mới để lưu vào DB (giữ nguyên logic cũ của mày)
        final updatedNovel = LightNovel(
          id: detail.id.isNotEmpty ? detail.id : widget.novel.id,
          title: detail.title,
          url: widget.novel.url,
          coverUrl: detail.cover,
          chapters: flatChapters.length,
          latestChapter: flatChapters.isNotEmpty
              ? flatChapters.last['title']
              : widget.novel.latestChapter,
          // Mấy cái rating/views API chưa trả về thì tạm thời lấy cũ hoặc null
          rating: null,
          reviews: null,
          wordCount: null,
          views: null,
          lastUpdated: null,
          alternativeTitles: [],
        );

        // Save to DB (Logic cũ của mày)
        try {
          final db = Provider.of<NovelDatabaseService>(context, listen: false);
          await db.saveNovel(updatedNovel);
        } catch (e) {
          debugPrint('⚠️ Failed to save novel data: $e');
        }

        setState(() {
          _genres = detail.genres;
          _description = detail.summary; // API đã trả về text sạch
          _chapters = flatChapters;
          _author = detail.author;
          _status = detail.status;
          _alternativeTitles = []; // API hiện tại chưa parse cái này, kệ nó
          _novelType = 'Truyện dịch'; // Mặc định hoặc parse từ API nếu cần
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _description = 'Error loading novel details: $e';
          CustomToast.show(context, 'Error: ${e.toString()}');
        });
      }
    }
  }

  // int? _extractNumberFromString(String text, String pattern) {
  //   final regex = RegExp(pattern);
  //   final match = regex.firstMatch(text);
  //   if (match != null && match.group(1) != null) {
  //     return int.tryParse(match.group(1)!.replaceAll(RegExp(r'[,.]'), ''));
  //   }
  //   return null;
  // }

  // Handle case when data is empty
  void _handleEmptyData() {
    // Set some placeholder data for testing
    setState(() {
      _description =
          'Tôi đã mất đi những người quan trọng, nhưng giấc mơ đã thành hiện thực, nên tôi quyết định không ngoảnh nhìn quá khứ mà sẽ tiến về phía trước';
      _genres = ['Drama', 'Harem', 'Netoratre', 'Romance', 'Misunderstanding'];
      _author = 'Unknown Author';

      // Show a toast about the fallback data
      CustomToast.show(
        context,
        'Could not get complete novel details, showing placeholder data',
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      // Threshold increased to 300 to match header height roughly
      final isScrolled = _scrollController.offset > 300;
      if (isScrolled != _isScrolled) {
        setState(() {
          _isScrolled = isScrolled;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: (_isScrolled || _isLoading) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.novel.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: AnimatedOpacity(
          opacity: _isScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color:
                    (theme.appBarTheme.backgroundColor ??
                            theme.colorScheme.surface)
                        .withOpacity(0.8),
              ),
            ),
          ),
        ),
        elevation: 0,
        iconTheme: IconThemeData(
          color: _isScrolled
              ? theme.iconTheme.color
              : Colors.white, // Always white on transparent (dark img)
        ),
        actions: [
          // Add the web reading button to the app bar
          if (!_isLoading)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(url: widget.novelUrl),
                  ),
                );
              },
              icon: const Icon(Icons.language),
              label: const Text('Read on Web'),
              style: TextButton.styleFrom(
                foregroundColor: _isScrolled
                    ? theme.colorScheme.primary
                    : Colors.white,
              ),
            ),
          BookmarkButton(
            novel: widget.novel,
            activeColor: _isScrolled ? theme.colorScheme.primary : Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showMoreOptions(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading novel details...',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : _buildNovelDetailContent(isDarkMode),
    );
  }

  Widget _buildNovelDetailContent(bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _loadNovelDetails,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNovelHeader(),
            _buildStatsSection(),
            if (_alternativeTitles.isNotEmpty) _buildAlternativeTitlesSection(),
            _buildAuthorSection(),
            _buildInfoSection(),
            if (_description.isNotEmpty) _buildDescriptionSection(),
            if (_chapters.isNotEmpty) _buildChaptersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildNovelHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Logic for Continue Reading
    final historyService = Provider.of<HistoryServiceV2>(context);
    final historyItem = historyService.getHistoryItem(widget.novel.id);

    String buttonText = 'READ NOW';
    Map<String, dynamic>? targetChapter;

    if (_chapters.isNotEmpty) {
      targetChapter = _chapters.first; // Default to first

      if (historyItem != null) {
        // Try to find the last read chapter
        final lastReadTitle = historyItem.lastReadChapter;
        final foundChapter = _chapters.firstWhere(
          (c) => c['title'] == lastReadTitle,
          orElse: () => _chapters.first,
        );

        if (foundChapter['title'] == lastReadTitle) {
          buttonText = 'CONTINUE READING';
          targetChapter = foundChapter;
        }
      }
    }

    return Stack(
      children: [
        // Background Blur (using CachedNetworkImage directly for stability)
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.9),
                ],
              ).createShader(rect);
            },
            blendMode: BlendMode.darken,
            child: OptimizedNetworkImage(
              imageUrl: widget.novel.coverUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              // Use low res for blur background to save RAM
              maxWidth: 100,
            ),
          ),
        ),

        // Content
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            kToolbarHeight + MediaQuery.of(context).padding.top + 20,
            20,
            20,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Cover
                  Hero(
                    tag: 'novel_${widget.novel.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: OptimizedNetworkImage(
                          imageUrl: widget.novel.coverUrl,
                          width: 130,
                          height: 190,
                          fit: BoxFit.cover,
                          memCacheHeight: 400, // Optimize RAM
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_novelType.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _novelType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                        Text(
                          widget.novel.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),

                        if (_author.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _author,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 6),

                        if (_status.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                _status == 'Đang tiến hành'
                                    ? Icons.timelapse
                                    : Icons.check_circle,
                                size: 14,
                                color: _status == 'Đang tiến hành'
                                    ? Colors.greenAccent
                                    : Colors.blueAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _status,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (targetChapter != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReaderScreen(
                                      url: _getFullUrl(
                                        targetChapter!['url'],
                                      ), // Assuming ApiService helper
                                      title: widget.novel.title,
                                      novel: widget.novel,
                                      chapterTitle:
                                          targetChapter!['title'] ??
                                          'Chapter 1',
                                    ),
                                  ),
                                );
                              } else if (!_isLoading) {
                                // Webview fallback
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WebViewScreen(url: widget.novelUrl),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: colorScheme.primary.withOpacity(0.4),
                      ),
                      icon: Icon(
                        buttonText == 'CONTINUE READING'
                            ? Icons.history_edu
                            : Icons.menu_book_rounded,
                      ),
                      label: Text(
                        buttonText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Notification/Bookmark Button
                  Material(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white24, width: 1.5),
                    ),
                    child: InkWell(
                      onTap: () async {
                        // Existing notification logic
                        final bookmarkService = Provider.of<BookmarkServiceV2>(
                          context,
                          listen: false,
                        );
                        if (!bookmarkService.isBookmarked(widget.novel.id)) {
                          CustomToast.show(
                            context,
                            'Please bookmark this novel first!',
                          );
                          return;
                        }
                        final newStatus = !_notificationEnabled;
                        await _backgroundService.setNovelNotificationEnabled(
                          widget.novel.id,
                          newStatus,
                        );
                        setState(() => _notificationEnabled = newStatus);
                        CustomToast.show(
                          context,
                          newStatus
                              ? 'Notifications enabled'
                              : 'Notifications disabled',
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Icon(
                          _notificationEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: _notificationEnabled
                              ? colorScheme.primary
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItemEnhanced(
              'Last Updated',
              _formatDate(_lastUpdated),
              Icons.access_time,
              colorScheme.primary,
              textTheme,
            ),
            _buildVerticalDivider(),
            _buildStatItemEnhanced(
              'Word Count',
              _formatNumber(_wordCount),
              Icons.format_list_numbered,
              colorScheme.primary,
              textTheme,
            ),
            _buildVerticalDivider(),
            _buildStatItemEnhanced(
              'Đánh giá',
              _formatRating(_rating, _reviews),
              Icons.star,
              Colors.amber,
              textTheme,
            ),
            _buildVerticalDivider(),
            _buildStatItemEnhanced(
              'Lượt xem',
              _formatNumber(_views),
              Icons.visibility,
              colorScheme.primary,
              textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return SizedBox(
      height: 40,
      child: VerticalDivider(
        color: Theme.of(context).dividerColor.withOpacity(0.5),
        width: 1,
        thickness: 1,
      ),
    );
  }

  String _formatNumber(int? number) {
    if (number == null) return 'N/A';
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildStatItemEnhanced(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    TextTheme textTheme,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';

    try {
      // Try to parse date in format dd/MM/yyyy HH:mm:ss
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
        final datePart = parts[0].split('/');
        final timePart = parts[1].split(':');

        if (datePart.length == 3 && timePart.length >= 2) {
          final day = int.parse(datePart[0]);
          final month = int.parse(datePart[1]);
          final year = int.parse(datePart[2]);
          final hour = int.parse(timePart[0]);
          final minute = int.parse(timePart[1]);
          final second = timePart.length > 2 ? int.parse(timePart[2]) : 0;

          final date = DateTime(year, month, day, hour, minute, second);
          final now = DateTime.now();

          // Calculate years, months, days more accurately
          int years = now.year - date.year;
          int months = now.month - date.month;
          int days = now.day - date.day;

          // Adjust for negative months or days
          if (days < 0) {
            // Go back one month and add days of that month
            months--;
            // Get the last day of the previous month
            final prevMonth = DateTime(now.year, now.month, 0);
            days += prevMonth.day;
          }

          if (months < 0) {
            years--;
            months += 12;
          }

          // Get the total hours/minutes/seconds difference for recent updates
          final difference = now.difference(date);

          // Custom compact time format with calendar-accurate months and years
          if (years > 0) {
            return '${years}y ago';
          } else if (months > 0) {
            return '${months}mo ago';
          } else if (days > 0) {
            return '${days}d ago';
          } else if (difference.inHours > 0) {
            return '${difference.inHours}h ago';
          } else if (difference.inMinutes > 0) {
            return '${difference.inMinutes}m ago';
          } else {
            return '${difference.inSeconds}s ago';
          }
        }
      }
      return dateStr; // Return original if can't parse
    } catch (e) {
      return dateStr; // Return original on error
    }
  }

  String _formatRating(double? rating, int? reviews) {
    if (rating == null || rating == 0) {
      return reviews != null && reviews > 0 ? '0,00 / $reviews' : 'N/A / 0';
    }

    // Format with comma as decimal separator to match original format
    String ratingStr = rating.toStringAsFixed(2).replaceAll('.', ',');

    // Return in the format "X,XX / Y" to match the original format
    return '$ratingStr / ${reviews ?? 0}';
  }

  Widget _buildAlternativeTitlesSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tên khác',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(
              _alternativeTitles.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.label_outline,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _alternativeTitles[index],
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // If no author is specified, display "Unknown"
    final authorName = _author.isNotEmpty ? _author : "Unknown";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tác giả',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  radius: 20,
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : "?",
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_status.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Tình trạng: $_status",
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Extract meaningful data from text and description
    final allTextContent =
        '''
$_description
Tác giả: $_author
Tình trạng: $_status
${_genres.join(', ')}
''';

    // Try to extract additional info
    final Map<String, String> extractedInfo = {};

    // Look for patterns like "Label: Value"
    final RegExp labelPattern = RegExp(r'([^:]+):\s*([^\n]+)');
    final matches = labelPattern.allMatches(allTextContent);
    for (final match in matches) {
      final label = match.group(1)?.trim();
      final value = match.group(2)?.trim();
      if (label != null &&
          value != null &&
          label.isNotEmpty &&
          value.isNotEmpty) {
        extractedInfo[label] = value;
      }
    }

    // Add explicitly known values
    if (_author.isNotEmpty) extractedInfo['Tác giả'] = _author;
    if (_status.isNotEmpty) extractedInfo['Tình trạng'] = _status;

    // Look for other common metadata
    final viewsPattern = RegExp(r'Lượt xem[:\s]*([0-9,.]+)');
    final viewsMatch = viewsPattern.firstMatch(allTextContent);
    if (viewsMatch != null && viewsMatch.group(1) != null) {
      extractedInfo['Lượt xem'] = viewsMatch.group(1)!;
    }

    final wordCountPattern = RegExp(r'Số từ[:\s]*([0-9,.]+)');
    final wordCountMatch = wordCountPattern.firstMatch(allTextContent);
    if (wordCountMatch != null && wordCountMatch.group(1) != null) {
      extractedInfo['Số từ'] = wordCountMatch.group(1)!;
    }

    final ratingPattern = RegExp(r'Đánh giá[:\s]*([0-9,.]+)');
    final ratingMatch = ratingPattern.firstMatch(allTextContent);
    if (ratingMatch != null && ratingMatch.group(1) != null) {
      extractedInfo['Đánh giá'] = ratingMatch.group(1)!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Genre section
            if (_genres.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.category, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Thể loại',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _genres.map((genre) {
                  // Get a consistent color for each genre
                  final colorIndex = genre.hashCode % _genreColors.length;
                  final color = _genreColors[colorIndex];

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      genre,
                      style: textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Additional info
            if (extractedInfo.isNotEmpty &&
                !extractedInfo.keys.every(
                  (k) =>
                      k == 'Tác giả' ||
                      k == 'Tình trạng' ||
                      k == 'Lượt xem' ||
                      k == 'Số từ' ||
                      k == 'Đánh giá',
                ))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_genres.isNotEmpty) const Divider(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thông tin khác',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...extractedInfo.entries
                        .where(
                          (entry) =>
                              entry.key != 'Tác giả' &&
                              entry.key != 'Tình trạng' &&
                              entry.key != 'Lượt xem' &&
                              entry.key != 'Số từ' &&
                              entry.key != 'Đánh giá',
                        )
                        .map((entry) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key}:',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value,
                                  style: textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // List of colors for genre tags
  final List<Color> _genreColors = [
    const Color(0xFF6B5FE5), // Purple
    const Color(0xFF5968E9), // Indigo
    const Color(0xFF4CC9F0), // Blue
    const Color(0xFF3FB7E8), // Sky Blue
    const Color(0xFF3A8CB5), // Teal
    const Color(0xFF7209B7), // Magenta
    const Color(0xFF8075F5), // Light Purple
  ];

  Widget _buildDescriptionSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Clean up description by removing excessive whitespace and known labels
    String cleanedDesc = _description
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll('Truyện dịch', '')
        .trim();

    // Remove common patterns that might be part of the metadata, not the description
    final metadataPatterns = [
      RegExp(r'Tác giả:.*?\n'),
      RegExp(r'Tình trạng:.*?\n'),
      RegExp(r'Thể loại:.*?\n'),
      RegExp(r'Lượt xem:.*?\n'),
      RegExp(r'Số từ:.*?\n'),
      RegExp(r'Đánh giá:.*?\n'),
    ];

    for (final pattern in metadataPatterns) {
      cleanedDesc = cleanedDesc.replaceAll(pattern, '');
    }

    // Extract author information - move to separate section
    String authorName = '';

    // Check if the description contains "Tác giả:" at the end
    final authorPattern = RegExp(r'Tác giả:\s*([^\n]+)$', multiLine: true);
    final authorMatch = authorPattern.firstMatch(cleanedDesc);

    if (authorMatch != null && authorMatch.group(1) != null) {
      // Remove the "Tác giả:" line from the description
      cleanedDesc = cleanedDesc.replaceAll(authorPattern, '').trim();
    }

    // If there's a standalone author name at the end, remove it
    final lastLinePattern = RegExp(r'\n([^\n]+)$');
    final lastLineMatch = lastLinePattern.firstMatch(cleanedDesc);

    if (lastLineMatch != null && lastLineMatch.group(1) != null) {
      final lastLine = lastLineMatch.group(1)!.trim();

      // If the last line is short and doesn't contain punctuation, it's likely the author
      if (lastLine.length < 30 && !lastLine.contains(RegExp(r'[.,:;!?]'))) {
        cleanedDesc = cleanedDesc.replaceAll(lastLinePattern, '').trim();
      }
    }

    // Extract summary if it has a specific section
    final summarySection = RegExp(
      r'Tóm tắt:(.*?)(?=\n\n|\n[A-Z]|$)',
      dotAll: true,
    ).firstMatch(cleanedDesc);
    if (summarySection != null && summarySection.group(1) != null) {
      cleanedDesc = summarySection.group(1)!.trim();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tóm tắt',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              child: Text(
                cleanedDesc,
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  letterSpacing: 0.2,
                  fontSize: 15.0,
                ),
                textAlign: TextAlign.left,
                softWrap: true,
              ),
            ),

            if (cleanedDesc.length > 300)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      // Could implement a "show more" feature here
                    },
                    icon: const Icon(Icons.more_horiz, size: 18),
                    label: const Text('Xem thêm'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Check if we have meaningful chapters
    final hasRealChapters =
        _chapters.isNotEmpty &&
        _chapters.any((ch) => ch['url']?.isNotEmpty == true);

    // If we don't have any real chapters, let's see if we know how many there are
    final int chapterCount = hasRealChapters
        ? _chapters.length
        : int.tryParse(
                RegExp(r'(\d+)\s+chương').firstMatch(_description)?.group(1) ??
                    '0',
              ) ??
              0;

    // If no chapters or count found, but UI shows chapters, create dummy chapter list
    List<Map<String, dynamic>> displayChapters = [];

    if (!hasRealChapters && chapterCount > 0) {
      // Create dummy chapters with numbers only
      for (int i = 1; i <= chapterCount; i++) {
        displayChapters.add({
          'title': 'Chapter $i',
          'url': widget.novelUrl,
          'date': '',
        });
      }
    } else {
      displayChapters = _chapters;
    }

    if (displayChapters.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 48,
                  color: colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'Không có chương nào',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WebViewScreen(url: widget.novelUrl),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Xem trên trang web'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Danh sách chương',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${displayChapters.length} chương',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Show limited chapters with a more attractive UI
            ...displayChapters.take(5).map((chapter) {
              final chapterUrl = _getFullUrl(chapter['url'] ?? '');
              final hasDate = chapter['date']?.isNotEmpty == true;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReaderScreen(
                        url: chapterUrl,
                        title: widget.novel.title,
                        novel: widget.novel,
                        chapterTitle:
                            chapter['title'] ??
                            'Chapter ${displayChapters.indexOf(chapter) + 1}',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.article_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter['title'] ??
                                  'Chapter ${displayChapters.indexOf(chapter) + 1}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (hasDate)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  chapter['date'] ?? '',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (displayChapters.length > 5) const Divider(height: 1),
            if (displayChapters.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      _showAllChapters(displayChapters);
                    },
                    icon: Icon(
                      Icons.list_alt,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    label: Text(
                      'View all ${displayChapters.length} chapters',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAllChapters(List<Map<String, dynamic>> chapters) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Danh sách chương (${chapters.length})',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: chapters.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      final chapterUrl = _getFullUrl(chapter['url'] ?? '');
                      final hasDate = chapter['date']?.isNotEmpty == true;

                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          chapter['title'] ?? 'Chapter ${index + 1}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: hasDate
                            ? Text(
                                chapter['date'] ?? '',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              )
                            : null,
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReaderScreen(
                                url: chapterUrl,
                                title: widget.novel.title,
                                novel: widget.novel,
                                chapterTitle:
                                    chapter['title'] ?? 'Chapter ${index + 1}',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper method to ensure URLs are properly formatted
  String _getFullUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http')) {
      return relativeUrl; // Already a full URL
    }

    // Extract base domain from novelUrl
    Uri novelUri = Uri.parse(widget.novelUrl);
    String domain = '${novelUri.scheme}://${novelUri.host}';

    // Handle paths correctly
    if (relativeUrl.startsWith('/')) {
      return '$domain$relativeUrl';
    } else {
      return '$domain/$relativeUrl';
    }
  }

  void _showMoreOptions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bookmarkService = Provider.of<BookmarkServiceV2>(
      context,
      listen: false,
    );
    final isBookmarked = bookmarkService.isBookmarked(widget.novel.id);

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
            leading: Icon(Icons.share, color: colorScheme.primary),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              _shareNovel();
            },
          ),
          ListTile(
            leading: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
              color: colorScheme.primary,
            ),
            title: Text(
              isBookmarked ? 'Remove from bookmarks' : 'Add to bookmarks',
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleBookmark();
            },
          ),
          ListTile(
            leading: Icon(Icons.open_in_browser, color: colorScheme.primary),
            title: const Text('Open in browser'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebViewScreen(url: widget.novelUrl),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.report_outlined, color: colorScheme.primary),
            title: const Text('Report issue'),
            onTap: () {
              Navigator.pop(context);
              _showReportIssueDialog();
            },
          ),
        ],
      ),
    );
  }

  void _shareNovel() {
    final String novelTitle = widget.novel.title;
    final String shareText =
        'Check out this light novel: $novelTitle\n${widget.novelUrl}';

    Share.share(shareText, subject: 'Light Novel Recommendation')
        .then((_) {
          // Optional: Analytics tracking for shares
        })
        .catchError((error) {
          CustomToast.show(context, 'Error sharing: $error');
        });
  }

  void _showReportIssueDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report an Issue',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What issue are you experiencing with this novel?',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildReportOption(
              icon: Icons.broken_image_outlined,
              title: 'Broken images',
              onTap: () => _submitReport('Broken images', widget.novelUrl),
            ),
            _buildReportOption(
              icon: Icons.translate,
              title: 'Translation errors',
              onTap: () => _submitReport('Translation errors', widget.novelUrl),
            ),
            _buildReportOption(
              icon: Icons.format_indent_decrease,
              title: 'Formatting issues',
              onTap: () => _submitReport('Formatting issues', widget.novelUrl),
            ),
            _buildReportOption(
              icon: Icons.error_outline,
              title: 'Content errors',
              onTap: () => _submitReport('Content errors', widget.novelUrl),
            ),
            _buildReportOption(
              icon: Icons.security,
              title: 'Inappropriate content',
              onTap: () =>
                  _submitReport('Inappropriate content', widget.novelUrl),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
      ),
    );
  }

  void _submitReport(String issueType, String novelUrl) {
    try {
      // Create a simplified version of the title without special characters
      final simplifiedTitle = widget.novel.title.length > 30
          ? '${widget.novel.title.substring(0, 30)}...'
          : widget.novel.title;

      // Use a simpler subject line with fewer special characters
      final subject = 'Report: $issueType';
      final body =
          'Novel: $simplifiedTitle\nIssue Type: $issueType\nURL: $novelUrl\n\nPlease describe the issue in detail:';

      // Try the mailto URL first
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'support@docln.net',
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );

      _launchEmailWithFallback(emailUri, subject, body);
    } catch (e) {
      CustomToast.show(context, 'Error creating report: $e');
    }
  }

  Future<void> _launchEmailWithFallback(
    Uri emailUri,
    String subject,
    String body,
  ) async {
    try {
      final canLaunch = await canLaunchUrl(emailUri);
      if (canLaunch) {
        await launchUrl(emailUri);
      } else {
        // If mailto fails, try a direct intent on Android or show manual instructions
        CustomToast.show(
          context,
          'Could not open email client. Please email support@docln.net manually.',
          duration: const Duration(seconds: 6),
        );

        // Show a dialog with manual instructions
        _showManualReportInstructions(subject, body);
      }
    } catch (e) {
      _showManualReportInstructions(subject, body);
      print('Email launch error: $e');
    }
  }

  void _showManualReportInstructions(String subject, String body) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Manual Report Instructions',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please send an email with the following details:',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To: support@docln.net', style: textTheme.bodyMedium),
                  Text('Subject: $subject', style: textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Body:',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(body, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Copy to clipboard option could be added here
            },
            child: Text('OK', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $uri';
      }
    } catch (e) {
      CustomToast.show(context, 'Could not open URL: $e');
    }
  }

  void _toggleBookmark() {
    final bookmarkService = Provider.of<BookmarkServiceV2>(
      context,
      listen: false,
    );
    final isCurrentlyBookmarked = bookmarkService.isBookmarked(widget.novel.id);

    // Toggle the bookmark
    bookmarkService.toggleBookmark(widget.novel).then((_) {
      final isNowBookmarked = bookmarkService.isBookmarked(widget.novel.id);

      // Show toast
      CustomToast.show(
        context,
        isNowBookmarked
            ? '${widget.novel.title} added to bookmarks'
            : '${widget.novel.title} removed from bookmarks',
      );

      // If we just added a bookmark (not removed), show the animation
      if (isNowBookmarked && !isCurrentlyBookmarked) {
        _showBookmarkAnimation();
      }
    });
  }

  void _showBookmarkAnimation() {
    // Create the overlay for the animation
    final OverlayState overlayState = Overlay.of(context);
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                tween: Tween<double>(begin: 0.0, end: 1.0),
                onEnd: () {
                  // Remove the overlay after the animation completes
                  Future.delayed(const Duration(milliseconds: 200), () {
                    overlayEntry?.remove();
                  });
                },
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: 1.0 - (value * 0.5),
                      child: Icon(
                        Icons.bookmark,
                        size: 120,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.7),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    // Add the overlay to the screen
    overlayState.insert(overlayEntry);
  }
}

// Add this class at the top of the file, outside any other class
class BookmarkButton extends StatefulWidget {
  final LightNovel novel;
  final Color? activeColor;
  final double size;

  const BookmarkButton({
    Key? key,
    required this.novel,
    this.activeColor,
    this.size = 24.0,
  }) : super(key: key);

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeInBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleBookmark(BuildContext context, bool isBookmarked) {
    final bookmarkService = Provider.of<BookmarkServiceV2>(
      context,
      listen: false,
    );

    // Start animation
    if (!isBookmarked) {
      _controller.forward().then((_) => _controller.reverse());
    }

    // Toggle bookmark
    bookmarkService.toggleBookmark(widget.novel).then((_) {
      if (!mounted) return; // Fix crash if widget is disposed
      final newState = bookmarkService.isBookmarked(widget.novel.id);
      CustomToast.show(
        context,
        newState
            ? '${widget.novel.title} added to bookmarks'
            : '${widget.novel.title} removed from bookmarks',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;

    return Consumer<BookmarkServiceV2>(
      builder: (context, bookmarkService, child) {
        final isBookmarked = bookmarkService.isBookmarked(widget.novel.id);

        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isBookmarked ? _scaleAnimation.value : 1.0,
              child: IconButton(
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border_outlined,
                  color: isBookmarked ? activeColor : null,
                  size: widget.size,
                ),
                onPressed: () => _toggleBookmark(context, isBookmarked),
                tooltip: isBookmarked
                    ? 'Remove from bookmarks'
                    : 'Add to bookmarks',
              ),
            );
          },
        );
      },
    );
  }
}

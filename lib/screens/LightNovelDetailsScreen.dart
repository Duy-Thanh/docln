import 'package:flutter/material.dart';
import '../modules/light_novel.dart';
import './widgets/light_novel_card.dart';
import './widgets/chapter_card.dart';
import '../services/crawler_service.dart';
import '../screens/custom_toast.dart';
import '../screens/webview_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final CrawlerService _crawlerService = CrawlerService();
  bool _isLoading = true;
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

  @override
  void initState() {
    super.initState();
    _loadNovelDetails();
  }

  Future<void> _loadNovelDetails() async {
    try {
      setState(() => _isLoading = true);

      final novelDetails = await _crawlerService.getNovelDetails(
        widget.novelUrl,
        context,
      );

      if (mounted) {
        // Extract genres from the summary if none were found directly
        List<String> extractedGenres = [];
        String summary = novelDetails['summary'] ?? '';

        // Get novel type if available
        String novelType = novelDetails['novelType'] ?? 'Truyện dịch';

        // Attempt to extract genres from the summary text
        if ((novelDetails['genres'] as List<dynamic>?)?.isEmpty ?? true) {
          final genreKeywords = [
            'Drama',
            'Harem',
            'Romance',
            'Comedy',
            'School Life',
            'Fantasy',
            'Netorare',
            'Misunderstanding',
            'Action',
            'Adventure',
            'Slice of Life',
          ];

          for (var genre in genreKeywords) {
            if (summary.contains(genre)) {
              extractedGenres.add(genre);
            }
          }

          // Check if we can find genre words in specific patterns
          final regex = RegExp(
            r'(Drama|Harem|Romance|Comedy|School Life|Fantasy|Netorare|Misunderstanding|Action|Adventure|Slice of Life)',
          );
          final matches = regex.allMatches(summary);
          for (var match in matches) {
            final genre = match.group(0);
            if (genre != null && !extractedGenres.contains(genre)) {
              extractedGenres.add(genre);
            }
          }
        }

        // Extract chapters if they have empty URLs
        final List<Map<String, dynamic>> cleanedChapters = [];
        final chapters =
            (novelDetails['chapters'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        // Only use chapters with non-empty URLs
        for (var chapter in chapters) {
          if (chapter['url']?.isNotEmpty == true) {
            cleanedChapters.add(chapter);
          }
        }

        // Construct a cleaner description by removing junk
        String cleanDescription = summary;
        if (cleanDescription.contains('Truyện dịch')) {
          cleanDescription =
              cleanDescription.replaceAll('Truyện dịch', '').trim();
        }

        // Extract additional info like wordCount, views, etc.
        final List<String> altTitles =
            (novelDetails['alternativeTitles'] as List<dynamic>?)
                ?.cast<String>() ??
            [];
        final int? wordCount =
            novelDetails['wordCount'] ??
            _extractNumberFromString(summary, r'Số từ[:\s]*([0-9,.]+)');
        final int? views =
            novelDetails['views'] ??
            _extractNumberFromString(summary, r'Lượt xem[:\s]*([0-9,.]+)');
        final String? lastUpdated = novelDetails['lastUpdated'];

        setState(() {
          _genres =
              (novelDetails['genres'] as List<dynamic>?)?.cast<String>() ??
              extractedGenres;
          _description = cleanDescription;
          _chapters = cleanedChapters;
          _author = novelDetails['author'] ?? 'Unknown';
          _status = novelDetails['status'] ?? '';
          _alternativeTitles = altTitles;
          _wordCount = wordCount;
          _views = views;
          _lastUpdated = lastUpdated;
          _novelType = novelType;
          _isLoading = false;
        });

        // Debug information
        print('Novel details loaded:');
        print('Genres: $_genres');
        print('Author: $_author');
        print('Status: $_status');
        print('Novel Type: $_novelType');
        print('Description length: ${_description.length}');
        print('Chapters count: ${_chapters.length}');

        // Check if we got meaningful data
        if ((_description.isEmpty || _description.contains('\n\n\n\n')) &&
            _chapters.isEmpty &&
            _genres.isEmpty) {
          _handleEmptyData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _description = 'Error loading novel details';
          CustomToast.show(context, 'Error: ${e.toString()}');
        });
      }
    }
  }

  int? _extractNumberFromString(String text, String pattern) {
    final regex = RegExp(pattern);
    final match = regex.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return int.tryParse(match.group(1)!.replaceAll(RegExp(r'[,.]'), ''));
    }
    return null;
  }

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
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.novel.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
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
              label: const Text('Đọc trên web'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {
              // TODO: Implement add to library functionality
              CustomToast.show(context, 'Added to bookmarks');
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showMoreOptions(context);
            },
          ),
        ],
      ),
      body:
          _isLoading
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

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image with novel type label
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Hero(
                          tag: 'novel_${widget.novel.id}',
                          child: Image.network(
                            widget.novel.coverUrl,
                            width: 120,
                            height: 170,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120,
                                height: 170,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // Novel type label
                    if (_novelType.isNotEmpty)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
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
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.novel.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Author with icon
                      if (_author.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: colorScheme.primary.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _author,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 6),

                      // Status with icon
                      if (_status.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: colorScheme.primary.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _status,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 6),

                      // Latest chapter/volume
                      if (widget.novel.volumeTitle != null ||
                          widget.novel.latestChapter != null)
                        Row(
                          children: [
                            Icon(
                              Icons.bookmark_outline,
                              size: 16,
                              color: colorScheme.primary.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Latest: ${widget.novel.volumeTitle ?? widget.novel.latestChapter}',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                      if (widget.novel.rating != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Icon(
                                  index < (widget.novel.rating ?? 0) / 1
                                      ? Icons.star
                                      : index <
                                          (widget.novel.rating ?? 0) / 1 + 0.5
                                      ? Icons.star_half
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.novel.rating}/5',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.novel.reviews != null)
                                Text(
                                  ' (${widget.novel.reviews})',
                                  style: textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons in a separate card section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surfaceVariant : colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed:
                        _chapters.isEmpty && !_isLoading
                            ? () {
                              // If no chapters found, open in web view
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          WebViewScreen(url: widget.novelUrl),
                                ),
                              );
                            }
                            : _isLoading
                            ? null
                            : () {
                              // Navigate to the first chapter
                              if (_chapters.isNotEmpty) {
                                final chapterUrl = _chapters.first['url'] ?? '';
                                final fullChapterUrl = _getFullUrl(chapterUrl);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            WebViewScreen(url: fullChapterUrl),
                                  ),
                                );
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.book, size: 18),
                    label: const Text('Read Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      CustomToast.show(context, 'Notifications disabled');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.notifications_off, size: 18),
                    label: const Text('Thông báo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              '${widget.novel.rating ?? 'N/A'} / ${widget.novel.reviews ?? '0'}',
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
    final allTextContent = '''
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
                children:
                    _genres.map((genre) {
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
    String cleanedDesc =
        _description
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
    final int chapterCount =
        hasRealChapters
            ? _chapters.length
            : int.tryParse(
                  RegExp(
                        r'(\d+)\s+chương',
                      ).firstMatch(_description)?.group(1) ??
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
                        builder:
                            (context) => WebViewScreen(url: widget.novelUrl),
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
                      builder: (context) => WebViewScreen(url: chapterUrl),
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
                    separatorBuilder:
                        (context, index) => const Divider(height: 1),
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
                        subtitle:
                            hasDate
                                ? Text(
                                  chapter['date'] ?? '',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
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
                              builder:
                                  (context) => WebViewScreen(url: chapterUrl),
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
                leading: Icon(Icons.share, color: colorScheme.primary),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareNovel();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.open_in_browser,
                  color: colorScheme.primary,
                ),
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
                leading: Icon(
                  Icons.report_outlined,
                  color: colorScheme.primary,
                ),
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
      builder:
          (context) => AlertDialog(
            title: Text(
              'Report an Issue',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                  onTap:
                      () =>
                          _submitReport('Translation errors', widget.novelUrl),
                ),
                _buildReportOption(
                  icon: Icons.format_indent_decrease,
                  title: 'Formatting issues',
                  onTap:
                      () => _submitReport('Formatting issues', widget.novelUrl),
                ),
                _buildReportOption(
                  icon: Icons.error_outline,
                  title: 'Content errors',
                  onTap: () => _submitReport('Content errors', widget.novelUrl),
                ),
                _buildReportOption(
                  icon: Icons.security,
                  title: 'Inappropriate content',
                  onTap:
                      () => _submitReport(
                        'Inappropriate content',
                        widget.novelUrl,
                      ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colorScheme.primary),
                ),
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
      final simplifiedTitle =
          widget.novel.title.length > 30
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
      builder:
          (context) => AlertDialog(
            title: Text(
              'Manual Report Instructions',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                      Text(
                        'To: support@docln.net',
                        style: textTheme.bodyMedium,
                      ),
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
}

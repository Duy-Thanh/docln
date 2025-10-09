import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For compute()
import '../screens/custom_toast.dart';
import '../modules/light_novel.dart';
import '../services/history_service_v2.dart';
import '../services/crawler_service.dart';
import '../services/eye_protection_service.dart';
import '../widgets/eye_protection_overlay.dart';
import '../widgets/eye_friendly_text.dart';
import '../widgets/network_image.dart';
import '../screens/EyeCareScreen.dart';
import '../services/settings_services.dart';
import 'comments_screen.dart';
import '../services/preferences_service.dart';

// Define content block types
enum ContentBlockType { paragraph, header, image }

// Define content block class
class ContentBlock {
  final ContentBlockType type;
  final String content;
  final int startPosition;
  final String? altText;

  ContentBlock({
    required this.type,
    required this.content,
    required this.startPosition,
    this.altText,
  });
}

// PERFORMANCE OPTIMIZATION: Data class for passing to isolate
class _ParseParams {
  final String content;
  final double fontSize;
  final String fontFamily;
  final double lineHeight;
  final double paragraphSpacing;
  final Color textColor;

  _ParseParams({
    required this.content,
    required this.fontSize,
    required this.fontFamily,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.textColor,
  });
}

// PERFORMANCE OPTIMIZATION: Top-level function for isolate parsing
// This runs on a separate thread, keeping UI responsive
List<ContentBlock> _parseContentInIsolate(_ParseParams params) {
  final content = params.content;
  final List<ContentBlock> blocks = [];

  // Check if the content is HTML
  if (content.contains('<p>') ||
      content.contains('<h') ||
      content.contains('<img')) {
    // Pre-process content
    final processedContent = content.replaceAll(
      RegExp(r'<p\s+id\s*=\s*"[^"]*"'),
      '<p',
    );

    // Single-pass parsing
    int currentPos = 0;
    while (currentPos < processedContent.length) {
      final nextTagStart = processedContent.indexOf('<', currentPos);
      if (nextTagStart == -1) break;

      // Parse paragraphs
      if (processedContent.startsWith('<p', nextTagStart)) {
        final endTag = processedContent.indexOf('</p>', nextTagStart);
        if (endTag != -1) {
          final contentStart = processedContent.indexOf('>', nextTagStart) + 1;
          final paragraphContent = processedContent.substring(
            contentStart,
            endTag,
          );

          // Check if paragraph contains ONLY images (no text)
          final textContent = paragraphContent
              .replaceAll(RegExp(r'<img[^>]*>'), '')
              .trim();
          final hasOnlyImages = textContent.isEmpty;
          final imageMatches = RegExp(
            r'<img[^>]*>',
          ).allMatches(paragraphContent);

          if (hasOnlyImages && imageMatches.isNotEmpty) {
            // Parse each image in the paragraph as separate blocks
            for (final match in imageMatches) {
              final imgTag = match.group(0)!;
              final srcMatch = RegExp(
                r'src\s*=\s*["'
                "'"
                r']([^"'
                "'"
                r']+)["'
                "'"
                r']',
              ).firstMatch(imgTag);
              if (srcMatch != null) {
                final imageUrl = srcMatch.group(1)!;
                if (imageUrl.startsWith('http')) {
                  // Extract alt text
                  String? altText;
                  final altStart = imgTag.indexOf('alt=');
                  if (altStart != -1) {
                    final quoteStart = altStart + 4;
                    if (quoteStart < imgTag.length) {
                      final quote = imgTag[quoteStart];
                      if (quote == '"' || quote == "'") {
                        final quoteEnd = imgTag.indexOf(quote, quoteStart + 1);
                        if (quoteEnd != -1) {
                          altText = imgTag.substring(quoteStart + 1, quoteEnd);
                        }
                      }
                    }
                  }
                  blocks.add(
                    ContentBlock(
                      type: ContentBlockType.image,
                      content: imageUrl,
                      startPosition: nextTagStart + match.start,
                      altText: altText,
                    ),
                  );
                }
              }
            }
          } else {
            // Regular paragraph with text
            blocks.add(
              ContentBlock(
                type: ContentBlockType.paragraph,
                content: paragraphContent,
                startPosition: nextTagStart,
              ),
            );
          }
          currentPos = endTag + 4;
          continue;
        }
      }
      // Parse headers
      else if (processedContent.startsWith(RegExp(r'<h[1-6]'), nextTagStart)) {
        final endTagMatch = RegExp(
          r'</h[1-6]>',
        ).firstMatch(processedContent.substring(nextTagStart));
        if (endTagMatch != null) {
          final contentStart = processedContent.indexOf('>', nextTagStart) + 1;
          final endTagPos = nextTagStart + endTagMatch.start;
          final blockContent = processedContent.substring(
            contentStart,
            endTagPos,
          );
          blocks.add(
            ContentBlock(
              type: ContentBlockType.header,
              content: blockContent,
              startPosition: nextTagStart,
            ),
          );
          currentPos = nextTagStart + endTagMatch.end;
          continue;
        }
      }
      // Parse images
      else if (processedContent.startsWith('<img', nextTagStart)) {
        final imgTagEnd = processedContent.indexOf('>', nextTagStart);
        if (imgTagEnd != -1) {
          final imgTag = processedContent.substring(
            nextTagStart,
            imgTagEnd + 1,
          );
          final srcMatch = RegExp(
            r'src\s*=\s*["'
            "'"
            r']([^"'
            "'"
            r']+)["'
            "'"
            r']',
          ).firstMatch(imgTag);
          if (srcMatch != null) {
            final imageUrl = srcMatch.group(1)!;
            if (imageUrl.startsWith('http')) {
              // Extract alt text
              String? altText;
              final altStart = imgTag.indexOf('alt=');
              if (altStart != -1) {
                final quoteStart = altStart + 4;
                if (quoteStart < imgTag.length) {
                  final quote = imgTag[quoteStart];
                  if (quote == '"' || quote == "'") {
                    final quoteEnd = imgTag.indexOf(quote, quoteStart + 1);
                    if (quoteEnd != -1) {
                      altText = imgTag.substring(quoteStart + 1, quoteEnd);
                    }
                  }
                }
              }
              blocks.add(
                ContentBlock(
                  type: ContentBlockType.image,
                  content: imageUrl,
                  startPosition: nextTagStart,
                  altText: altText,
                ),
              );
            }
          }
          currentPos = imgTagEnd + 1;
          continue;
        }
      }

      currentPos = nextTagStart + 1;
    }
  } else {
    // Plain text parsing
    final paragraphs = content.split('\n\n');
    int position = 0;
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        position += paragraph.length + 2;
        continue;
      }

      if (paragraph.trim().startsWith('#')) {
        blocks.add(
          ContentBlock(
            type: ContentBlockType.header,
            content: paragraph.trim().substring(1).trim(),
            startPosition: position,
          ),
        );
      } else {
        blocks.add(
          ContentBlock(
            type: ContentBlockType.paragraph,
            content: paragraph.trim(),
            startPosition: position,
          ),
        );
      }
      position += paragraph.length + 2;
    }
  }

  return blocks;
}

class ReaderScreen extends StatefulWidget {
  final String url;
  final String title;
  final LightNovel? novel;
  final String? chapterTitle;

  const ReaderScreen({
    Key? key,
    required this.url,
    required this.title,
    this.novel,
    this.chapterTitle,
  }) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String _content = '';
  double _fontSize = 18.0;
  String _fontFamily = 'Roboto';
  double _lineHeight = 1.8;
  Color _textColor = Colors.black;
  Color _backgroundColor = Colors.white;
  bool _isDarkMode = false;
  double _paragraphSpacing = 1.5;
  bool _showControls = true;

  // PERFORMANCE OPTIMIZATION: Cache parsed content
  List<Widget>? _cachedContentWidgets;
  List<ContentBlock>?
  _parsedContentBlocks; // Store pre-parsed blocks from isolate
  String? _lastParsedContent;
  double? _lastFontSize;
  double? _lastLineHeight;
  double? _lastParagraphSpacing;

  // Reading progress
  double _readingProgress = 0.0;
  final ScrollController _scrollController = ScrollController();

  // Text selection
  bool _enableTextSelection = true;

  // Chapter navigation
  bool _hasNextChapter = false;
  bool _hasPreviousChapter = false;
  String? _nextChapterUrl;
  String? _prevChapterUrl;
  String? _nextChapterTitle;
  String? _prevChapterTitle;

  // Screen brightness
  double _screenBrightness = 1.0;

  // Eye protection
  late EyeProtectionService _eyeProtectionService;
  DateTime _readingStartTime = DateTime.now();

  final CrawlerService _crawlerService = CrawlerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eyeProtectionService = EyeProtectionService();
    _eyeProtectionService.initSettings();
    _loadSettings();
    _fetchContent();
    _fetchAdjacentChapters();

    // Add scroll listener for reading progress
    _scrollController.addListener(_updateReadingProgress);

    // Schedule adding to history after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addToHistory();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is in background, save reading progress
      _saveReadingProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_updateReadingProgress);
    _scrollController.dispose();
    // Save reading progress when leaving
    _saveReadingProgress();
    // Reset system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Reset scroll position when the screen is first loaded
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _fetchAdjacentChapters() async {
    if (widget.novel == null) return;

    try {
      final novelDetails = await _crawlerService.getNovelDetails(
        widget.novel!.url,
        context,
      );

      if (mounted) {
        final List<Map<String, dynamic>> chapters =
            (novelDetails['chapters'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        if (chapters.isNotEmpty) {
          // Find current chapter index
          int currentIndex = -1;
          for (int i = 0; i < chapters.length; i++) {
            if (chapters[i]['title'] == widget.chapterTitle) {
              currentIndex = i;
              break;
            }
          }

          if (currentIndex != -1) {
            // Check if has next chapter
            if (currentIndex < chapters.length - 1) {
              setState(() {
                _hasNextChapter = true;
                final nextChapter = chapters[currentIndex + 1];
                _nextChapterUrl = nextChapter['url'] ?? '';
                _nextChapterTitle = nextChapter['title'] ?? 'Next Chapter';
              });
            }

            // Check if has previous chapter
            if (currentIndex > 0) {
              setState(() {
                _hasPreviousChapter = true;
                final prevChapter = chapters[currentIndex - 1];
                _prevChapterUrl = prevChapter['url'] ?? '';
                _prevChapterTitle = prevChapter['title'] ?? 'Previous Chapter';
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching adjacent chapters: $e');
    }
  }

  void _navigateToChapter(String? url, String? title) {
    if (url == null || url.isEmpty) return;

    // Make sure url is absolute
    String fullUrl = url;
    if (!url.startsWith('http')) {
      final Uri uri = Uri.parse(widget.url);
      final String baseUrl = '${uri.scheme}://${uri.host}';
      fullUrl = url.startsWith('/') ? '$baseUrl$url' : '$baseUrl/$url';
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          url: fullUrl,
          title: widget.title,
          novel: widget.novel,
          chapterTitle: title,
        ),
      ),
    );
  }

  void _updateReadingProgress() {
    if (_scrollController.positions.isNotEmpty &&
        _scrollController.position.maxScrollExtent > 0) {
      final currentPos = _scrollController.offset;
      final maxPos = _scrollController.position.maxScrollExtent;
      final progress = (currentPos / maxPos).clamp(0.0, 1.0);

      setState(() {
        _readingProgress = progress;
      });

      // Auto-load next chapter when near the end
      if (progress > 0.9 && _hasNextChapter && _nextChapterUrl != null) {
        // Pre-fetch next chapter for faster loading
        _prefetchNextChapter();
      }
    }
  }

  Future<void> _prefetchNextChapter() async {
    // This method could be implemented to preload the next chapter
    // for a smoother transition between chapters
  }

  Future<void> _saveReadingProgress() async {
    if (widget.novel == null || widget.chapterTitle == null) return;

    try {
      final prefsService = PreferencesService();
      await prefsService.initialize();

      final key = 'progress_${widget.novel!.id}_${widget.chapterTitle}';
      await prefsService.setDouble(key, _readingProgress);
    } catch (e) {
      print('Error saving reading progress: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefsService = PreferencesService();
      await prefsService.initialize();

      // Load font settings
      setState(() {
        _fontSize = prefsService.getDouble(
          'reader_font_size',
          defaultValue: 18.0,
        );
        _fontFamily = prefsService.getString(
          'reader_font_family',
          defaultValue: 'Roboto',
        );
        _lineHeight = prefsService.getDouble(
          'reader_line_height',
          defaultValue: 1.8,
        );
        _paragraphSpacing = prefsService.getDouble(
          'reader_paragraph_spacing',
          defaultValue: 1.5,
        );
        _isDarkMode = prefsService.getBool('darkMode');
        _enableTextSelection = prefsService.getBool(
          'reader_text_selection',
          defaultValue: true,
        );
        _screenBrightness = prefsService.getDouble(
          'reader_brightness',
          defaultValue: 1.0,
        );

        // Apply adaptive brightness from eye protection service if enabled
        if (_eyeProtectionService.adaptiveBrightnessEnabled) {
          _screenBrightness = _eyeProtectionService.getAdaptiveBrightness(
            _screenBrightness,
            DateTime.now(),
          );
        }

        // Set colors based on theme
        if (_isDarkMode) {
          final textColorStr = prefsService.getString('reader_text_color_dark');
          _textColor = textColorStr.isNotEmpty
              ? Color(int.parse(textColorStr))
              : Colors.white.withOpacity(0.9);

          final bgColorStr = prefsService.getString(
            'reader_background_color_dark',
          );
          _backgroundColor = bgColorStr.isNotEmpty
              ? Color(int.parse(bgColorStr))
              : const Color(0xFF121212);
        } else {
          final textColorStr = prefsService.getString(
            'reader_text_color_light',
          );
          _textColor = textColorStr.isNotEmpty
              ? Color(int.parse(textColorStr))
              : Colors.black.withOpacity(0.9);

          final bgColorStr = prefsService.getString(
            'reader_background_color_light',
          );
          _backgroundColor = bgColorStr.isNotEmpty
              ? Color(int.parse(bgColorStr))
              : Colors.white;
        }

        // Apply eye protection to colors if enabled
        if (_eyeProtectionService.eyeProtectionEnabled) {
          _textColor = _eyeProtectionService.applyEyeProtection(_textColor);
          // Don't apply to background as we use overlay instead
        }
      });

      // Load reading progress if available
      if (widget.novel != null && widget.chapterTitle != null) {
        final key = 'progress_${widget.novel!.id}_${widget.chapterTitle}';
        final savedProgress = prefsService.getDouble(key);
        if (savedProgress > 0) {
          setState(() {
            _readingProgress = savedProgress;
          });
        }
      }
    } catch (e) {
      print('Error loading reader settings: $e');
    }
  }

  Future<void> _fetchContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 Starting content fetch...');
      final fetchStopwatch = Stopwatch()..start();

      // Fetch real content from the crawler service
      final chapterData = await _crawlerService.getChapterContent(
        widget.url,
        context,
      );

      fetchStopwatch.stop();
      debugPrint(
        '📥 Content fetched in ${fetchStopwatch.elapsedMilliseconds}ms',
      );

      if (!mounted) return;

      final rawContent = chapterData['content'] ?? '';

      // CRITICAL PERFORMANCE FIX: Parse content in background isolate
      // This keeps the UI thread responsive during heavy parsing
      debugPrint(
        '🔄 Starting async content parsing (${rawContent.length} chars)...',
      );
      final parseStopwatch = Stopwatch()..start();

      final parseParams = _ParseParams(
        content: rawContent,
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        lineHeight: _lineHeight,
        paragraphSpacing: _paragraphSpacing,
        textColor: _textColor,
      );

      // Parse in separate isolate - UI stays responsive!
      final contentBlocks = await compute(_parseContentInIsolate, parseParams);

      parseStopwatch.stop();
      debugPrint(
        '✅ Content parsed in ${parseStopwatch.elapsedMilliseconds}ms (${contentBlocks.length} blocks)',
      );

      // DEBUG: Check for images
      final imageBlocks = contentBlocks
          .where((b) => b.type == ContentBlockType.image)
          .length;
      debugPrint('🖼️ Found $imageBlocks image blocks');
      if (imageBlocks > 0) {
        final firstImage = contentBlocks.firstWhere(
          (b) => b.type == ContentBlockType.image,
        );
        debugPrint('🖼️ First image URL: ${firstImage.content}');
      }

      if (!mounted) return;

      // Now update state with parsed data
      setState(() {
        _content = rawContent;

        // Store parsed blocks for widget building
        _parsedContentBlocks = contentBlocks;

        // PERFORMANCE OPTIMIZATION: Invalidate cache when content changes
        _cachedContentWidgets = null;
        // Keep _lastParsedContent synchronized so isolate blocks are used
        _lastParsedContent = rawContent;

        // Update chapter navigation info
        if (!_hasNextChapter &&
            chapterData['nextChapterUrl'] != null &&
            chapterData['nextChapterUrl'].isNotEmpty) {
          _hasNextChapter = true;
          _nextChapterUrl = chapterData['nextChapterUrl'];
          _nextChapterTitle = chapterData['nextChapterTitle'] ?? 'Next Chapter';
        }

        if (!_hasPreviousChapter &&
            chapterData['prevChapterUrl'] != null &&
            chapterData['prevChapterUrl'].isNotEmpty) {
          _hasPreviousChapter = true;
          _prevChapterUrl = chapterData['prevChapterUrl'];
          _prevChapterTitle =
              chapterData['prevChapterTitle'] ?? 'Previous Chapter';
        }

        _isLoading = false;
      });

      debugPrint(
        '🎉 Total load time: ${fetchStopwatch.elapsedMilliseconds + parseStopwatch.elapsedMilliseconds}ms',
      );

      // Reset scroll position after content is loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    } catch (e) {
      debugPrint('❌ Error loading content: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _content = '<p>Error loading content: $e</p>';
        });
        CustomToast.show(context, 'Error loading chapter: $e');
      }
    }
  }

  void _addToHistory() {
    if (!mounted || widget.novel == null) return;

    try {
      final historyService = Provider.of<HistoryServiceV2>(
        context,
        listen: false,
      );

      historyService.addToHistory(widget.novel!, widget.chapterTitle);
    } catch (e) {
      print('Error adding to history: $e');
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;

      // Update colors based on theme
      if (_isDarkMode) {
        _textColor = Colors.white.withOpacity(0.9);
        _backgroundColor = const Color(0xFF121212);
      } else {
        _textColor = Colors.black.withOpacity(0.9);
        _backgroundColor = Colors.white;
      }
    });

    // Save the theme preference
    PreferencesService().setBool('darkMode', _isDarkMode);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _adjustBrightness(double value) {
    setState(() {
      _screenBrightness = value;
    });

    PreferencesService().setDouble('reader_brightness', value);
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reading Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Font size slider
                    Row(
                      children: [
                        const Text('A', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 12.0,
                            max: 24.0,
                            divisions: 12,
                            label: _fontSize.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                _fontSize = value;
                              });
                            },
                            onChangeEnd: (value) async {
                              await PreferencesService().setDouble(
                                'reader_font_size',
                                value,
                              );
                            },
                          ),
                        ),
                        const Text('A', style: TextStyle(fontSize: 22)),
                      ],
                    ),

                    // Line height slider
                    Row(
                      children: [
                        Icon(Icons.format_line_spacing, size: 20),
                        const SizedBox(width: 8),
                        const Text('Line Height'),
                        Expanded(
                          child: Slider(
                            value: _lineHeight,
                            min: 1.2,
                            max: 2.4,
                            divisions: 12,
                            label: _lineHeight.toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() {
                                _lineHeight = value;
                              });
                            },
                            onChangeEnd: (value) async {
                              await PreferencesService().setDouble(
                                'reader_line_height',
                                value,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // Paragraph spacing slider
                    Row(
                      children: [
                        Icon(Icons.space_bar, size: 20),
                        const SizedBox(width: 8),
                        const Text('Paragraph Spacing'),
                        Expanded(
                          child: Slider(
                            value: _paragraphSpacing,
                            min: 1.0,
                            max: 3.0,
                            divisions: 10,
                            label: _paragraphSpacing.toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() {
                                _paragraphSpacing = value;
                              });
                            },
                            onChangeEnd: (value) async {
                              await PreferencesService().setDouble(
                                'reader_paragraph_spacing',
                                value,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // Blue light filter slider
                    Row(
                      children: [
                        Icon(Icons.nights_stay, size: 20),
                        const SizedBox(width: 8),
                        const Text('Blue Light Filter'),
                        Expanded(
                          child: Slider(
                            value: _eyeProtectionService.blueFilterLevel,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            label:
                                (_eyeProtectionService.blueFilterLevel * 100)
                                    .round()
                                    .toString() +
                                '%',
                            onChanged: (value) async {
                              // Update immediately for preview
                              await _eyeProtectionService.setBlueFilterLevel(
                                value,
                              );
                              // Refresh state to show changes
                              setState(() {});
                              this.setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),

                    // Color temperature (warmth) slider
                    Row(
                      children: [
                        Icon(Icons.wb_sunny, size: 20),
                        const SizedBox(width: 8),
                        const Text('Warmth'),
                        Expanded(
                          child: Slider(
                            value: _eyeProtectionService.warmthLevel,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            label:
                                (_eyeProtectionService.warmthLevel * 100)
                                    .round()
                                    .toString() +
                                '%',
                            onChanged: (value) async {
                              // Update immediately for preview
                              await _eyeProtectionService.setWarmthLevel(value);
                              // Refresh state to show changes
                              setState(() {});
                              this.setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),

                    // Screen brightness slider
                    Row(
                      children: [
                        Icon(Icons.brightness_medium, size: 20),
                        const SizedBox(width: 8),
                        const Text('Brightness'),
                        Expanded(
                          child: Slider(
                            value: _screenBrightness,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            label:
                                (_screenBrightness * 100).round().toString() +
                                '%',
                            onChanged: (value) {
                              setState(() {
                                _screenBrightness = value;
                              });

                              this.setState(() {
                                _screenBrightness = value;
                              });
                            },
                            onChangeEnd: (value) async {
                              await PreferencesService().setDouble(
                                'reader_brightness',
                                value,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // Theme toggle
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      value: _isDarkMode,
                      onChanged: (value) {
                        setState(() {
                          _isDarkMode = value;
                        });
                        this.setState(() {
                          if (_isDarkMode) {
                            _textColor = Colors.white.withOpacity(0.9);
                            _backgroundColor = const Color(0xFF121212);
                          } else {
                            _textColor = Colors.black.withOpacity(0.9);
                            _backgroundColor = Colors.white;
                          }

                          // Apply eye protection if enabled
                          if (_eyeProtectionService.eyeProtectionEnabled) {
                            _textColor = _eyeProtectionService
                                .applyEyeProtection(_textColor);
                          }
                        });

                        // Save the setting
                        PreferencesService().setBool('darkMode', value);
                      },
                    ),

                    // Eye protection toggle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.grey.shade800.withOpacity(0.3)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'eyeCARE™',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Commercial and monopoly eye-protection method developed by us to protect your eyes',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value:
                                    _eyeProtectionService.eyeProtectionEnabled,
                                onChanged: (value) async {
                                  // Update service
                                  await _eyeProtectionService
                                      .setEyeProtectionEnabled(value);
                                  // Refresh both state builders
                                  setState(() {});
                                  this.setState(() {
                                    // Re-apply protection to text color
                                    if (_eyeProtectionService
                                        .eyeProtectionEnabled) {
                                      _textColor = _eyeProtectionService
                                          .applyEyeProtection(_textColor);
                                    } else {
                                      // Reset to original colors based on theme
                                      if (_isDarkMode) {
                                        _textColor = Colors.white.withOpacity(
                                          0.9,
                                        );
                                      } else {
                                        _textColor = Colors.black.withOpacity(
                                          0.9,
                                        );
                                      }
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const EyeCareScreen(),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.help_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            label: Text(
                              'Learn more about eyeCARE™',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Adaptive brightness toggle
                    SwitchListTile(
                      title: const Text('Adaptive Brightness'),
                      subtitle: const Text(
                        'Adjust brightness based on time of day',
                      ),
                      value: _eyeProtectionService.adaptiveBrightnessEnabled,
                      onChanged: (value) async {
                        // Update service
                        await _eyeProtectionService
                            .setAdaptiveBrightnessEnabled(value);
                        // Refresh state
                        setState(() {});
                        this.setState(() {
                          // Apply adaptive brightness if enabled
                          if (_eyeProtectionService.adaptiveBrightnessEnabled) {
                            _screenBrightness = _eyeProtectionService
                                .getAdaptiveBrightness(
                                  _screenBrightness,
                                  DateTime.now(),
                                );
                          }
                        });
                      },
                    ),

                    // Reading timer toggle and settings
                    SwitchListTile(
                      title: const Text('Break Reminders'),
                      subtitle: const Text(
                        'Reminds you to rest your eyes periodically',
                      ),
                      value: _eyeProtectionService.periodicalReminderEnabled,
                      onChanged: (value) async {
                        await _eyeProtectionService
                            .setPeriodicalReminderEnabled(value);
                        setState(() {});
                      },
                    ),

                    // Only show interval setting if reminders are enabled
                    if (_eyeProtectionService.periodicalReminderEnabled)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                        ),
                        child: Row(
                          children: [
                            const Text('Reminder interval: '),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _eyeProtectionService.readingTimerInterval,
                              items: [5, 10, 15, 20, 25, 30, 45, 60].map((
                                int value,
                              ) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value minutes'),
                                );
                              }).toList(),
                              onChanged: (int? newValue) async {
                                if (newValue != null) {
                                  await _eyeProtectionService
                                      .setReadingTimerInterval(newValue);
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                    // Text selection toggle
                    SwitchListTile(
                      title: const Text('Enable Text Selection'),
                      value: _enableTextSelection,
                      onChanged: (value) {
                        setState(() {
                          _enableTextSelection = value;
                        });

                        this.setState(() {
                          _enableTextSelection = value;
                        });

                        // Save the setting
                        PreferencesService().setBool(
                          'reader_text_selection',
                          value,
                        );
                      },
                    ),

                    // Show information about eye protection features
                    if (_eyeProtectionService.eyeProtectionEnabled)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Eye Protection Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Our eye protection technology includes:',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              _buildEyeProtectionInfoItem(
                                '• Blue light filtering to reduce eye strain',
                                'Reduces harmful blue light wavelengths',
                              ),
                              _buildEyeProtectionInfoItem(
                                '• Optimal contrast adjustment',
                                'Prevents excessive contrast that causes eye fatigue',
                              ),
                              _buildEyeProtectionInfoItem(
                                '• Color temperature warming',
                                'Creates a paper-like reading experience',
                              ),
                              _buildEyeProtectionInfoItem(
                                '• 20-20-20 break reminders',
                                'Look away every 20 minutes at something 20 feet away for 20 seconds',
                              ),
                              _buildEyeProtectionInfoItem(
                                '• Time-based brightness adjustment',
                                'Automatically reduces screen brightness at night',
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(
            color: _textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.comment),
            onPressed: _openComments,
            tooltip: 'View comments',
          ),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.remove_red_eye),
            onPressed: () => _showSettingsPanel(),
            tooltip: 'Eye protection settings',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsPanel,
            tooltip: 'Reader settings',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: EyeProtectionOverlay(
          readingStartTime: _readingStartTime,
          showControls: _showControls,
          child: Stack(
            children: [
              // Screen brightness overlay
              IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(1.0 - _screenBrightness),
                ),
              ),

              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : GestureDetector(
                      onHorizontalDragEnd: (details) {
                        // Swipe right to go to previous chapter
                        if (details.primaryVelocity! > 300 &&
                            _hasPreviousChapter) {
                          _navigateToChapter(
                            _prevChapterUrl,
                            _prevChapterTitle,
                          );
                        }
                        // Swipe left to go to next chapter
                        else if (details.primaryVelocity! < -300 &&
                            _hasNextChapter) {
                          _navigateToChapter(
                            _nextChapterUrl,
                            _nextChapterTitle,
                          );
                        }
                      },
                      child: Stack(
                        children: [
                          // Main content - OPTIMIZED: Use ListView.builder for large chapters
                          SelectionArea(
                            selectionControls: _enableTextSelection
                                ? MaterialTextSelectionControls()
                                : null,
                            child: _buildOptimizedContentView(),
                          ),

                          // Reading progress indicator
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              width: double.infinity,
                              height: 4,
                              color: Colors.grey.withOpacity(0.3),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _readingProgress,
                                child: Container(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
      // Navigation buttons - always visible now
      bottomNavigationBar: _isLoading
          ? null
          : BottomAppBar(
              color: _backgroundColor,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous chapter button
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: _hasPreviousChapter
                            ? _textColor
                            : _textColor.withOpacity(0.3),
                      ),
                      onPressed: _hasPreviousChapter
                          ? () => _navigateToChapter(
                              _prevChapterUrl,
                              _prevChapterTitle,
                            )
                          : null,
                      tooltip: _hasPreviousChapter
                          ? 'Previous Chapter: $_prevChapterTitle'
                          : 'No Previous Chapter',
                    ),

                    // Chapter indicator
                    if (widget.chapterTitle != null)
                      Expanded(
                        child: Text(
                          widget.chapterTitle!,
                          style: TextStyle(color: _textColor, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Next chapter button
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: _hasNextChapter
                            ? _textColor
                            : _textColor.withOpacity(0.3),
                      ),
                      onPressed: _hasNextChapter
                          ? () => _navigateToChapter(
                              _nextChapterUrl,
                              _nextChapterTitle,
                            )
                          : null,
                      tooltip: _hasNextChapter
                          ? 'Next Chapter: $_nextChapterTitle'
                          : 'No Next Chapter',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // PERFORMANCE OPTIMIZATION: Build optimized content view with lazy loading
  Widget _buildOptimizedContentView() {
    final contentWidgets = _parseContent();

    // For small chapters (<50 widgets), use SingleChildScrollView (faster)
    if (contentWidgets.length < 50) {
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentWidgets,
        ),
      );
    }

    // For large chapters (>=50 widgets), use ListView.builder for lazy loading
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: contentWidgets.length,
      // CRITICAL: addAutomaticKeepAlives and addRepaintBoundaries improve performance
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 1000, // Cache 1000 pixels ahead
      itemBuilder: (context, index) {
        // Wrap each item in RepaintBoundary for better performance
        return RepaintBoundary(child: contentWidgets[index]);
      },
    );
  }

  List<Widget> _parseContent() {
    // PERFORMANCE OPTIMIZATION: Check cache first
    final settingsChanged =
        _lastFontSize != _fontSize ||
        _lastLineHeight != _lineHeight ||
        _lastParagraphSpacing != _paragraphSpacing;

    if (_cachedContentWidgets != null &&
        _lastParsedContent == _content &&
        !settingsChanged) {
      return _cachedContentWidgets!;
    }

    // CRITICAL PERFORMANCE FIX: Use pre-parsed blocks from isolate
    // This skips the expensive parsing on UI thread
    final List<ContentBlock> contentBlocks;

    if (_parsedContentBlocks != null && _lastParsedContent == _content) {
      // Use blocks from isolate parsing
      contentBlocks = _parsedContentBlocks!;

      // DEBUG: Check image blocks in widget building
      final imageCount = contentBlocks
          .where((b) => b.type == ContentBlockType.image)
          .length;
      debugPrint(
        '🎨 Building widgets with $imageCount images from ${contentBlocks.length} blocks',
      );
    } else {
      // Fallback to synchronous parsing (should rarely happen)
      final stopwatch = Stopwatch()..start();

      if (_content.contains('<p>') ||
          _content.contains('<h') ||
          _content.contains('<img')) {
        final processedContent = _content.replaceAll(
          RegExp(r'<p\s+id\s*=\s*"[^"]*"'),
          '<p',
        );
        contentBlocks = _parseContentBlocksOptimized(processedContent);
      } else {
        contentBlocks = _parseContentBlocksOptimized(_content);
      }

      stopwatch.stop();
    }

    // Now build widgets from blocks (this is fast)
    final stopwatch = Stopwatch()..start();
    final List<Widget> widgets = [];

    // Process the blocks in order
    for (var block in contentBlocks) {
      switch (block.type) {
        case ContentBlockType.paragraph:
          final paragraphText = _stripHtmlTagsFast(block.content);
          // Skip empty paragraphs
          if (paragraphText.isEmpty ||
              RegExp(r'^\s*\$\d+\s*$').hasMatch(paragraphText)) {
            continue;
          }

          widgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: 16 * _paragraphSpacing),
              child: Text(
                paragraphText,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: _textColor,
                  fontFamily: _fontFamily,
                  height: _lineHeight,
                ),
              ),
            ),
          );
          break;

        case ContentBlockType.header:
          final headerText = _stripHtmlTagsFast(block.content);
          if (headerText.isNotEmpty) {
            widgets.add(
              Padding(
                padding: EdgeInsets.only(bottom: 16 * _paragraphSpacing),
                child: Text(
                  headerText,
                  style: TextStyle(
                    fontSize: _fontSize + 4,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                    fontFamily: _fontFamily,
                    height: _lineHeight,
                  ),
                ),
              ),
            );
          }
          break;

        case ContentBlockType.image:
          widgets.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Column(
                  children: [
                    _buildImageWidget(block.content),
                    if (block.altText != null && block.altText!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          block.altText!,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: _fontSize - 2,
                            color: _textColor.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          break;
      }
    }

    // Cache the result
    _cachedContentWidgets = widgets;
    _lastParsedContent = _content;
    _lastFontSize = _fontSize;
    _lastLineHeight = _lineHeight;
    _lastParagraphSpacing = _paragraphSpacing;

    stopwatch.stop();

    return widgets;
  }

  // PERFORMANCE OPTIMIZATION: Single-pass optimized content block parsing
  List<ContentBlock> _parseContentBlocksOptimized(String html) {
    final List<ContentBlock> blocks = [];
    int currentPos = 0;

    // Use a more efficient parsing strategy for large content
    while (currentPos < html.length) {
      // Find next tag
      final nextTagStart = html.indexOf('<', currentPos);
      if (nextTagStart == -1) break;

      // Determine tag type
      if (html.startsWith('<p', nextTagStart)) {
        final endTag = html.indexOf('</p>', nextTagStart);
        if (endTag != -1) {
          final contentStart = html.indexOf('>', nextTagStart) + 1;
          final content = html.substring(contentStart, endTag);
          blocks.add(
            ContentBlock(
              type: ContentBlockType.paragraph,
              content: content,
              startPosition: nextTagStart,
            ),
          );
          currentPos = endTag + 4; // Skip </p>
          continue;
        }
      } else if (html.startsWith(RegExp(r'<h[1-6]'), nextTagStart)) {
        final endTagMatch = RegExp(
          r'</h[1-6]>',
        ).firstMatch(html.substring(nextTagStart));
        if (endTagMatch != null) {
          final contentStart = html.indexOf('>', nextTagStart) + 1;
          final endTagPos = nextTagStart + endTagMatch.start;
          final content = html.substring(contentStart, endTagPos);
          blocks.add(
            ContentBlock(
              type: ContentBlockType.header,
              content: content,
              startPosition: nextTagStart,
            ),
          );
          currentPos = nextTagStart + endTagMatch.end;
          continue;
        }
      } else if (html.startsWith('<img', nextTagStart)) {
        final imgTagEnd = html.indexOf('>', nextTagStart);
        if (imgTagEnd != -1) {
          final imgTag = html.substring(nextTagStart, imgTagEnd + 1);
          final srcMatch = RegExp(
            r'src\s*=\s*["'
            "'"
            r']([^"'
            "'"
            r']+)["'
            "'"
            r']',
          ).firstMatch(imgTag);
          if (srcMatch != null) {
            final imageUrl = srcMatch.group(1)!;
            if (imageUrl.startsWith('http')) {
              blocks.add(
                ContentBlock(
                  type: ContentBlockType.image,
                  content: imageUrl,
                  startPosition: nextTagStart,
                  altText: _extractAltTextFast(imgTag),
                ),
              );
            }
          }
          currentPos = imgTagEnd + 1;
          continue;
        }
      }

      currentPos = nextTagStart + 1;
    }

    return blocks;
  }

  // PERFORMANCE OPTIMIZATION: Faster HTML tag stripping
  String _stripHtmlTagsFast(String htmlString) {
    if (htmlString.isEmpty) return '';

    // Single-pass tag removal
    final buffer = StringBuffer();
    bool inTag = false;

    for (int i = 0; i < htmlString.length; i++) {
      final char = htmlString[i];
      if (char == '<') {
        inTag = true;
      } else if (char == '>') {
        inTag = false;
      } else if (!inTag) {
        buffer.write(char);
      }
    }

    // Convert HTML entities in single pass
    String result = buffer
        .toString()
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    return result.trim();
  }

  // PERFORMANCE OPTIMIZATION: Faster alt text extraction
  String? _extractAltTextFast(String imgTag) {
    final altStart = imgTag.indexOf('alt=');
    if (altStart == -1) return null;

    final quoteStart = altStart + 4;
    if (quoteStart >= imgTag.length) return null;

    final quote = imgTag[quoteStart];
    if (quote != '"' && quote != "'") return null;

    final quoteEnd = imgTag.indexOf(quote, quoteStart + 1);
    if (quoteEnd == -1) return null;

    return imgTag.substring(quoteStart + 1, quoteEnd);
  }

  // Method to fix image URLs before loading
  String _fixImageUrl(String url) {
    // First check if the URL is from a known problematic domain
    final domainPatterns = {
      'i.docln.net': 'i.hako.vn',
      'i2.docln.net': 'i.hako.vn',
      'i3.docln.net': 'i.hako.vn',
    };

    // Check for each problematic domain
    for (final entry in domainPatterns.entries) {
      if (url.contains(entry.key)) {
        return url.replaceFirst(entry.key, entry.value);
      }
    }

    // Use the crawler service's fixImageUrl if available
    try {
      return _crawlerService.fixImageUrl(url);
    } catch (e) {
      print('Error fixing image URL: $e');
      return url;
    }
  }

  // Custom image widget that handles redirects and fallbacks
  Widget _buildImageWidget(String imageUrl) {
    final fixedUrl = _fixImageUrl(imageUrl);

    return OptimizedNetworkImage(
      imageUrl: fixedUrl,
      fit: BoxFit.contain,
      errorWidget: (context, url, error) {
        print('Error loading image: $error for URL $fixedUrl');

        // If the fixed URL failed, try a direct alternative domain
        if (fixedUrl != imageUrl && !fixedUrl.contains('i.hako.vn')) {
          print('Trying alternative domain for image');
          final altUrl = imageUrl.replaceAll(
            RegExp(r'i[0-9]?\.docln\.net'),
            'i.hako.vn',
          );

          return OptimizedNetworkImage(
            imageUrl: altUrl,
            fit: BoxFit.contain,
            errorWidget: (context, url, error) {
              print('Error loading alternative image: $error');
              return Column(
                children: [
                  Icon(Icons.broken_image, color: Colors.red),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.red),
                  ),
                  Text(
                    '(Tap to retry)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              );
            },
          );
        }

        return Column(
          children: [
            Icon(Icons.broken_image, color: Colors.red),
            Text('Failed to load image', style: TextStyle(color: Colors.red)),
          ],
        );
      },
      placeholder: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEyeProtectionInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(description, style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          url: widget.url,
          title: widget.chapterTitle ?? widget.title,
        ),
      ),
    );
  }
}

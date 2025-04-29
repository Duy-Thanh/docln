import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/theme_services.dart';
import '../screens/custom_toast.dart';
import '../modules/light_novel.dart';
import '../screens/HistoryScreen.dart';
import '../services/crawler_service.dart';

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

  final CrawlerService _crawlerService = CrawlerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        builder:
            (context) => ReaderScreen(
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
      final prefs = await SharedPreferences.getInstance();
      final key = 'progress_${widget.novel!.id}_${widget.chapterTitle}';
      await prefs.setDouble(key, _readingProgress);
    } catch (e) {
      print('Error saving reading progress: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load font settings
      setState(() {
        _fontSize = prefs.getDouble('reader_font_size') ?? 18.0;
        _fontFamily = prefs.getString('reader_font_family') ?? 'Roboto';
        _lineHeight = prefs.getDouble('reader_line_height') ?? 1.8;
        _paragraphSpacing = prefs.getDouble('reader_paragraph_spacing') ?? 1.5;
        _isDarkMode = prefs.getBool('darkMode') ?? false;
        _enableTextSelection = prefs.getBool('reader_text_selection') ?? true;
        _screenBrightness = prefs.getDouble('reader_brightness') ?? 1.0;

        // Set colors based on theme
        if (_isDarkMode) {
          _textColor =
              prefs.getString('reader_text_color_dark') != null
                  ? Color(int.parse(prefs.getString('reader_text_color_dark')!))
                  : Colors.white.withOpacity(0.9);
          _backgroundColor =
              prefs.getString('reader_background_color_dark') != null
                  ? Color(
                    int.parse(prefs.getString('reader_background_color_dark')!),
                  )
                  : const Color(0xFF121212);
        } else {
          _textColor =
              prefs.getString('reader_text_color_light') != null
                  ? Color(
                    int.parse(prefs.getString('reader_text_color_light')!),
                  )
                  : Colors.black.withOpacity(0.9);
          _backgroundColor =
              prefs.getString('reader_background_color_light') != null
                  ? Color(
                    int.parse(
                      prefs.getString('reader_background_color_light')!,
                    ),
                  )
                  : Colors.white;
        }
      });

      // Load reading progress if available
      if (widget.novel != null && widget.chapterTitle != null) {
        final key = 'progress_${widget.novel!.id}_${widget.chapterTitle}';
        final savedProgress = prefs.getDouble(key);
        if (savedProgress != null) {
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
      // Fetch real content from the crawler service
      final chapterData = await _crawlerService.getChapterContent(
        widget.url,
        context,
      );

      if (mounted) {
        setState(() {
          // Update content
          _content = chapterData['content'] ?? '';

          // Update chapter navigation info if we didn't already get it
          if (!_hasNextChapter &&
              chapterData['nextChapterUrl'] != null &&
              chapterData['nextChapterUrl'].isNotEmpty) {
            _hasNextChapter = true;
            _nextChapterUrl = chapterData['nextChapterUrl'];
            _nextChapterTitle =
                chapterData['nextChapterTitle'] ?? 'Next Chapter';
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
      }

      // Restore reading position after content is loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_readingProgress > 0 &&
            _scrollController.position.maxScrollExtent > 0) {
          final targetPosition =
              _scrollController.position.maxScrollExtent * _readingProgress;
          _scrollController.jumpTo(targetPosition);
        }
      });
    } catch (e) {
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
      final historyService = Provider.of<HistoryService>(
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
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('darkMode', _isDarkMode);
    });
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

    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('reader_brightness', value);
    });
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            final prefs = await SharedPreferences.getInstance();
                            prefs.setDouble('reader_font_size', value);
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
                            final prefs = await SharedPreferences.getInstance();
                            prefs.setDouble('reader_line_height', value);
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
                            final prefs = await SharedPreferences.getInstance();
                            prefs.setDouble('reader_paragraph_spacing', value);
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
                            final prefs = await SharedPreferences.getInstance();
                            prefs.setDouble('reader_brightness', value);
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
                      });

                      // Save the setting
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setBool('darkMode', value);
                      });
                    },
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
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setBool('reader_text_selection', value);
                      });
                    },
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
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
            tooltip: 'Toggle theme',
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
                    if (details.primaryVelocity! > 300 && _hasPreviousChapter) {
                      _navigateToChapter(_prevChapterUrl, _prevChapterTitle);
                    }
                    // Swipe left to go to next chapter
                    else if (details.primaryVelocity! < -300 &&
                        _hasNextChapter) {
                      _navigateToChapter(_nextChapterUrl, _nextChapterTitle);
                    }
                  },
                  child: Stack(
                    children: [
                      // Main content
                      SelectionArea(
                        selectionControls:
                            _enableTextSelection
                                ? MaterialTextSelectionControls()
                                : null,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _parseContent(),
                          ),
                        ),
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
      // Navigation buttons - always visible now
      bottomNavigationBar:
          _isLoading
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
                          color:
                              _hasPreviousChapter
                                  ? _textColor
                                  : _textColor.withOpacity(0.3),
                        ),
                        onPressed:
                            _hasPreviousChapter
                                ? () => _navigateToChapter(
                                  _prevChapterUrl,
                                  _prevChapterTitle,
                                )
                                : null,
                        tooltip:
                            _hasPreviousChapter
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
                          color:
                              _hasNextChapter
                                  ? _textColor
                                  : _textColor.withOpacity(0.3),
                        ),
                        onPressed:
                            _hasNextChapter
                                ? () => _navigateToChapter(
                                  _nextChapterUrl,
                                  _nextChapterTitle,
                                )
                                : null,
                        tooltip:
                            _hasNextChapter
                                ? 'Next Chapter: $_nextChapterTitle'
                                : 'No Next Chapter',
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  List<Widget> _parseContent() {
    final List<Widget> widgets = [];

    // Check if the content is HTML
    if (_content.contains('<p>') || _content.contains('<h')) {
      // Parse HTML content
      final RegExp headerRegex = RegExp(
        r'<h[1-6][^>]*>(.*?)<\/h[1-6]>',
        dotAll: true,
      );
      final RegExp paragraphRegex = RegExp(r'<p[^>]*>(.*?)<\/p>', dotAll: true);

      // Find all headers
      headerRegex.allMatches(_content).forEach((match) {
        final headerText = _stripHtmlTags(match.group(1) ?? '');
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
      });

      // Find all paragraphs
      paragraphRegex.allMatches(_content).forEach((match) {
        final paragraphText = _stripHtmlTags(match.group(1) ?? '');
        if (paragraphText.isNotEmpty) {
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
        }
      });

      // If no widgets were created, just show the raw content with HTML tags stripped
      if (widgets.isEmpty) {
        final plainText = _stripHtmlTags(_content);
        widgets.add(
          Text(
            plainText,
            style: TextStyle(
              fontSize: _fontSize,
              color: _textColor,
              fontFamily: _fontFamily,
              height: _lineHeight,
            ),
          ),
        );
      }
    } else {
      // Use the existing parsing for plain text
      final paragraphs = _content.split('\n\n');

      for (final paragraph in paragraphs) {
        if (paragraph.trim().isEmpty) continue;

        // Check if it's a header
        if (paragraph.trim().startsWith('#')) {
          final headerText = paragraph.trim().substring(1).trim();
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
        } else {
          widgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: 16 * _paragraphSpacing),
              child: Text(
                paragraph.trim(),
                style: TextStyle(
                  fontSize: _fontSize,
                  color: _textColor,
                  fontFamily: _fontFamily,
                  height: _lineHeight,
                ),
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }

  // Helper to strip HTML tags
  String _stripHtmlTags(String htmlString) {
    // Remove all html tags
    final text = htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
    // Convert HTML entities
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}

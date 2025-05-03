import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/theme_services.dart';
import '../screens/custom_toast.dart';
import '../modules/light_novel.dart';
import '../screens/HistoryScreen.dart';
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
          _textColor =
              textColorStr.isNotEmpty
                  ? Color(int.parse(textColorStr))
                  : Colors.white.withOpacity(0.9);

          final bgColorStr = prefsService.getString(
            'reader_background_color_dark',
          );
          _backgroundColor =
              bgColorStr.isNotEmpty
                  ? Color(int.parse(bgColorStr))
                  : const Color(0xFF121212);
        } else {
          final textColorStr = prefsService.getString(
            'reader_text_color_light',
          );
          _textColor =
              textColorStr.isNotEmpty
                  ? Color(int.parse(textColorStr))
                  : Colors.black.withOpacity(0.9);

          final bgColorStr = prefsService.getString(
            'reader_background_color_light',
          );
          _backgroundColor =
              bgColorStr.isNotEmpty
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

      // Reset scroll position after content is loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
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
                        color:
                            _isDarkMode
                                ? Colors.grey.shade800.withOpacity(0.3)
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _isDarkMode
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
                              items:
                                  [5, 10, 15, 20, 25, 30, 45, 60].map((
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Eye Protection Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
    if (_content.contains('<p>') ||
        _content.contains('<h') ||
        _content.contains('<img')) {
      // Use a simpler regex but preprocess the content first
      final processedContent = _content.replaceAll(
        RegExp(r'<p\s+id\s*=\s*"[^"]*"'),
        '<p',
      );

      // First, let's extract all content blocks in the order they appear
      final List<ContentBlock> contentBlocks = [];

      // Extract paragraphs with positions
      final paragraphMatches = RegExp(
        r'<p[^>]*>(.*?)<\/p>',
        dotAll: true,
      ).allMatches(processedContent);
      for (var match in paragraphMatches) {
        contentBlocks.add(
          ContentBlock(
            type: ContentBlockType.paragraph,
            content: match.group(1) ?? '',
            startPosition: match.start,
          ),
        );
      }

      // Extract headers with positions
      final headerMatches = RegExp(
        r'<h[1-6][^>]*>(.*?)<\/h[1-6]>',
        dotAll: true,
      ).allMatches(processedContent);
      for (var match in headerMatches) {
        contentBlocks.add(
          ContentBlock(
            type: ContentBlockType.header,
            content: match.group(1) ?? '',
            startPosition: match.start,
          ),
        );
      }

      // Extract images with positions (double quotes)
      final doubleQuoteImageMatches = RegExp(
        r'<img\s+[^>]*src\s*=\s*"([^"]*)"[^>]*>',
        dotAll: true,
      ).allMatches(processedContent);
      for (var match in doubleQuoteImageMatches) {
        final imageUrl = match.group(1);
        if (imageUrl != null &&
            imageUrl.isNotEmpty &&
            (imageUrl.startsWith('http') || imageUrl.startsWith('https'))) {
          contentBlocks.add(
            ContentBlock(
              type: ContentBlockType.image,
              content: imageUrl,
              startPosition: match.start,
              altText: _extractAltText(match.group(0) ?? ''),
            ),
          );
        }
      }

      // Extract images with positions (single quotes)
      final singleQuoteImageMatches = RegExp(
        r"<img\s+[^>]*src\s*=\s*'([^']*)'[^>]*>",
        dotAll: true,
      ).allMatches(processedContent);
      for (var match in singleQuoteImageMatches) {
        final imageUrl = match.group(1);
        if (imageUrl != null &&
            imageUrl.isNotEmpty &&
            (imageUrl.startsWith('http') || imageUrl.startsWith('https'))) {
          contentBlocks.add(
            ContentBlock(
              type: ContentBlockType.image,
              content: imageUrl,
              startPosition: match.start,
              altText: _extractAltText(match.group(0) ?? ''),
            ),
          );
        }
      }

      // Sort blocks by their position in the original content
      contentBlocks.sort((a, b) => a.startPosition.compareTo(b.startPosition));

      // Process the blocks in order
      for (var block in contentBlocks) {
        switch (block.type) {
          case ContentBlockType.paragraph:
            final paragraphText = _stripHtmlTags(block.content);
            // Skip paragraphs that are only regex artifacts
            if (paragraphText.isEmpty ||
                RegExp(r'^\s*\$\d+\s*$').hasMatch(paragraphText)) {
              continue;
            }

            widgets.add(
              Padding(
                padding: EdgeInsets.only(bottom: 16 * _paragraphSpacing),
                child: EyeFriendlyText(
                  text: paragraphText,
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
            final headerText = _stripHtmlTags(block.content);
            if (headerText.isNotEmpty) {
              widgets.add(
                Padding(
                  padding: EdgeInsets.only(bottom: 16 * _paragraphSpacing),
                  child: EyeFriendlyText(
                    text: headerText,
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
                          child: EyeFriendlyText(
                            text: block.altText!,
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

      // If no widgets were created, just show the raw content with HTML tags stripped
      if (widgets.isEmpty) {
        final plainText = _stripHtmlTags(processedContent);
        widgets.add(
          EyeFriendlyText(
            text: plainText,
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
              child: EyeFriendlyText(
                text: headerText,
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
              child: EyeFriendlyText(
                text: paragraph.trim(),
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

  // Extract alt text from an image tag
  String? _extractAltText(String imgTag) {
    final altTextMatch =
        RegExp(r'alt\s*=\s*"([^"]*)"').firstMatch(imgTag) ??
        RegExp(r"alt\s*=\s*'([^']*)'").firstMatch(imgTag);
    return altTextMatch?.group(1);
  }

  // Helper to strip HTML tags
  String _stripHtmlTags(String htmlString) {
    // Pre-process any visible HTML tags by replacing "<" with "&lt;" if they appear to be raw tags
    String processed = htmlString;

    // Replace raw tags that might be showing in the text
    if (processed.contains('<p id=') || processed.contains('</p><p id=')) {
      processed = processed.replaceAll('<p id=', '').replaceAll('</p>', '');
    }

    // Remove all html tags
    final text = processed.replaceAll(RegExp(r'<[^>]*>'), '');

    // Convert HTML entities
    String result =
        text
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .trim();

    // Remove regex artifacts that might have leaked through
    result = result.replaceAll(RegExp(r'^\s*\$\d+\s*$'), '');
    result = result.replaceAll(RegExp(r'\s+\$\d+\s+'), ' ');

    // Remove any remaining id markers
    result = result.replaceAll(RegExp(r'id="\d+"'), '');
    result = result.replaceAll(RegExp(r"id='\d+'"), '');

    return result;
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
        builder:
            (context) => CommentsScreen(
              url: widget.url,
              title: widget.chapterTitle ?? widget.title,
            ),
      ),
    );
  }
}

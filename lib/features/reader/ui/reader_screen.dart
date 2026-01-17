import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For compute()
import 'package:docln/core/widgets/custom_toast.dart';
import 'package:docln/core/models/light_novel.dart';
import 'package:docln/core/services/history_service_v2.dart';
import 'package:docln/core/services/eye_protection_service.dart';
import 'package:docln/core/widgets/eye_protection_overlay.dart';

import 'package:docln/core/widgets/network_image.dart';
import 'package:docln/features/settings/ui/EyeCareScreen.dart';

import 'comments_screen.dart';
import 'package:docln/core/services/preferences_service.dart';
import 'package:docln/core/services/api_service.dart';
import 'package:docln/core/models/hako_models.dart';

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
      // 1. Dùng ApiService gọi data về (Object NovelDetail chuẩn chỉ)
      final novelDetails = await _apiService.fetchNovelDetail(
        widget.novel!.url,
      );

      if (mounted) {
        // 2. Làm phẳng danh sách chương (Gộp tất cả Volume lại thành 1 list)
        // Vì trong model mới: NovelDetail -> List<Volume> -> List<Chapter>
        final List<Chapter> allChapters = [];
        for (var vol in novelDetails.volumes) {
          allChapters.addAll(vol.chapters);
        }

        if (allChapters.isNotEmpty) {
          // 3. Tìm vị trí chương hiện tại
          int currentIndex = -1;
          for (int i = 0; i < allChapters.length; i++) {
            // So sánh tiêu đề để tìm chương đang đọc
            if (allChapters[i].title == widget.chapterTitle) {
              currentIndex = i;
              break;
            }
          }

          if (currentIndex != -1) {
            // 4. Xử lý chương TIẾP THEO
            if (currentIndex < allChapters.length - 1) {
              setState(() {
                _hasNextChapter = true;
                final nextChapter = allChapters[currentIndex + 1];
                _nextChapterUrl = nextChapter.url;
                _nextChapterTitle = nextChapter.title;
              });
            }

            // 5. Xử lý chương TRƯỚC ĐÓ
            if (currentIndex > 0) {
              setState(() {
                _hasPreviousChapter = true;
                final prevChapter = allChapters[currentIndex - 1];
                _prevChapterUrl = prevChapter.url;
                _prevChapterTitle = prevChapter.title;
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

  final ApiService _apiService = ApiService();
  List<ChapterContent> _chapterContentList = []; // Dữ liệu mới từ API

  Future<void> _fetchContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 Fetching via API...');

      // GỌI API LẤY LIST TEXT/IMAGE
      final content = await _apiService.fetchChapterContent(widget.url);

      if (!mounted) return;

      setState(() {
        _chapterContentList = content; // Lưu vào list
        _isLoading = false;

        // Logic next/prev chapter mày tự xử lý ở backend hoặc call API detail để lấy list
        // (Tạm thời bỏ qua hoặc giữ logic cũ nếu muốn)
      });

      // Reset scroll
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
          _chapterContentList = [
            ChapterContent(type: 'text', content: 'Lỗi tải chương: $e'),
          ];
        });
        CustomToast.show(context, 'Error: $e');
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
    // Dùng ListView.builder render list text/image
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chapterContentList.length,
      itemBuilder: (context, index) {
        final item = _chapterContentList[index];

        if (item.type == 'image') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _buildImageWidget(item.content), // Hàm build ảnh cũ của mày
          );
        } else {
          // Render Text
          return Padding(
            padding: EdgeInsets.only(bottom: 16 * _paragraphSpacing),
            child: Text(
              item.content,
              style: TextStyle(
                fontSize: _fontSize,
                color: _textColor,
                fontFamily: _fontFamily,
                height: _lineHeight,
              ),
            ),
          );
        }
      },
    );
  }

  // Method to fix image URLs before loading
  String _fixImageUrl(String url) {
    // Giữ lại logic thay thế domain lỗi (docln -> hako)
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

    // XÓA ĐOẠN GỌI CRAWLER SERVICE ĐI
    // Trả về URL gốc nếu không cần fix
    return url;
  }

  // Custom image widget that handles redirects and fallbacks
  Widget _buildImageWidget(String imageUrl) {
    final fixedUrl = _fixImageUrl(imageUrl);

    // RAM OPTIMIZATION: Calculate optimal cache size
    // limit max width to 1080p to prevent OOM on high-res tablets loading excessively huge images
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetWidth = (screenWidth * devicePixelRatio).toInt();
    final memCacheWidth = targetWidth > 1500
        ? 1500
        : targetWidth; // Cap at ~1500px width

    return RepaintBoundary(
      // Performance: Separate layer for images
      child: OptimizedNetworkImage(
        imageUrl: fixedUrl,
        fit: BoxFit.contain,
        memCacheWidth: memCacheWidth, // Vital for RAM usage
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
              memCacheWidth: memCacheWidth,
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
        placeholder: Center(
          child: SizedBox(
            height: 200, // Fixed height placeholder to reduce layout jumps
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
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

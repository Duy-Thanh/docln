import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/theme_services.dart';
import '../screens/custom_toast.dart';
import '../modules/light_novel.dart';
import '../screens/HistoryScreen.dart';

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

class _ReaderScreenState extends State<ReaderScreen> {
  bool _isLoading = true;
  String _content = '';
  double _fontSize = 18.0;
  String _fontFamily = 'Roboto';
  double _lineHeight = 1.8;
  Color _textColor = Colors.black;
  Color _backgroundColor = Colors.white;
  bool _isDarkMode = false;
  double _paragraphSpacing = 1.5;

  // Reading progress
  double _readingProgress = 0.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchContent();

    // Add scroll listener for reading progress
    _scrollController.addListener(_updateReadingProgress);

    // Save to reading history
    _addToHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateReadingProgress);
    _scrollController.dispose();
    // Save reading progress when leaving
    _saveReadingProgress();
    super.dispose();
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
    }
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
      // For now, we'll use placeholder content
      // In a real implementation, you would fetch the content from an API
      await Future.delayed(const Duration(milliseconds: 800));

      setState(() {
        _content = _getDummyContent();
        _isLoading = false;
      });

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
      setState(() {
        _isLoading = false;
        _content = 'Error loading content: $e';
      });
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

  String _getDummyContent() {
    return """
# ${widget.chapterTitle ?? 'Chapter Title'}

It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of foolishness, it was the epoch of belief, it was the epoch of incredulity, it was the season of Light, it was the season of Darkness, it was the spring of hope, it was the winter of despair, we had everything before us, we had nothing before us, we were all going direct to Heaven, we were all going direct the other way.

In a certain corner of a certain town, there lived a peculiar young man. He wasn't particularly tall, nor was he notably short. His features weren't strikingly handsome, but neither were they unpleasant to look at. By all accounts, he was thoroughly average—or so it seemed on the surface.

"I can't believe this is happening again," he muttered, glancing at the notification on his phone.

The message read: [System Alert: Dimensional Instability Detected]

He sighed, wondering how many times he would be forced to relive this same scenario. This was his seventh "reset" since the phenomenon had begun.

"You look troubled," came a soft voice from behind him.

He turned to see a young woman with silver hair that seemed to capture and reflect the moonlight. Her eyes, an unusual shade of violet, regarded him with concern.

"Aiko," he acknowledged with a nod. "I thought you weren't supposed to remember me this time."

She smiled mysteriously. "The system has its flaws. Those of us who've been through enough resets develop a certain... resistance."

"So what now?" he asked, feeling the familiar weight of destiny settling on his shoulders once again.

"Now," she replied, her expression growing serious, "we find the anomaly before it destroys this timeline too."

The young man nodded, understanding the gravity of their mission. With each reset, the fabric of reality grew thinner, more fragile. If they failed again, there might not be another chance.

"Lead the way," he said, following her into the night.

As they walked through the eerily quiet streets, he couldn't help but notice how different everything looked in this iteration. The buildings seemed older, more worn. The technology less advanced. It was as if they had gone back in time rather than simply resetting to a parallel dimension.

"Something's different this time," he observed. "We're further back than before."

Aiko nodded. "The system is deteriorating. It can no longer maintain consistency between resets. That's why we need to act quickly."

A distant rumble caught their attention. Looking up, they saw a crack forming in the sky—a literal fracture in the firmament, glowing with an ominous purple light.

"It's starting," Aiko whispered. "The collapse is happening faster than before."

The young man clenched his fists. "Then we'd better hurry."

Together, they raced toward the source of the disturbance, knowing that the fate of not just this world, but all possible worlds, rested on their success.

What they didn't know was that something was watching them—something that had engineered these resets for its own inscrutable purpose. And it had no intention of letting them succeed this time either.

In the distance, a clock struck midnight, and with each resonant toll, the crack in the sky grew larger...
    """;
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
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  // Main content
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _parseContent(),
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
    );
  }

  List<Widget> _parseContent() {
    final List<Widget> widgets = [];

    // Split content by paragraphs
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

    return widgets;
  }
}

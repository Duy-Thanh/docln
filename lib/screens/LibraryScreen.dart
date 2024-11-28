import 'package:flutter/material.dart';
import '../modules/announcement.dart';
import '../services/crawler_service.dart';
import '../screens/custom_toast.dart';
import '../screens/webview_screen.dart';
import '../modules/light_novel.dart';
import 'widgets/light_novel_card.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io' show Platform;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final CrawlerService _crawlerService = CrawlerService();
  late TabController _tabController;

  List<Announcement> announcements = [];
  List<LightNovel> popularNovels = [];
  List<LightNovel> creativeNovels = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnnouncements();
    _loadAllNovels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final fetchedAnnouncements = await _crawlerService.getAnnouncements(context);
      
      setState(() {
        announcements = fetchedAnnouncements;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      CustomToast.show(context, error!);
    }
  }

  Future<void> _loadAllNovels() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Load both sections in parallel
      final results = await Future.wait([
        _crawlerService.getPopularNovels(context),
        _crawlerService.getCreativeNovels(context),
      ]);

      setState(() {
        popularNovels = results[0];
        creativeNovels = results[1];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      await Future.wait([
        _loadAnnouncements(),
        _loadAllNovels(),
      ]);
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      CustomToast.show(context, 'Error loading data: $e');
    }
  }

  // Future<void> _loadPopularNovels() async {
  //   try {
  //     setState(() {
  //       isLoading = true;
  //       error = null;
  //     });

  //     final novels = await _crawlerService.getPopularNovels(context);
      
  //     setState(() {
  //       popularNovels = novels;
  //       isLoading = false;
  //     });
  //   } catch (e) {
  //     setState(() {
  //       error = e.toString();
  //       isLoading = false;
  //     });
  //     CustomToast.show(context, 'Error fetching novels: $e');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DocLN'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.local_fire_department_rounded),
              text: 'Popular',
            ),
            Tab(
              icon: Icon(Icons.create_rounded),
              text: 'Creative',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Announcements at top
          if (announcements.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final announcement = announcements[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebViewScreen(url: announcement.url),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Text(
                            announcement.title,
                            style: TextStyle(
                              color: _getColorFromString(
                                announcement.color,
                                Theme.of(context).brightness == Brightness.dark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Popular Novels Tab
                _buildNovelGrid(
                  novels: popularNovels,
                  isLoading: isLoading,
                  showRating: true,
                ),

                // Creative Novels Tab
                _buildNovelGrid(
                  novels: creativeNovels,
                  isLoading: isLoading,
                  showChapterInfo: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovelGrid({
    required List<LightNovel> novels,
    required bool isLoading,
    bool showRating = false,
    bool showChapterInfo = false,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (novels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No novels available'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: novels.length,
        itemBuilder: (context, index) {
          return LightNovelCard(
            novel: novels[index],
            showRating: showRating,
            showChapterInfo: showChapterInfo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewScreen(url: novels[index].url),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewScreen(url: announcement.url),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              announcement.title,
              style: TextStyle(
                color: _getColorFromString(announcement.color, isDarkMode),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNovelSection({
    required String title,
    required IconData icon,
    required List<LightNovel> novels,
    bool showRating = false,
    bool showChapterInfo = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (novels.isEmpty)
          Center(child: Text('No $title available'))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.48,  // Adjusted to be taller
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: novels.length,
            itemBuilder: (context, index) {
              final novel = novels[index];
              return LightNovelCard(
                novel: novel,
                showRating: showRating,
                showChapterInfo: showChapterInfo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(url: novel.url),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLibraryTitle() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Adjusted padding
        child: Row(
          children: [
            Icon(
              Icons.campaign_rounded,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Announcements',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Fetching data, please be patient...', 
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Card(
          elevation: 2,
          shadowColor: Theme.of(context).colorScheme.error.withOpacity(0.3),
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Error Icon
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                              blurRadius: 20 * value,
                              spreadRadius: 5 * value,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Error Title with Animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    'Connection Error',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Error Message with Animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    'Error while fetching data.\n\nMaybe you are offline or the server is down.\n\nPlease check your internet connection\n\nUse button below to go to Internet settings',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Settings Buttons with Animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSettingsButton(
                        icon: Icons.wifi_rounded,
                        label: 'Wi-Fi',
                        onTap: () async {
                          if (Platform.isAndroid) {
                            const AndroidIntent intent = AndroidIntent(
                              action: 'android.settings.WIFI_SETTINGS',
                            );
                            await intent.launch();
                          } else {
                            await AppSettings.openAppSettings(type: AppSettingsType.wifi);
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildSettingsButton(
                        icon: Icons.cell_tower_rounded,
                        label: 'Mobile Data',
                        onTap: () async {
                          if (Platform.isAndroid) {
                            const AndroidIntent intent = AndroidIntent(
                              action: 'android.settings.DATA_ROAMING_SETTINGS',
                            );
                            await intent.launch();
                          } else {
                            await AppSettings.openAppSettings(type: AppSettingsType.wireless);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Try Again Button with Animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: TextButton.icon(
                    onPressed: _loadAnnouncements,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.1),
                      foregroundColor: Theme.of(context).colorScheme.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ).copyWith(
                      overlayColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.pressed)) {
                          return Theme.of(context).colorScheme.error.withOpacity(0.2);
                        }
                        if (states.contains(MaterialState.hovered)) {
                          return Theme.of(context).colorScheme.error.withOpacity(0.15);
                        }
                        return null;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ).copyWith(
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) {
            return Theme.of(context).colorScheme.primary.withOpacity(0.1);
          }
          return null;
        }),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsList(bool isDarkMode) {
    if (announcements.isEmpty) {
      return Center(
        child: Text(
          'No announcements available',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: announcements.map((announcement) => 
            _buildAnnouncementItem(announcement, isDarkMode)
          ).toList(),
        ),
      ),
    );
  }

  Widget _buildAnnouncementItem(Announcement announcement, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewScreen(url: announcement.url),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              announcement.title,
              style: TextStyle(
                fontSize: 14,
                color: _getColorFromString(announcement.color, isDarkMode),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorFromString(String? colorString, bool isDarkMode) {
    if (colorString == null || colorString.isEmpty) {
      return isDarkMode ? Colors.white : Colors.black; // Default color based on theme
    }

    if (colorString.trim() == 'red') {
      return isDarkMode ? Colors.red[300]! : Colors.red;
    } else if (colorString.trim() == 'blue') {
      return isDarkMode ? Colors.blue[300]! : Colors.blue;
    }

    if (colorString.startsWith('#') && (colorString.length == 7 || colorString.length == 9)) {
      Color baseColor = Color(int.parse(colorString.replaceAll('#', '0xFF')));
      return isDarkMode ? baseColor.withOpacity(0.8) : baseColor; // Slightly lighter in dark mode
    } else {
      return isDarkMode ? Colors.white : Colors.black; // Default color based on theme
    }
  }
}
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

class _LibraryScreenState extends State<LibraryScreen> {
  final CrawlerService _crawlerService = CrawlerService();
  List<Announcement> announcements = [];
  List<LightNovel> popularNovels = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _loadPopularNovels();
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

  Future<void> _loadPopularNovels() async {
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      popularNovels = [
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
        LightNovel(
          id: '1',
          title: 'Light Novel 1',
          coverUrl: 'https://ln.hako.vn/img/nocover.jpg',
          url: '/tests1',
          chapters: 123,
          rating: 4.5,
          reviews: 789,
        ),
      ];

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: isLoading 
          ? _buildLoadingIndicator()
          : error != null 
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: _buildErrorCard(),
                      ),
                    ),
                  );
                },
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildLibraryTitle(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildAnnouncementsList(isDarkMode),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildPopularNovels(isDarkMode),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
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

  // Update the GridView in _buildPopularNovels
  Widget _buildPopularNovels(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              Icons.local_library_rounded,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Popular Novels',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (popularNovels.isEmpty)
          Center(
            child: Text(
              'No novels available',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),  // Disable grid scrolling
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: popularNovels.length,
            itemBuilder: (context, index) {
              final novel = popularNovels[index];
              return LightNovelCard(
                novel: novel,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebViewScreen(
                        url: 'https://ln.hako.vn${novel.url}',
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
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
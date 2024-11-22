import 'package:flutter/material.dart';
import '../modules/announcement.dart';
import '../services/crawler_service.dart';
import '../screens/custom_toast.dart';
import '../screens/webview_screen.dart';
import '../modules/light_novel.dart';
import 'widgets/light_novel_card.dart';

class LibraryScreen extends StatefulWidget {
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
    await Future.delayed(Duration(seconds: 2));

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
        child: SingleChildScrollView(  // Wrap with SingleChildScrollView
          physics: const AlwaysScrollableScrollPhysics(),  // Enable scrolling
          child: Column(
            children: [
              if (isLoading) 
                _buildLoadingIndicator()
              else if (error != null) 
                _buildErrorCard()
              else ... [
                _buildLibraryTitle(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAnnouncementsList(isDarkMode),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildPopularNovels(isDarkMode),
                ),
                // Add bottom padding for better scroll experience
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryTitle() {
    return Padding(
      padding: const EdgeInsets.all(16),
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
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
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
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connection Error',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error?.replaceAll('Exception: ', '') ?? 'Error fetching announcements.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _loadAnnouncements,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
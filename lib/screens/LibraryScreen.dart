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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isLoading) _buildLoadingIndicator(),
            if (error != null) _buildErrorCard(),
            if (!isLoading && error == null) ... {
              _buildLibraryTitle(),
              _buildAnnouncementsList(isDarkMode),
              _buildPopularNovels(isDarkMode),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryTitle() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'Library',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
      ],
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 20),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.redAccent, Colors.red],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _loadAnnouncements,
              child: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList(bool isDarkMode) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ...announcements.map((announcement) => 
              _buildAnnouncementItem(announcement, isDarkMode)
            ).toList(),
          ],
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

  // Light Novels
  Widget _buildPopularNovels(bool isDarkMode) {
    return Container();
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
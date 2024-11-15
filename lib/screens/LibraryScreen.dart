import 'package:flutter/material.dart';
import '../modules/announcement.dart';
import '../services/crawler_service.dart';
import '../screens/custom_toast.dart';

class LibraryScreen extends StatefulWidget {
  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final CrawlerService _crawlerService = CrawlerService();
  List<Announcement> announcements = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isLoading) _buildLoadingIndicator(),
            if (error != null) _buildErrorCard(),
            if (!isLoading && error == null) _buildAnnouncementsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200, // Adjust height to center
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading...', style: TextStyle(fontSize: 16)),
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

  Widget _buildAnnouncementsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Thông báo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ...announcements.map((announcement) => _buildAnnouncementItem(announcement)).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementItem(Announcement announcement) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(4),
      child: InkWell(
        onTap: () {
          // Handle announcement tap
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              announcement.title,
              style: TextStyle(
                fontSize: 14,
                color: _getColorFromString(announcement.color),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorFromString(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.black; // Default color
    }

    if (colorString.trim() == 'red') {
      return Colors.red;
    } else if (colorString.trim() == 'blue') {
      return Colors.blue;
    }

    if (colorString.startsWith('#') && (colorString.length == 7 || colorString.length == 9)) {
      return Color(int.parse(colorString.replaceAll('#', '0xFF')));
    } else {
      return Colors.black; // Default color
    }
  }
}
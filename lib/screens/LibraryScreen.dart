import 'package:flutter/material.dart';
import '../modules/announcement.dart';
import '../services/crawler_service.dart';

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

      final fetchedAnnouncements = await _crawlerService.getAnnouncements();
      
      setState(() {
        announcements = fetchedAnnouncements;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Không thể kết nối đến máy chủ. Vui lòng thử lại sau.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            isLoading 
              ? Center(child: CircularProgressIndicator())
              : error != null
                ? Column(
                    children: [
                      Text(
                        error!,
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadAnnouncements,
                        child: Text('Thử lại'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Thông báo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8), // Reduced space
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200], // Light background color
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.all(4), // Reduced padding
                        child: Column(
                          children: [
                            ...announcements.map((announcement) => 
                              Container(
                                margin: EdgeInsets.symmetric(vertical: 2), // Reduced margin
                                padding: EdgeInsets.all(4), // Reduced padding
                                child: InkWell(
                                  onTap: () {
                                    // Handle announcement tap
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center, // Center align text
                                    children: [
                                      Text(
                                        announcement.title,
                                        style: TextStyle(
                                          fontSize: 14, // Smaller font size
                                          color: _getColorFromString(announcement.color),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center, // Center text
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // Helper function to convert color string to Color
  Color _getColorFromString(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.black; // Default color
    }

    // Check for named colors
    if (colorString.trim() == 'red') {
      return Colors.red;
    } else if (colorString.trim() == 'blue') {
      return Colors.blue;
    }

    // Check if the color string starts with '#' and has the correct length
    if (colorString.startsWith('#') && (colorString.length == 7 || colorString.length == 9)) {
      return Color(int.parse(colorString.replaceAll('#', '0xFF')));
    } else {
      // If it's not a valid hex color, return a default color
      return Colors.black; // Default color
    }
  }
}
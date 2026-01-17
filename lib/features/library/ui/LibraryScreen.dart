import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io' show Platform;

// Import các modules cũ
import 'package:docln/core/models/announcement.dart';
import 'package:docln/core/models/chapter.dart';
import 'package:docln/core/models/light_novel.dart';

// Import Service & Model mới
// FIX LỖI Ở ĐÂY: Ẩn class Chapter của model mới để tránh trùng tên với model cũ
import 'package:docln/core/models/hako_models.dart' hide Chapter;

// Screens & Widgets
import 'package:docln/core/services/api_service.dart'; // Import API Service
import 'package:docln/core/widgets/custom_toast.dart';
import 'package:docln/core/widgets/webview_screen.dart';
import 'package:docln/features/reader/ui/LightNovelDetailsScreen.dart';
import 'package:docln/features/reader/ui/reader_screen.dart';
import 'package:docln/core/widgets/light_novel_card.dart';
import 'package:docln/core/widgets/chapter_card.dart';
import 'package:docln/core/services/performance_service.dart';

// Settings
import 'package:android_intent_plus/android_intent.dart';
import 'package:app_settings/app_settings.dart';
import 'package:docln/core/services/settings_services.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {
  // Dùng ApiService thay cho CrawlerService
  final ApiService _apiService = ApiService();

  late TabController _tabController;
  int _selectedIndex = 0;

  List<Announcement> announcements = [];
  List<LightNovel> popularNovels = [];
  List<LightNovel> creativeNovels = [];
  List<Chapter> latestChapters = []; // List này dùng Chapter cũ

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _optimizeScreen();
    _tabController = TabController(length: 3, vsync: this);

    _loadData();
  }

  Future<void> _optimizeScreen() async {
    await PerformanceService.optimizeScreen('LibraryScreen');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      HapticFeedback.lightImpact();
    }
  }

  // --- LOGIC LOAD DATA TỪ API ---
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Gọi API Home lấy tất cả dữ liệu 1 lần
      final homeData = await _apiService.fetchHome();

      if (!mounted) return;

      setState(() {
        // 1. Map 'featured' -> Popular Novels (Dùng class LightNovel cũ)
        popularNovels = homeData['featured']!
            .map(
              (item) => LightNovel(
                id: item.id,
                title: item.title,
                url: item.url,
                coverUrl: item.cover,
                // Các field khác để mặc định
                latestChapter: '',
                chapters: 0,
              ),
            )
            .toList();

        // 2. Map 'original' -> Creative Novels
        creativeNovels = homeData['original']!
            .map(
              (item) => LightNovel(
                id: item.id,
                title: item.title,
                url: item.url,
                coverUrl: item.cover,
                latestChapter: item.latestChapter ?? '',
                chapters: 0,
              ),
            )
            .toList();

        // 3. Map 'translation' -> Latest Chapters
        // Chuyển đổi dữ liệu từ API sang object Chapter cũ cho khớp UI
        latestChapters = homeData['translation']!
            .map(
              (item) => Chapter(
                id: item.id,
                title: item.latestChapter ?? 'New Chapter',
                url: item.url,
                seriesTitle: item.title, // Field cũ
                coverUrl: item.cover, // Field cũ
                time: '',
                seriesUrl: item.url, // Field cũ
              ),
            )
            .toList();

        // 4. Announcements (Tạm thời để trống hoặc fake nếu API chưa có)
        announcements = [];

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      // CustomToast.show(context, 'Data loading error: $e');
      print('Data loading error: $e');
    }
  }

  // Giữ lại hàm này để nút "Try Again" hoạt động
  Future<void> _loadAnnouncements() async {
    _loadData();
  }

  // --- PHẦN UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Modern Material 3 TabBar
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 12,
              16,
              12,
            ),
            color: theme.scaffoldBackgroundColor,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                controller: _tabController,
                onTap: _onTabTapped,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: theme.colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_fire_department_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Popular'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.create_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Original'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.new_releases_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Latest'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Announcement banner
          if (announcements.isNotEmpty)
            _buildAnnouncementBanner(
              theme.colorScheme,
              theme.textTheme,
              theme.brightness == Brightness.dark,
            ),

          // Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: [
                  _buildTabContent(
                    novels: popularNovels,
                    isLoading: isLoading,
                    showRating: true,
                  ),
                  _buildTabContent(
                    novels: creativeNovels,
                    isLoading: isLoading,
                    showChapterInfo: true,
                  ),
                  _buildLatestChaptersTab(),
                ][_selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementBanner(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceVariant.withOpacity(0.3)
            : colorScheme.surfaceVariant.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: announcements.length,
        itemBuilder: (context, index) => _buildAnnouncementChip(
          announcement: announcements[index],
          colorScheme: colorScheme,
          textTheme: textTheme,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildAnnouncementChip({
    required Announcement announcement,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Material(
        color: _getColorFromString(announcement.color, isDark).withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewScreen(url: announcement.url),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.announcement_outlined,
                  size: 16,
                  color: _getColorFromString(announcement.color, isDark),
                ),
                const SizedBox(width: 8),
                Text(
                  announcement.title,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _getColorFromString(announcement.color, isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorFromString(String? colorString, bool isDarkMode) {
    if (colorString == null || colorString.isEmpty) {
      return isDarkMode ? Colors.white : Colors.black;
    }
    if (colorString.trim() == 'red')
      return isDarkMode ? Colors.red[300]! : Colors.red;
    if (colorString.trim() == 'blue')
      return isDarkMode ? Colors.blue[300]! : Colors.blue;
    return isDarkMode ? Colors.white : Colors.black;
  }

  Widget _buildTabContent({
    required List<LightNovel> novels,
    required bool isLoading,
    bool showRating = false,
    bool showChapterInfo = false,
  }) {
    if (error != null) return _buildErrorCard();
    if (isLoading) return _buildLoadingGrid();
    if (novels.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
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
                builder: (context) =>
                    LightNovelDetailsScreen(novel: novel, novelUrl: novel.url),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestChaptersTab() {
    if (isLoading) return _buildLoadingGrid();
    if (latestChapters.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: latestChapters.length,
        itemBuilder: (context, index) => ChapterCard(
          chapter: latestChapters[index],
          onTap: () async {
            final fullUrl = await _ensureFullUrl(latestChapters[index].url);

            // Vào chi tiết truyện trước (để load đủ thông tin)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LightNovelDetailsScreen(
                  novel: LightNovel(
                    id: latestChapters[index].id,
                    title: latestChapters[index].seriesTitle,
                    url: latestChapters[index].seriesUrl ?? '',
                    coverUrl: latestChapters[index].coverUrl ?? '',
                    chapters: 0,
                  ),
                  novelUrl: latestChapters[index].seriesUrl ?? '',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<String> _ensureFullUrl(String url) async {
    if (url.startsWith('http')) return url;
    final settingsService = SettingsService();
    final baseUrl =
        await settingsService.getCurrentServer() ?? 'https://docln.sbs';
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanPath';
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.library_books_outlined,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text('No data available'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(error ?? 'Connection error'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              if (Platform.isAndroid) {
                const AndroidIntent intent = AndroidIntent(
                  action: 'android.settings.WIFI_SETTINGS',
                );
                await intent.launch();
              }
            },
            child: const Text('Check WiFi'),
          ),
        ],
      ),
    );
  }
}

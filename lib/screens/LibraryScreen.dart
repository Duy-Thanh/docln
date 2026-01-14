import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io' show Platform;

// Import các modules cũ
import '../modules/announcement.dart';
import '../modules/chapter.dart';
import '../modules/light_novel.dart';

// Import Service & Model mới
// FIX LỖI Ở ĐÂY: Ẩn class Chapter của model mới để tránh trùng tên với model cũ
import '../models/hako_models.dart' hide Chapter;

// Screens & Widgets
import '../services/api_service.dart'; // Import API Service
import '../screens/custom_toast.dart';
import '../screens/webview_screen.dart';
import '../screens/LightNovelDetailsScreen.dart';
import './reader_screen.dart';
import 'widgets/light_novel_card.dart';
import 'widgets/chapter_card.dart';
import '../services/performance_service.dart';

// Settings
import 'package:android_intent_plus/android_intent.dart';
import 'package:app_settings/app_settings.dart';
import 'package:docln/services/settings_services.dart';

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
  late AnimationController _controller;
  double _tabAnimationValue = 0.0;
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
    _tabController.animation?.addListener(_handleTabAnimation);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _loadData();
  }

  Future<void> _optimizeScreen() async {
    await PerformanceService.optimizeScreen('LibraryScreen');
  }

  @override
  void dispose() {
    _tabController.animation?.removeListener(_handleTabAnimation);
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTabAnimation() {
    setState(() {
      _tabAnimationValue = _tabController.animation!.value;
    });
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
                title: item.latestChapter ?? 'Chương mới',
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
      // CustomToast.show(context, 'Lỗi tải dữ liệu: $e');
      print('Lỗi tải dữ liệu: $e');
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
          // Enhanced Tab Bar Container
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.08),
                  theme.colorScheme.primary.withOpacity(0.02),
                  theme.scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = (constraints.maxWidth - 8) / 3;
                  return Stack(
                    children: [
                      // Animated selection background
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutExpo,
                        left: 4 + (_selectedIndex * tabWidth),
                        child: Container(
                          width: tabWidth,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Tab buttons
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabItem(
                                'Nổi bật',
                                Icons.local_fire_department_rounded,
                                0,
                                theme,
                              ),
                            ),
                            Expanded(
                              child: _buildTabItem(
                                'Sáng tác',
                                Icons.create_rounded,
                                1,
                                theme,
                              ),
                            ),
                            Expanded(
                              child: _buildTabItem(
                                'Mới nhất',
                                Icons.new_releases_rounded,
                                2,
                                theme,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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

  Widget _buildTabItem(
    String title,
    IconData icon,
    int index,
    ThemeData theme,
  ) {
    final isSelected = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(26),
        child: Container(
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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
          const Text('Không có dữ liệu'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
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
          Text(error ?? 'Lỗi kết nối'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
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
            child: const Text('Kiểm tra Wifi'),
          ),
        ],
      ),
    );
  }
}

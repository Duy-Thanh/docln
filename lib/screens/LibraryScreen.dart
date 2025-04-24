import 'package:docln/services/settings_services.dart';
import 'package:flutter/material.dart';
import '../modules/announcement.dart';
import '../modules/chapter.dart';
import '../services/crawler_service.dart';
import '../screens/custom_toast.dart';
import '../screens/webview_screen.dart';
import '../modules/light_novel.dart';
import 'widgets/light_novel_card.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io' show Platform;
import 'widgets/latest_chapters_section.dart';
import 'widgets/chapter_card.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import '../services/performance_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {
  final CrawlerService _crawlerService = CrawlerService();
  late TabController _tabController;
  late AnimationController _controller;
  double _tabAnimationValue = 0.0;
  int _selectedIndex = 0;

  // Initialize animation controller and animation at declaration
  late final AnimationController _gradientAnimationController =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);

  late final Animation<double> _gradientAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(_gradientAnimationController);

  List<Announcement> announcements = [];
  List<LightNovel> popularNovels = [];
  List<LightNovel> creativeNovels = [];
  List<Chapter> latestChapters = [];
  bool isLoading = true;
  String? error;

  void _onTabTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      // Add haptic feedback for better interaction
      HapticFeedback.lightImpact();
    }
  }

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
    _gradientAnimationController.dispose();
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

  Future<void> _loadAnnouncements() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final fetchedAnnouncements = await _crawlerService.getAnnouncements(
        context,
      );

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
    setState(() => isLoading = true);
    try {
      final futures = await Future.wait([
        _crawlerService.getAnnouncements(context),
        _crawlerService.getPopularNovels(context),
        _crawlerService.getCreativeNovels(context),
        _crawlerService.getLatestChapters(context),
      ]);

      setState(() {
        announcements = futures[0] as List<Announcement>;
        popularNovels = futures[1] as List<LightNovel>;
        creativeNovels = futures[2] as List<LightNovel>;
        latestChapters = futures[3] as List<Chapter>;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      CustomToast.show(context, 'Error loading data: $e');
    }
  }

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
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.03),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
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
                      // Enhanced animated selection background
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
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.05,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          // Add subtle gradient to selected tab
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary.withOpacity(0.05),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                            ),
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
                                'Popular',
                                Icons.trending_up_rounded,
                                0,
                                theme,
                              ),
                            ),
                            Expanded(
                              child: _buildTabItem(
                                'Creative',
                                Icons.auto_awesome_rounded,
                                1,
                                theme,
                              ),
                            ),
                            Expanded(
                              child: _buildTabItem(
                                'Latest',
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

          // Existing announcement banner
          if (announcements.isNotEmpty)
            _buildAnnouncementBanner(
              theme.colorScheme,
              theme.textTheme,
              theme.brightness == Brightness.dark,
            ),

          // Content with existing transitions
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.03, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child:
                    [
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
              // Enhanced icon with scale and rotation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1.0 + (value * 0.2),
                    child: Transform.rotate(
                      angle: value * 0.1,
                      child: Icon(
                        icon,
                        color: Color.lerp(
                          theme.colorScheme.onSurface.withOpacity(0.6),
                          theme.colorScheme.primary,
                          value,
                        ),
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              // Enhanced text with scale and slide
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1.0 + (value * 0.1),
                    child: Transform.translate(
                      offset: Offset(value * 2, 0),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Color.lerp(
                            theme.colorScheme.onSurface.withOpacity(0.6),
                            theme.colorScheme.primary,
                            value,
                          ),
                          fontSize:
                              14 + (value * 1), // Subtle font size animation
                          fontWeight: FontWeight.lerp(
                            FontWeight.w500,
                            FontWeight.w600,
                            value,
                          ),
                          letterSpacing: 0.2 + (value * 0.2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required int tabIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate the color interpolation value based on animation
    final colorValue =
        1.0 - (_tabAnimationValue - tabIndex).abs().clamp(0.0, 1.0);

    return Tab(
      height: 40,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: Color.lerp(
                colorScheme.onSurfaceVariant,
                colorScheme.primary,
                colorValue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Color.lerp(
                  colorScheme.onSurfaceVariant,
                  colorScheme.primary,
                  colorValue,
                ),
                fontWeight: FontWeight.lerp(
                  FontWeight.w500,
                  FontWeight.w600,
                  colorValue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedTabs() {
    return [
      _buildAnimatedTab(
        icon: Icons.local_fire_department_rounded,
        label: 'Popular',
        isSelected: _tabController.index == 0,
      ),
      _buildAnimatedTab(
        icon: Icons.create_rounded,
        label: 'Creative',
        isSelected: _tabController.index == 1,
      ),
    ];
  }

  Widget _buildAnimatedTab({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Tab(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
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
      height: 52, // Increased height
      decoration: BoxDecoration(
        color:
            isDark
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
        itemBuilder:
            (context, index) => _buildAnnouncementChip(
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
          onTap:
              () => Navigator.push(
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
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required List<LightNovel> novels,
    required bool isLoading,
    bool showRating = false,
    bool showChapterInfo = false,
  }) {
    if (error != null) {
      return _buildErrorCard();
    }

    if (isLoading) {
      return _buildLoadingGrid();
    }

    if (novels.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final novel = novels[index];
                return KeyedSubtree(
                  key: ValueKey(novel.id),
                  child: LightNovelCard(
                    novel: novel,
                    showRating: showRating,
                    showChapterInfo: showChapterInfo,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WebViewScreen(url: novel.url),
                          ),
                        ),
                  ),
                );
              }, childCount: novels.length),
            ),
          ),
        ],
      ),
    );
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
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No novels available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reload'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
            onTap:
                () => Navigator.push(
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
        onTap:
            () => Navigator.push(
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
              Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
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
              childAspectRatio: 0.48, // Adjusted to be taller
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
                onTap:
                    () => Navigator.push(
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
              ),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.1),
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
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
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
                            await AppSettings.openAppSettings(
                              type: AppSettingsType.wifi,
                            );
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
                            await AppSettings.openAppSettings(
                              type: AppSettingsType.wireless,
                            );
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
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.error.withOpacity(0.1),
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
                          return Theme.of(
                            context,
                          ).colorScheme.error.withOpacity(0.2);
                        }
                        if (states.contains(MaterialState.hovered)) {
                          return Theme.of(
                            context,
                          ).colorScheme.error.withOpacity(0.15);
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        child: Column(
          children:
              announcements
                  .map(
                    (announcement) =>
                        _buildAnnouncementItem(announcement, isDarkMode),
                  )
                  .toList(),
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
      return isDarkMode
          ? Colors.white
          : Colors.black; // Default color based on theme
    }

    if (colorString.trim() == 'red') {
      return isDarkMode ? Colors.red[300]! : Colors.red;
    } else if (colorString.trim() == 'blue') {
      return isDarkMode ? Colors.blue[300]! : Colors.blue;
    }

    if (colorString.startsWith('#') &&
        (colorString.length == 7 || colorString.length == 9)) {
      Color baseColor = Color(int.parse(colorString.replaceAll('#', '0xFF')));
      return isDarkMode
          ? baseColor.withOpacity(0.8)
          : baseColor; // Slightly lighter in dark mode
    } else {
      return isDarkMode
          ? Colors.white
          : Colors.black; // Default color based on theme
    }
  }

  Widget _buildChapterShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestChaptersTab() {
    if (isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55, // Decreased from 0.6 to give more height
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => _buildChapterShimmerCard(),
      );
    }

    // Filter out invalid chapters
    final validChapters =
        latestChapters
            .where(
              (chapter) =>
                  chapter.title.isNotEmpty && chapter.seriesTitle.isNotEmpty,
            )
            .toList();

    if (validChapters.isEmpty) {
      return const Center(child: Text('No chapters available'));
    }

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
        itemCount: validChapters.length,
        itemBuilder:
            (context, index) => ChapterCard(
              chapter: validChapters[index],
              onTap: () async {
                final fullUrl = await _ensureFullUrl(validChapters[index].url);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(url: fullUrl),
                  ),
                );
              },
            ),
      ),
    );
  }

  Future<String> _ensureFullUrl(String url) async {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Get the current server from settings
    final settingsService = SettingsService();
    final baseUrl =
        await settingsService.getCurrentServer() ?? 'https://ln.hako.vn';

    // Remove any leading slash to prevent double slashes
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanPath';
  }

  Widget _buildNovelShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

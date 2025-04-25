import 'package:docln/services/update_service.dart';
import 'package:flutter/material.dart';
import '../screens/LibraryScreen.dart';
import '../screens/SettingsScreen.dart';
import '../screens/widgets/update_dialog.dart';
import 'dart:ui';
import '../services/performance_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasUnsavedSettings = false;
  final _settingsKey = GlobalKey<SettingsScreenState>();
  bool _isCheckingForUpdates = false;

  Future<void> _optimizeScreen() async {
    await PerformanceService.optimizeScreen('HomeScreen');
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _optimizeScreen();
    _screens = [
      LibraryScreen(),
      const Center(child: Text('Search')),
      const Center(child: Text('Bookmarks')),
      const Center(child: Text('History')),
      SettingsScreen(
        key: _settingsKey,
        onSettingsChanged: (hasChanges) {
          setState(() => _hasUnsavedSettings = hasChanges);
        },
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for updates only once after dependencies are ready
    if (!_isCheckingForUpdates) {
      _isCheckingForUpdates = true;
      // Wait for the next frame to ensure everything is properly laid out
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _checkForUpdates();
          }
        });
      });
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateInfo = await UpdateService.checkForUpdates();
      if (updateInfo != null && mounted && context.mounted) {
        // Use Navigator instead of showGeneralDialog
        await Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            barrierDismissible: false,
            barrierColor: Colors.black54,
            pageBuilder: (context, animation, secondaryAnimation) {
              return WillPopScope(
                onWillPop: () async => false,
                child: SafeArea(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                      child: UpdateDialog(updateInfo: updateInfo),
                    ),
                  ),
                ),
              );
            },
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  Future<bool> _handlePopWithResult() async {
    if (_selectedIndex == 4 && _hasUnsavedSettings) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Unsaved Changes'),
                ],
              ),
              content: const Text(
                'Do you want to save your changes before leaving?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Discard'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context, true);
                    await _settingsKey.currentState?.saveSettings();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
      );

      if (result == null) return false; // Cancel navigation
      if (result) {
        // User chose to save
        return true;
      }
      // User chose to discard
      setState(() => _hasUnsavedSettings = false);
      return true;
    }
    return true; // Allow pop if no unsaved changes
  }

  Future<bool?> _showUnsavedChangesDialog(int newIndex) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Unsaved Changes'),
              ],
            ),
            content: const Text(
              'Do you want to save your changes before leaving?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _settingsKey.currentState?.revertSettings(); // Add this line
                  Navigator.pop(context, false);
                  setState(() {
                    _selectedIndex = newIndex;
                    _hasUnsavedSettings = false;
                  });
                },
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await _settingsKey.currentState?.saveSettings();
                  if (context.mounted) {
                    Navigator.pop(context, true);
                    setState(() {
                      _selectedIndex = newIndex;
                      _hasUnsavedSettings = false;
                    });
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    return result;
  }

  void _onTabSelected(int index) async {
    print(
      'Tab selected: $index, Current: $_selectedIndex, Has unsaved: $_hasUnsavedSettings',
    ); // Debug
    if (_selectedIndex == 4 && _hasUnsavedSettings && index != 4) {
      await _showUnsavedChangesDialog(index);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (_selectedIndex == 4 && _hasUnsavedSettings) {
          final result = await _showUnsavedChangesDialog(_selectedIndex);
          if (result == true && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(
                  0.2,
                ),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onTabSelected,
              type: BottomNavigationBarType.fixed,
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              selectedItemColor: Colors.deepOrange,
              unselectedItemColor:
                  isDarkMode ? Colors.grey[400] : Colors.grey[600],
              showSelectedLabels: false,
              showUnselectedLabels: false,
              elevation: 0,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              iconSize: 24,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_book_outlined),
                  activeIcon: Icon(Icons.menu_book),
                  label: 'Library',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_outlined),
                  activeIcon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark_border_outlined),
                  activeIcon: Icon(Icons.bookmark),
                  label: 'Bookmarks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

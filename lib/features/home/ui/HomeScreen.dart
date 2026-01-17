import 'package:docln/core/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:docln/features/library/ui/LibraryScreen.dart';
import 'package:docln/features/search/ui/SearchScreen.dart';
import 'package:docln/features/settings/ui/SettingsScreen.dart';
import 'package:docln/features/library/ui/BookmarksScreen.dart';
import 'package:docln/features/library/ui/HistoryScreen.dart';
import 'package:docln/core/widgets/update_dialog.dart';
import 'dart:ui';
import 'package:docln/core/services/performance_service.dart';

// Create a service for handling navigation
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Reference to the HomeScreen state
  _HomeScreenState? _homeScreenState;

  // Register the HomeScreen state
  void registerHomeScreen(_HomeScreenState state) {
    _homeScreenState = state;
  }

  // Navigate to a specific tab
  void navigateToTab(int index) {
    _homeScreenState?.navigateToTab(index);
  }
}

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

  // Add a method to change the selected index from outside
  void navigateToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      _onTabSelected(index);
    }
  }

  // Expose the current index for external access
  int get selectedIndex => _selectedIndex;

  Future<void> _optimizeScreen() async {
    await PerformanceService.optimizeScreen('HomeScreen');
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _optimizeScreen();
    // Register this state with the NavigationService
    NavigationService().registerHomeScreen(this);
    _screens = [
      LibraryScreen(),
      const SearchScreen(),
      const BookmarksScreen(),
      const HistoryScreen(),
      SettingsScreen(
        key: _settingsKey,
        onSettingsChanged: (hasChanges) {
          setState(() => _hasUnsavedSettings = hasChanges);
        },
      ),
    ];
  }

  @override
  void dispose() {
    // Unregister from the NavigationService when disposed
    if (NavigationService()._homeScreenState == this) {
      NavigationService()._homeScreenState = null;
    }
    super.dispose();
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
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
        builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Unsaved Changes'),
          ],
        ),
        content: const Text('Do you want to save your changes before leaving?'),
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
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );
              }
              return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: isDarkMode
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: isDarkMode
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Theme.of(context).colorScheme.primaryContainer,
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.2),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border_outlined),
                selectedIcon: Icon(Icons.bookmark),
                label: 'Bookmarks',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

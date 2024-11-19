import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_services.dart';
import '../screens/LibraryScreen.dart';
import '../screens/webview_screen.dart';
import '../screens/SettingsScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasUnsavedSettings = false;
  final _settingsKey = GlobalKey<SettingsScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
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
          content: const Text('Do you want to save your changes before leaving?'),
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
              _settingsKey.currentState?.revertSettings();  // Add this line
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
    print('Tab selected: $index, Current: $_selectedIndex, Has unsaved: $_hasUnsavedSettings'); // Debug
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
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onTabSelected,
                type: BottomNavigationBarType.fixed,
                backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
                selectedItemColor: Colors.deepOrange,
                unselectedItemColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                showSelectedLabels: false,
                showUnselectedLabels: false,
                elevation: 0,
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
      ),
    );
  }
}
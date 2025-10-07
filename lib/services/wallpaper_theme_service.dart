import 'package:flutter/material.dart';
import 'wallpaper_color_extractor.dart';

class WallpaperThemeService extends ChangeNotifier {
  static final WallpaperThemeService _instance = WallpaperThemeService._internal();
  
  WallpaperThemeService._internal() {
    _extractor.addListener(_onColorsChanged);
  }
  
  factory WallpaperThemeService() => _instance;
  static WallpaperThemeService get instance => _instance;
  
  final WallpaperColorExtractor _extractor = WallpaperColorExtractor.instance;
  bool _useWallpaperColors = false;
  
  // Getters
  bool get useWallpaperColors => _useWallpaperColors;
  bool get hasWallpaperColors => _extractor.lightColorScheme != null;
  WallpaperColorExtractor get extractor => _extractor;
  
  void _onColorsChanged() {
    notifyListeners();
  }
  
  /// Enable or disable wallpaper-based theming
  void setUseWallpaperColors(bool use) {
    if (_useWallpaperColors != use) {
      _useWallpaperColors = use;
      notifyListeners();
    }
  }
  
  /// Get the current light theme data
  ThemeData getLightTheme({ThemeData? fallback}) {
    if (_useWallpaperColors && _extractor.lightColorScheme != null) {
      return ThemeData(
        colorScheme: _extractor.lightColorScheme!,
        useMaterial3: true,
        brightness: Brightness.light,
      );
    }
    return fallback ?? ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }
  
  /// Get the current dark theme data
  ThemeData getDarkTheme({ThemeData? fallback}) {
    if (_useWallpaperColors && _extractor.darkColorScheme != null) {
      return ThemeData(
        colorScheme: _extractor.darkColorScheme!,
        useMaterial3: true,
        brightness: Brightness.dark,
      );
    }
    return fallback ?? ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );
  }
  
  /// Extract colors from a new wallpaper image
  Future<bool> updateWallpaperColors() async {
    return await _extractor.extractColorsFromImage();
  }
  
  /// Extract colors from an asset wallpaper
  Future<bool> updateWallpaperColorsFromAsset(String assetPath) async {
    return await _extractor.extractColorsFromAsset(assetPath);
  }
  
  /// Clear wallpaper colors and disable wallpaper theming
  void clearWallpaperColors() {
    _extractor.clearCache();
    _useWallpaperColors = false;
    notifyListeners();
  }
  
  /// Get extracted color preview for UI
  List<Color> getColorPreview() {
    return _extractor.getColorPreview();
  }
  
  @override
  void dispose() {
    _extractor.removeListener(_onColorsChanged);
    super.dispose();
  }
}

/// Example main app widget showing how to integrate wallpaper theming
class MaterialYouWallpaperApp extends StatelessWidget {
  const MaterialYouWallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WallpaperThemeService.instance,
      builder: (context, child) {
        final themeService = WallpaperThemeService.instance;
        
        return MaterialApp(
          title: 'Material You Wallpaper Demo',
          theme: themeService.getLightTheme(),
          darkTheme: themeService.getDarkTheme(),
          home: const WallpaperThemeDemo(),
        );
      },
    );
  }
}

/// Demo screen showing wallpaper theming controls
class WallpaperThemeDemo extends StatefulWidget {
  const WallpaperThemeDemo({super.key});

  @override
  State<WallpaperThemeDemo> createState() => _WallpaperThemeDemoState();
}

class _WallpaperThemeDemoState extends State<WallpaperThemeDemo> {
  final WallpaperThemeService _themeService = WallpaperThemeService.instance;
  final WallpaperColorExtractor _extractor = WallpaperColorExtractor.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material You from Wallpaper'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wallpaper theming controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallpaper Theming',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Use Wallpaper Colors'),
                    subtitle: Text(_themeService.hasWallpaperColors
                        ? 'Colors extracted from wallpaper'
                        : 'Select a wallpaper to extract colors'),
                    value: _themeService.useWallpaperColors,
                    onChanged: _themeService.hasWallpaperColors
                        ? _themeService.setUseWallpaperColors
                        : null,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _extractor.isExtracting
                              ? null
                              : () async {
                                  final success = await _themeService.updateWallpaperColors();
                                  if (success && mounted) {
                                    _themeService.setUseWallpaperColors(true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Colors extracted successfully!'),
                                      ),
                                    );
                                  } else if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('❌ Failed to extract colors'),
                                      ),
                                    );
                                  }
                                },
                          icon: _extractor.isExtracting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.image),
                          label: Text(_extractor.isExtracting
                              ? 'Extracting...'
                              : 'Select Wallpaper'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          _themeService.clearWallpaperColors();
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear Colors',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Color preview
          if (_themeService.getColorPreview().isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracted Colors',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _themeService.getColorPreview().map((color) {
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
          
          // Material 3 component showcase
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Material You Components',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  // Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Primary'),
                      ),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Filled'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Outlined'),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Text'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Chips
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: const Text('Chip'),
                        onDeleted: () {},
                      ),
                      ActionChip(
                        label: const Text('Action'),
                        onPressed: () {},
                      ),
                      FilterChip(
                        label: const Text('Filter'),
                        selected: true,
                        onSelected: (value) {},
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Cards with different colors
                  Row(
                    children: [
                      Expanded(
                        child: Card.filled(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Primary Container',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Secondary Container',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Example: Navigate to wallpaper colors screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const WallpaperColorsScreen(),
            ),
          );
        },
        icon: const Icon(Icons.palette),
        label: const Text('Color Details'),
      ),
    );
  }
}

// Import the wallpaper colors screen
class WallpaperColorsScreen extends StatelessWidget {
  const WallpaperColorsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    // This would be your wallpaper_colors_screen.dart content
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper Color Details'),
      ),
      body: const Center(
        child: Text('Detailed wallpaper color extraction UI would go here'),
      ),
    );
  }
}
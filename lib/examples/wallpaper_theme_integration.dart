// Example integration with your existing app
// Add this to your main.dart or theme management

import 'package:flutter/material.dart';
import '../services/wallpaper_theme_service.dart';

class AppWithWallpaperTheming extends StatelessWidget {
  const AppWithWallpaperTheming({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WallpaperThemeService.instance,
      builder: (context, child) {
        final themeService = WallpaperThemeService.instance;
        
        return MaterialApp(
          title: 'DocLN - Light Novel Reader',
          
          // Use wallpaper-based themes or fallback to your existing themes
          theme: themeService.getLightTheme(
            fallback: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue, // Your existing theme
              ),
              useMaterial3: true,
            ),
          ),
          
          darkTheme: themeService.getDarkTheme(
            fallback: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
          ),
          
          // Your existing app structure
          home: const YourExistingHomeScreen(),
          
          // Add routes for wallpaper theming if needed
          routes: {
            '/wallpaper-theme': (context) => const WallpaperThemeDemo(),
          },
        );
      },
    );
  }
}

// Example settings integration
class ThemeSettingsSection extends StatefulWidget {
  const ThemeSettingsSection({super.key});

  @override
  State<ThemeSettingsSection> createState() => _ThemeSettingsSectionState();
}

class _ThemeSettingsSectionState extends State<ThemeSettingsSection> {
  final WallpaperThemeService _themeService = WallpaperThemeService.instance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material You Theming',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        
        const SizedBox(height: 8),
        
        ListenableBuilder(
          listenable: _themeService,
          builder: (context, child) {
            return SwitchListTile(
              title: const Text('Use Wallpaper Colors'),
              subtitle: Text(_themeService.hasWallpaperColors
                  ? 'Extract colors from your wallpaper'
                  : 'Tap to select a wallpaper image'),
              value: _themeService.useWallpaperColors,
              onChanged: _themeService.hasWallpaperColors
                  ? _themeService.setUseWallpaperColors
                  : null,
            );
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.palette),
          title: const Text('Select Wallpaper'),
          subtitle: const Text('Extract Material You colors'),
          trailing: ListenableBuilder(
            listenable: _themeService.extractor,
            builder: (context, child) {
              return _themeService.extractor.isExtracting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right);
            },
          ),
          onTap: () async {
            final success = await _themeService.updateWallpaperColors();
            if (success && mounted) {
              _themeService.setUseWallpaperColors(true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎨 Wallpaper colors applied!'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        
        if (_themeService.getColorPreview().isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Extracted Colors:'),
                const SizedBox(height: 8),
                Row(
                  children: _themeService
                      .getColorPreview()
                      .take(5)
                      .map((color) => Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Placeholder for your existing home screen
class YourExistingHomeScreen extends StatelessWidget {
  const YourExistingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Your existing home screen implementation
    return Scaffold(
      appBar: AppBar(
        title: const Text('DocLN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () {
              Navigator.pushNamed(context, '/wallpaper-theme');
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Your existing app content'),
      ),
    );
  }
}
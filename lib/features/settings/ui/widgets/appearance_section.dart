import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:docln/features/settings/logic/appearance_settings_provider.dart';
import 'package:docln/core/services/theme_services.dart';
import 'package:docln/core/widgets/custom_toast.dart';

class AppearanceSection extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const AppearanceSection({super.key, this.onSettingsChanged});

  @override
  State<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<AppearanceSection> {
  @override
  Widget build(BuildContext context) {
    // We consume AppearanceSettingsProvider for Dark Mode and Text Size
    return Consumer<AppearanceSettingsProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Dark Mode
            _buildModernSwitchTile(
              context: context,
              title: 'Dark Mode',
              subtitle: 'Switch between light and dark theme',
              icon: Icons.dark_mode_rounded,
              value: provider.isDarkMode,
              onChanged: (value) {
                provider.setDarkMode(value);
                widget.onSettingsChanged?.call();
              },
            ),
            // Text Size
            _buildModernSliderTile(
              context: context,
              title: 'Text Size',
              subtitle: 'Adjust the size of text in the app',
              icon: Icons.text_fields_rounded,
              value: provider.textSize,
              onChanged: (value) {
                provider.setTextSize(
                  value,
                  onPreview: (newSize) {
                    final themeService = Provider.of<ThemeServices>(
                      context,
                      listen: false,
                    );
                    themeService.previewTextSize(newSize);
                  },
                );
                widget.onSettingsChanged?.call();
              },
            ),
            // Wallpaper Colors (managed directly by ThemeServices)
            _buildWallpaperThemeSettings(context),
          ],
        );
      },
    );
  }

  Widget _buildModernSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colorScheme.secondary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }

  Widget _buildModernSliderTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required Function(double) onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.secondary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const Text('A', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: value.clamp(12.0, 24.0),
                        min: 12.0,
                        max: 24.0,
                        divisions: 12,
                        label: value.round().toString(),
                        onChanged: onChanged,
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Preview Text', style: TextStyle(fontSize: value)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWallpaperThemeSettings(BuildContext context) {
    // This widget interacts with ThemeServices directly as per original implementation
    // because "Material You" settings seem to be applied immediately.
    // However, we should consider if we want to make them transactional too.
    // For now, mirroring original behavior.

    // We use Consumer<ThemeServices> to rebuild when theme settings change
    return Consumer<ThemeServices>(
      builder: (context, themeService, child) {
        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.palette_rounded, color: colorScheme.primary),
              ),
              title: const Text(
                'Material You from Wallpaper',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                themeService.hasWallpaperColors
                    ? (themeService
                              .wallpaperThemeService
                              .extractor
                              .isUsingSystemWallpaper
                          ? 'Using system wallpaper colors'
                          : 'Using custom image colors')
                    : 'Extract colors from wallpaper',
              ),
              trailing: Switch.adaptive(
                value: themeService.useWallpaperColors,
                onChanged: themeService.hasWallpaperColors
                    ? (value) async {
                        await themeService.setUseWallpaperColors(value);
                        // No need for explicit setState if consuming ThemeServices
                        // But we might want to notify SettingsScreen about "changes" if we want to consistency check
                        // Currently ignored in original implementation regarding "Unsaved Changes" flag?
                      }
                    : null,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        CustomToast.show(
                          context,
                          'Extracting from system wallpaper...',
                        );
                        final result = await themeService
                            .updateWallpaperColorsFromSystem();
                        if (result) {
                          CustomToast.show(
                            context,
                            'System wallpaper colors extracted!',
                          );
                        } else {
                          CustomToast.show(
                            context,
                            'System wallpaper not supported on this device',
                          );
                        }
                      },
                      icon: const Icon(Icons.wallpaper, size: 18),
                      label: const Text(
                        'System',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        CustomToast.show(context, 'Selecting wallpaper...');
                        final result = await themeService
                            .updateWallpaperColors();
                        if (result) {
                          CustomToast.show(
                            context,
                            'Colors extracted successfully!',
                          );
                        } else {
                          CustomToast.show(context, 'Failed to extract colors');
                        }
                      },
                      icon: const Icon(Icons.image, size: 18),
                      label: const Text(
                        'Pick Image',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (themeService.hasWallpaperColors) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        themeService.clearWallpaperColors();
                        CustomToast.show(context, 'Wallpaper colors cleared');
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear wallpaper colors',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (themeService.hasWallpaperColors)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: themeService.getWallpaperColorPreview().map((
                      color,
                    ) {
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            // Simplistic border radius - first and last items get corners
                            // We don't have index easily here, just do generic.
                            // Wait, map doesn't give index.
                            // Just leaving it square inside is fine, parent clips?
                            // Parent doesn't clip.
                            // Simplified for now.
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

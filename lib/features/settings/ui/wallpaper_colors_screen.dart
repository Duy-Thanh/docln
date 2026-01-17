import 'package:flutter/material.dart';
import 'package:docln/core/services/wallpaper_color_extractor.dart';

class WallpaperColorsScreen extends StatefulWidget {
  const WallpaperColorsScreen({Key? key}) : super(key: key);

  @override
  State<WallpaperColorsScreen> createState() => _WallpaperColorsScreenState();
}

class _WallpaperColorsScreenState extends State<WallpaperColorsScreen> {
  final WallpaperColorExtractor _extractor = WallpaperColorExtractor.instance;

  @override
  void initState() {
    super.initState();
    _extractor.addListener(_onColorsChanged);
  }

  @override
  void dispose() {
    _extractor.removeListener(_onColorsChanged);
    super.dispose();
  }

  void _onColorsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material You from Wallpaper'),
        backgroundColor: _extractor.dominantColor,
        foregroundColor: _extractor.dominantColor != null
            ? ThemeData.estimateBrightnessForColor(_extractor.dominantColor!) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Extract Colors from Wallpaper',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _extractor.isExtracting
                                ? null
                                : () async {
                                    await _extractor
                                        .extractColorsFromSystemWallpaper();
                                  },
                            icon: _extractor.isExtracting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wallpaper),
                            label: Text(
                              _extractor.isExtracting
                                  ? 'Extracting...'
                                  : 'System Wallpaper',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _extractor.isExtracting
                                ? null
                                : () async {
                                    await _extractor.extractColorsFromImage();
                                  },
                            icon: _extractor.isExtracting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.image),
                            label: Text(
                              _extractor.isExtracting
                                  ? 'Extracting...'
                                  : 'Pick Image',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            _extractor.clearCache();
                          },
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Clear Cache',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Color source indicator
            if (_extractor.extractedColors.isNotEmpty)
              Card(
                color: _extractor.isUsingSystemWallpaper
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        _extractor.isUsingSystemWallpaper
                            ? Icons.wallpaper
                            : Icons.image,
                        size: 20,
                        color: _extractor.isUsingSystemWallpaper
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _extractor.isUsingSystemWallpaper
                            ? 'Using System Wallpaper Colors'
                            : 'Using Custom Image Colors',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _extractor.isUsingSystemWallpaper
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Color preview
            if (_extractor.extractedColors.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extracted Colors',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _extractor.getColorPreview().map((color) {
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Theme preview
            if (_extractor.lightColorScheme != null)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Material You Theme Preview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Row(
                            children: [
                              // Light theme preview
                              Expanded(
                                child: _buildThemePreview(
                                  'Light Theme',
                                  _extractor.lightColorScheme!,
                                  Brightness.light,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Dark theme preview
                              Expanded(
                                child: _buildThemePreview(
                                  'Dark Theme',
                                  _extractor.darkColorScheme!,
                                  Brightness.dark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemePreview(
    String title,
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    return Theme(
      data: ThemeData(colorScheme: colorScheme, useMaterial3: true),
      child: Builder(
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Primary button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('Primary'),
                  ),
                ),

                const SizedBox(height: 4),

                // Secondary button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.outline),
                      foregroundColor: colorScheme.primary,
                    ),
                    child: const Text('Secondary'),
                  ),
                ),

                const SizedBox(height: 8),

                // Color swatches
                Expanded(
                  child: Column(
                    children: [
                      _buildColorSwatch('Primary', colorScheme.primary),
                      _buildColorSwatch('Secondary', colorScheme.secondary),
                      _buildColorSwatch('Tertiary', colorScheme.tertiary),
                      _buildColorSwatch('Error', colorScheme.error),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatch(String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color:
                  ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

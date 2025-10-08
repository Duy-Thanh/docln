import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dynamic_color/dynamic_color.dart';

class WallpaperColorExtractor extends ChangeNotifier {
  static final WallpaperColorExtractor _instance =
      WallpaperColorExtractor._internal();

  WallpaperColorExtractor._internal();

  factory WallpaperColorExtractor() => _instance;

  static WallpaperColorExtractor get instance => _instance;

  ColorScheme? _lightColorScheme;
  ColorScheme? _darkColorScheme;
  Color? _dominantColor;
  List<Color> _extractedColors = [];
  bool _isExtracting = false;
  String? _lastImageHash;
  bool _isUsingSystemWallpaper = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Getters
  ColorScheme? get lightColorScheme => _lightColorScheme;
  ColorScheme? get darkColorScheme => _darkColorScheme;
  Color? get dominantColor => _dominantColor;
  List<Color> get extractedColors => _extractedColors;
  bool get isExtracting => _isExtracting;
  bool get isUsingSystemWallpaper => _isUsingSystemWallpaper;

  /// Extract colors from system wallpaper (Android 12+ / iOS)
  Future<bool> extractColorsFromSystemWallpaper() async {
    _isExtracting = true;
    notifyListeners();

    try {
      print('🎨 Extracting colors from system wallpaper...');

      // Try to get system color palette
      final corePalette = await DynamicColorPlugin.getCorePalette();

      if (corePalette != null) {
        print('✅ System wallpaper colors available!');

        // Generate color schemes from system palette
        _lightColorScheme = corePalette.toColorScheme(
          brightness: Brightness.light,
        );
        _darkColorScheme = corePalette.toColorScheme(
          brightness: Brightness.dark,
        );

        // Extract dominant color (primary)
        _dominantColor = _lightColorScheme!.primary;

        // Build color preview from the scheme
        _extractedColors = [
          _lightColorScheme!.primary,
          _lightColorScheme!.secondary,
          _lightColorScheme!.tertiary,
          _lightColorScheme!.primaryContainer,
          _lightColorScheme!.secondaryContainer,
          _lightColorScheme!.tertiaryContainer,
        ];

        _lastImageHash =
            'system_wallpaper_${DateTime.now().millisecondsSinceEpoch}';
        _isUsingSystemWallpaper = true;

        print(
          '🎨 Extracted ${_extractedColors.length} colors from system wallpaper',
        );
        print('   Primary: ${_lightColorScheme!.primary}');
        print('   Secondary: ${_lightColorScheme!.secondary}');
        print('   Tertiary: ${_lightColorScheme!.tertiary}');

        return true;
      } else {
        print('⚠️ System wallpaper colors not available on this device');
        print('   (Requires Android 12+ or supported iOS version)');
        return false;
      }
    } catch (e) {
      print('❌ Error extracting system wallpaper colors: $e');
      return false;
    } finally {
      _isExtracting = false;
      notifyListeners();
    }
  }

  /// Extract colors from a selected image (wallpaper)
  Future<bool> extractColorsFromImage({File? imageFile}) async {
    _isExtracting = true;
    notifyListeners();

    try {
      print('🖼️ Starting image color extraction...');

      File? selectedImage = imageFile;

      // If no image provided, let user select one
      if (selectedImage == null) {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50, // Reduce quality for faster processing
        );

        if (pickedFile == null) {
          print('❌ No image selected');
          return false;
        }

        selectedImage = File(pickedFile.path);
      }

      // Read image bytes
      Uint8List imageBytes = await selectedImage.readAsBytes();

      // Create a hash to check if image changed
      String imageHash = imageBytes.hashCode.toString();

      // Check if we already processed this image
      if (imageHash == _lastImageHash && _lightColorScheme != null) {
        print('✅ Using cached colors for current image');
        _isExtracting = false;
        notifyListeners();
        return true;
      }

      // Extract colors using palette generator
      PaletteGenerator palette = await _generatePalette(imageBytes);

      // Process extracted colors
      await _processExtractedColors(palette);

      _lastImageHash = imageHash;
      _isUsingSystemWallpaper = false; // Manual image selection
      print('✅ Successfully extracted colors from image');

      return true;
    } catch (e) {
      print('❌ Error extracting image colors: $e');
      return false;
    } finally {
      _isExtracting = false;
      notifyListeners();
    }
  }

  /// Extract colors from predefined wallpaper asset
  Future<bool> extractColorsFromAsset(String assetPath) async {
    _isExtracting = true;
    notifyListeners();

    try {
      print('🖼️ Starting asset color extraction: $assetPath');

      // Load asset
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Create a hash to check if asset changed
      String assetHash = '$assetPath:${bytes.hashCode}';

      // Check if we already processed this asset
      if (assetHash == _lastImageHash && _lightColorScheme != null) {
        print('✅ Using cached colors for current asset');
        _isExtracting = false;
        notifyListeners();
        return true;
      }

      // Extract colors using palette generator
      PaletteGenerator palette = await _generatePalette(bytes);

      // Process extracted colors
      await _processExtractedColors(palette);

      _lastImageHash = assetHash;
      _isUsingSystemWallpaper = false; // Asset-based extraction
      print('✅ Successfully extracted colors from asset');

      return true;
    } catch (e) {
      print('❌ Error extracting asset colors: $e');
      return false;
    } finally {
      _isExtracting = false;
      notifyListeners();
    }
  }

  /// Generate color palette from image bytes
  Future<PaletteGenerator> _generatePalette(Uint8List imageBytes) async {
    return await PaletteGenerator.fromImageProvider(
      MemoryImage(imageBytes),
      size: const Size(200, 200), // Resize for faster processing
      maximumColorCount: 16,
    );
  }

  /// Process extracted colors and create Material You color schemes
  Future<void> _processExtractedColors(PaletteGenerator palette) async {
    try {
      // Extract dominant and accent colors
      Color? primary =
          palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.darkVibrantColor?.color ??
          palette.dominantColor?.color;

      if (primary == null) {
        print('Could not extract primary color from wallpaper');
        return;
      }

      _dominantColor = primary;

      // Collect all extracted colors
      _extractedColors = [
        if (palette.vibrantColor != null) palette.vibrantColor!.color,
        if (palette.lightVibrantColor != null) palette.lightVibrantColor!.color,
        if (palette.darkVibrantColor != null) palette.darkVibrantColor!.color,
        if (palette.mutedColor != null) palette.mutedColor!.color,
        if (palette.lightMutedColor != null) palette.lightMutedColor!.color,
        if (palette.darkMutedColor != null) palette.darkMutedColor!.color,
        if (palette.dominantColor != null) palette.dominantColor!.color,
      ];

      // Generate Material You color schemes using the extracted primary color
      _lightColorScheme = ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      );

      _darkColorScheme = ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      );

      print('🎨 Generated color schemes from wallpaper:');
      print('   Primary: ${primary.toString()}');
      print(
        '   Light scheme primary: ${_lightColorScheme!.primary.toString()}',
      );
      print('   Dark scheme primary: ${_darkColorScheme!.primary.toString()}');
      print('   Extracted ${_extractedColors.length} total colors');
    } catch (e) {
      print('Error processing extracted colors: $e');
      rethrow;
    }
  }

  /// Clear cached colors (useful when wallpaper changes)
  void clearCache() {
    _lightColorScheme = null;
    _darkColorScheme = null;
    _dominantColor = null;
    _extractedColors.clear();
    _lastImageHash = null;
    _isUsingSystemWallpaper = false;
    notifyListeners();
    print('🗑️ Cleared wallpaper color cache');
  }

  /// Get a preview of extracted colors for UI display
  List<Color> getColorPreview() {
    return _extractedColors.take(6).toList();
  }
}

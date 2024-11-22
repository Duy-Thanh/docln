import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String currentVersion;
  final int currentBuildNumber;
  final String newVersion;
  final DateTime releaseDate;
  final String releaseNotes;
  final String downloadUrl;
  final int apkSize;

  UpdateInfo({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.newVersion,
    required this.releaseDate,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.apkSize,
  });
}

class UpdateService {
  static const String GITHUB_API_URL = 'https://api.github.com/repos/Duy-Thanh/docln/releases/latest';
  static const String LAST_CHECK_KEY = 'last_update_check';
  static const Duration CHECK_INTERVAL = Duration(minutes: 15);

  // Convert release date format to version number
  static String _getReleaseVersion(String releaseTag) {
    // release_2024.11.20_16-06 -> 2024.11.20
    try {
      if (releaseTag.startsWith('release_')) {
        final parts = releaseTag.split('release_')[1].split('_');
        return parts[0]; // Returns 2024.11.20
      }
      return releaseTag;
    } catch (e) {
      print('Error converting release tag: $e');
      return '0.0.0';
    }
  }

  static bool _isNewerVersion(String currentVersion, String latestReleaseTag) {
    try {
      final latestVersion = _getReleaseVersion(latestReleaseTag);
      
      // Split versions into parts and compare
      final currentParts = currentVersion.split('.')
          .map(int.parse).toList();
      final latestParts = latestVersion.split('.')
          .map(int.parse).toList();

      // Compare year
      if (latestParts[0] != currentParts[0]) {
        return latestParts[0] > currentParts[0];
      }
      // Compare month
      if (latestParts[1] != currentParts[1]) {
        return latestParts[1] > currentParts[1];
      }
      // Compare day
      return latestParts[2] > currentParts[2];
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }

  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(LAST_CHECK_KEY) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now - lastCheck < CHECK_INTERVAL.inMilliseconds) {
        return null;
      }

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);

      // Get latest release from GitHub
      final response = await http.get(
        Uri.parse(GITHUB_API_URL),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestReleaseTag = data['tag_name'].toString();
        final releaseNotes = data['body'] ?? '';
        
        // Find the APK asset
        final assets = List<Map<String, dynamic>>.from(data['assets']);
        final apkAsset = assets.firstWhere(
          (asset) => asset['name'].toString().endsWith('.apk'),
          orElse: () => {},
        );
        
        if (apkAsset.isEmpty) return null;

        // Check if the latest version is newer
        if (_isNewerVersion(currentVersion, latestReleaseTag)) {
          final downloadUrl = apkAsset['browser_download_url'];
          final releaseDate = DateTime.parse(data['published_at']);

          // Save last check time
          await prefs.setInt(LAST_CHECK_KEY, now);

          return UpdateInfo(
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
            newVersion: latestReleaseTag,
            releaseDate: releaseDate,
            releaseNotes: releaseNotes,
            downloadUrl: downloadUrl,
            apkSize: (apkAsset['size'] as int) ~/ 1048576,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error checking for updates: $e');
      return null;
    }
  }
}


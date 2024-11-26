import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

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
  static DateTime _parseReleaseDate(String releaseTag) {
    try {
      // Parse release_2024.11.22_09-24
      final parts = releaseTag.split('release_')[1].split('_');
      final date = parts[0]; // 2024.11.22
      final time = parts[1].replaceAll('-', ':'); // 09:24
      return DateTime.parse('${date.replaceAll('.', '-')}T$time:00Z');
    } catch (e) {
      print('Error parsing release date: $e');
      return DateTime(1970); // Return very old date on error
    }
  }

  // Convert app version to comparable date
  static DateTime _parseAppVersion(String version) {
    try {
      // Parse 2024.11.20
      final parts = version.split('.');
      return DateTime(
        int.parse(parts[0]), // year
        int.parse(parts[1]), // month
        int.parse(parts[2]), // day
      );
    } catch (e) {
      print('Error parsing app version: $e');
      return DateTime(1970); // Return very old date on error
    }
  }

  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // 2024.11.20
      
      print('Current app version: $currentVersion'); // Debug print

      // Get latest release from GitHub
      final response = await http.get(
        Uri.parse(GITHUB_API_URL),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('GitHub API Response: ${response.body}'); // Debug print
        
        final latestTag = data['tag_name'].toString();
        print('Latest GitHub tag: $latestTag'); // Debug print

        // Simple date comparison
        final currentParts = currentVersion.split('.');
        final currentDate = DateTime(
          int.parse(currentParts[0]), // year
          int.parse(currentParts[1]), // month
          int.parse(currentParts[2])  // day
        );

        final tagParts = latestTag.split('release_')[1].split('_')[0].split('.');
        final releaseDate = DateTime(
          int.parse(tagParts[0]), // year
          int.parse(tagParts[1]), // month
          int.parse(tagParts[2])  // day
        );

        print('Current date: $currentDate'); // Debug print
        print('Release date: $releaseDate'); // Debug print
        print('Is update needed: ${releaseDate.isAfter(currentDate)}'); // Debug print

        if (releaseDate.isAfter(currentDate)) {
          final releaseNotes = data['body'] ?? '';
          final assets = List<Map<String, dynamic>>.from(data['assets']);
          final apkAsset = assets.firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => {},
          );
          
          if (apkAsset.isEmpty) {
            print('No APK asset found!'); // Debug print
            return null;
          }

          return UpdateInfo(
            currentVersion: currentVersion,
            currentBuildNumber: 1,
            newVersion: latestTag,
            releaseDate: DateTime.parse(data['published_at']),
            releaseNotes: releaseNotes,
            downloadUrl: apkAsset['browser_download_url'],
            apkSize: (apkAsset['size'] as int) ~/ 1048576,
          );
        }
      } else {
        print('GitHub API Error: ${response.statusCode}'); // Debug print
      }
      return null;
    } catch (e) {
      print('Error checking for updates: $e'); // Debug print
      return null;
    }
  }

  static Future<void> downloadAndInstallUpdate(
    UpdateInfo updateInfo,
    void Function(double) onProgress
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final apkPath = '${dir.path}/docln_update.apk';
      
      final dio = Dio(BaseOptions(
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
      ));
      
      await dio.download(
        updateInfo.downloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
        deleteOnError: true,
      );

      if (Platform.isAndroid) {
        final result = await OpenFile.open(apkPath);
        if (result.type != ResultType.done) {
          throw 'Failed to open APK: ${result.message}';
        }
      }

      Future.delayed(const Duration(minutes: 2), () {
        File(apkPath).delete().catchError((e) => print('Error cleaning up: $e'));
      });
      
    } catch (e) {
      print('Error downloading/installing update: $e');
      rethrow;
    }
  }
}


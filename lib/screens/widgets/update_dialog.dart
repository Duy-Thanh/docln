import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({
    Key? key,
    required this.updateInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(updateInfo.releaseDate);
    final screenSize = MediaQuery.of(context).size;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.85,
            maxHeight: screenSize.height * 0.7,
          ),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(Icons.system_update_rounded, 
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Update Available',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A new version was released on:',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dateStr,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'APK Size: ${updateInfo.apkSize} MB',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'What\'s new:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              updateInfo.releaseNotes,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Actions
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: () async {
                          final uri = Uri.parse(updateInfo.downloadUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.download_rounded, size: 18),
                            const SizedBox(width: 8),
                            const Text('Download'),
                          ],
                        ),
                      ),
                    ],
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
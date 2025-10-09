import 'package:flutter/material.dart';
import '../services/server_management_service.dart';
import '../services/novel_url_migration_service.dart';
import '../services/bookmark_service_v2.dart';

/// Server Diagnostic Screen
///
/// Helps users diagnose and fix server-related issues
class ServerDiagnosticScreen extends StatefulWidget {
  const ServerDiagnosticScreen({super.key});

  @override
  State<ServerDiagnosticScreen> createState() => _ServerDiagnosticScreenState();
}

class _ServerDiagnosticScreenState extends State<ServerDiagnosticScreen> {
  final ServerManagementService _serverManagement = ServerManagementService();
  final NovelUrlMigrationService _urlMigration = NovelUrlMigrationService();
  final BookmarkServiceV2 _bookmarkService = BookmarkServiceV2();

  bool _isLoading = true;
  bool _isMigrating = false;
  Map<String, dynamic>? _migrationInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _serverManagement.initialize();
      await _bookmarkService.init();

      final info = await _urlMigration.getMigrationInfo();

      setState(() {
        _migrationInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runMigration() async {
    setState(() {
      _isMigrating = true;
    });

    try {
      final success = await _urlMigration.migrateNovelUrls();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Migration completed successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload diagnostics
        await _loadDiagnostics();

        // Reload bookmarks
        await _bookmarkService.loadBookmarks();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Migration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMigrating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Server Diagnostics'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : _buildDiagnosticsView(colorScheme),
    );
  }

  Widget _buildErrorView() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading diagnostics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDiagnostics,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsView(ColorScheme colorScheme) {
    final migrationVersion = _migrationInfo?['migrationVersion'] ?? 0;
    final currentVersion = _migrationInfo?['currentVersion'] ?? 0;
    final needsMigration = _migrationInfo?['needsMigration'] ?? false;
    final totalNovels = _migrationInfo?['totalNovels'] ?? 0;
    final corruptedUrls = _migrationInfo?['corruptedUrls'] ?? 0;

    final hasProblems = needsMigration || corruptedUrls > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Card
        Card(
          color: hasProblems
              ? (colorScheme.brightness == Brightness.dark
                    ? Colors.orange.shade900
                    : Colors.orange.shade50)
              : (colorScheme.brightness == Brightness.dark
                    ? Colors.green.shade900
                    : Colors.green.shade50),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasProblems ? Icons.warning : Icons.check_circle,
                      color: hasProblems ? Colors.orange : Colors.green,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasProblems ? 'Issues Detected' : 'All Systems Normal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: hasProblems
                              ? (colorScheme.brightness == Brightness.dark
                                    ? Colors.orange.shade100
                                    : Colors.orange.shade900)
                              : (colorScheme.brightness == Brightness.dark
                                    ? Colors.green.shade100
                                    : Colors.green.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasProblems) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Your library may have corrupted novel URLs due to server changes. '
                    'Run migration to fix this issue.',
                    style: TextStyle(
                      color: colorScheme.brightness == Brightness.dark
                          ? Colors.orange.shade100
                          : Colors.orange.shade900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Current Server
        _buildInfoCard(
          colorScheme,
          icon: Icons.dns,
          title: 'Current Server',
          value: _serverManagement.currentServer,
          subtitle: 'All new novels will use this server',
        ),

        const SizedBox(height: 8),

        // Migration Status
        _buildInfoCard(
          colorScheme,
          icon: Icons.sync,
          title: 'Migration Version',
          value: '$migrationVersion / $currentVersion',
          subtitle: needsMigration ? '⚠️ Migration needed' : '✅ Up to date',
          valueColor: needsMigration ? Colors.orange : Colors.green,
        ),

        const SizedBox(height: 8),

        // Total Novels
        _buildInfoCard(
          colorScheme,
          icon: Icons.library_books,
          title: 'Bookmarked Novels',
          value: totalNovels.toString(),
          subtitle: 'Novels in your library',
        ),

        const SizedBox(height: 8),

        // Corrupted URLs
        _buildInfoCard(
          colorScheme,
          icon: Icons.broken_image,
          title: 'Corrupted URLs',
          value: corruptedUrls.toString(),
          subtitle: corruptedUrls > 0
              ? '⚠️ Novels with wrong server URLs'
              : '✅ No corrupted URLs found',
          valueColor: corruptedUrls > 0 ? Colors.red : Colors.green,
        ),

        const SizedBox(height: 24),

        // Action Buttons
        if (hasProblems) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isMigrating ? null : _runMigration,
              icon: _isMigrating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.build),
              label: Text(
                _isMigrating ? 'Migrating...' : 'Fix Corrupted URLs',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _loadDiagnostics,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Diagnostics'),
          ),
        ),

        const SizedBox(height: 24),

        // Information Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'What This Fixes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Novels stuck with endless loading spinner\n'
                  '• Corrupted URLs from server changes\n'
                  '• Library novels showing old server URLs\n'
                  '• "Failed to load" errors for saved novels',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor ?? colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

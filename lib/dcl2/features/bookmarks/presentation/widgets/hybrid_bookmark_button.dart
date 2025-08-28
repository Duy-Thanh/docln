import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../dcl2/core/utils/migration_helper.dart';
import '../../dcl2/features/bookmarks/presentation/blocs/bookmark_bloc.dart';
import '../../dcl2/features/bookmarks/presentation/blocs/bookmark_event.dart';
import '../../dcl2/features/bookmarks/presentation/blocs/bookmark_state.dart';
import '../../dcl2/core/di/injection_container.dart';
import '../services/bookmark_service.dart';

/// Hybrid bookmark widget that supports both DCL1 and DCL2
class HybridBookmarkButton extends StatefulWidget {
  final String novelId;
  final String title;
  final String? coverUrl;
  final String? author;
  final String? latestChapter;
  
  const HybridBookmarkButton({
    Key? key,
    required this.novelId,
    required this.title,
    this.coverUrl,
    this.author,
    this.latestChapter,
  }) : super(key: key);
  
  @override
  State<HybridBookmarkButton> createState() => _HybridBookmarkButtonState();
}

class _HybridBookmarkButtonState extends State<HybridBookmarkButton> {
  bool _isBookmarked = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _checkBookmarkStatus();
  }
  
  void _checkBookmarkStatus() async {
    setState(() => _isLoading = true);
    
    if (Dcl2MigrationHelper.shouldUseDcl2Bookmarks()) {
      // Use DCL2 BLoC
      if (isDcl2Available()) {
        final bloc = getIt<BookmarkBloc>();
        bloc.add(CheckBookmarkStatus(novelId: widget.novelId));
      }
    } else {
      // Use DCL1 service
      final bookmarkService = Provider.of<BookmarkService>(context, listen: false);
      setState(() {
        _isBookmarked = bookmarkService.isBookmarked(widget.novelId);
        _isLoading = false;
      });
    }
  }
  
  void _toggleBookmark() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    if (Dcl2MigrationHelper.shouldUseDcl2Bookmarks()) {
      // Use DCL2 BLoC
      if (isDcl2Available()) {
        final bloc = getIt<BookmarkBloc>();
        // Create bookmark entity
        final bookmark = createBookmarkEntity();
        bloc.add(ToggleBookmarkEvent(bookmark: bookmark));
      }
    } else {
      // Use DCL1 service
      final bookmarkService = Provider.of<BookmarkService>(context, listen: false);
      // Create LightNovel object
      final novel = createLightNovel();
      await bookmarkService.toggleBookmark(novel);
      _checkBookmarkStatus();
    }
  }
  
  /// Create DCL2 bookmark entity
  dynamic createBookmarkEntity() {
    // Import the entity class dynamically to avoid dependency issues
    try {
      // This would be replaced with actual BookmarkEntity import when DCL2 is enabled
      return {
        'id': 'bookmark_${widget.novelId}',
        'novelId': widget.novelId,
        'title': widget.title,
        'coverUrl': widget.coverUrl,
        'author': widget.author,
        'latestChapter': widget.latestChapter,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };
    } catch (e) {
      print('Error creating bookmark entity: $e');
      return null;
    }
  }
  
  /// Create DCL1 LightNovel object  
  dynamic createLightNovel() {
    // This creates a LightNovel object for DCL1 compatibility
    // Would be replaced with actual LightNovel import
    return {
      'id': widget.novelId,
      'title': widget.title,
      'coverUrl': widget.coverUrl,
      'author': widget.author,
      'latestChapter': widget.latestChapter,
    };
  }
  
  @override
  Widget build(BuildContext context) {
    if (Dcl2MigrationHelper.shouldUseDcl2Bookmarks() && isDcl2Available()) {
      // Use DCL2 BLoC
      return BlocBuilder<BookmarkBloc, BookmarkState>(
        bloc: getIt<BookmarkBloc>(),
        builder: (context, state) {
          if (state is BookmarkOperationSuccess) {
            _isBookmarked = state.isAdded;
            _isLoading = false;
          } else if (state is BookmarkLoading) {
            _isLoading = true;
          } else if (state is BookmarkError) {
            _isLoading = false;
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          
          return _buildButton();
        },
      );
    } else {
      // Use DCL1 Consumer
      return Consumer<BookmarkService>(
        builder: (context, bookmarkService, child) {
          _isBookmarked = bookmarkService.isBookmarked(widget.novelId);
          return _buildButton();
        },
      );
    }
  }
  
  Widget _buildButton() {
    return IconButton(
      onPressed: _isLoading ? null : _toggleBookmark,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.red : null,
            ),
      tooltip: _isBookmarked ? 'Remove bookmark' : 'Add bookmark',
    );
  }
}
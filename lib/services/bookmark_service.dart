import 'package:flutter/material.dart';
import 'dart:convert';
import '../modules/light_novel.dart';
import 'preferences_service.dart';

class BookmarkService extends ChangeNotifier {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;

  BookmarkService._internal();

  // Preferences service instance
  final PreferencesService _prefsService = PreferencesService();

  static const String _bookmarksKey = 'bookmarked_novels';
  List<LightNovel> _bookmarkedNovels = [];

  List<LightNovel> get bookmarkedNovels => _bookmarkedNovels;

  Future<void> init() async {
    await loadBookmarks();
  }

  Future<void> loadBookmarks() async {
    try {
      // Initialize preferences service if not already initialized
      await _prefsService.initialize();

      final String bookmarksJson = _prefsService.getString(_bookmarksKey);

      if (bookmarksJson.isNotEmpty) {
        final List<dynamic> bookmarksList = jsonDecode(bookmarksJson);
        _bookmarkedNovels =
            bookmarksList.map((json) => LightNovel.fromJson(json)).toList();
      }

      notifyListeners();
    } catch (e) {
      print('Error loading bookmarks: $e');
      _bookmarkedNovels = [];
      notifyListeners();
    }
  }

  Future<void> saveBookmarks() async {
    try {
      final String bookmarksJson = jsonEncode(
        _bookmarkedNovels.map((novel) => novel.toJson()).toList(),
      );

      await _prefsService.setString(_bookmarksKey, bookmarksJson);
    } catch (e) {
      print('Error saving bookmarks: $e');
    }
  }

  Future<bool> addBookmark(LightNovel novel) async {
    try {
      // Check if novel is already bookmarked
      if (_isBookmarked(novel.id)) {
        return false;
      }

      _bookmarkedNovels.add(novel);
      await saveBookmarks();
      notifyListeners();
      return true;
    } catch (e) {
      print('Error adding bookmark: $e');
      return false;
    }
  }

  Future<bool> removeBookmark(String novelId) async {
    try {
      final initialLength = _bookmarkedNovels.length;
      _bookmarkedNovels.removeWhere((novel) => novel.id == novelId);

      if (_bookmarkedNovels.length < initialLength) {
        await saveBookmarks();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing bookmark: $e');
      return false;
    }
  }

  bool _isBookmarked(String novelId) {
    return _bookmarkedNovels.any((novel) => novel.id == novelId);
  }

  bool isBookmarked(String novelId) {
    return _isBookmarked(novelId);
  }

  Future<void> toggleBookmark(LightNovel novel) async {
    if (_isBookmarked(novel.id)) {
      await removeBookmark(novel.id);
    } else {
      await addBookmark(novel);
    }
  }
}

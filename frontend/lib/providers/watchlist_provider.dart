// frontend/lib/providers/watchlist_provider.dart
import 'package:flutter/material.dart';
import '../models/watchlist_item.dart';
import '../services/api_service.dart';

class WatchlistProvider extends ChangeNotifier {
  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<WatchlistItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 💡 Filtered Getters for UI Tabs
  List<WatchlistItem> get movies => _items
      .where((item) => item.mediaType.toLowerCase() == 'movie')
      .toList();

  List<WatchlistItem> get shows => _items
      .where((item) =>
          item.mediaType.toLowerCase() == 'tv' ||
          item.mediaType.toLowerCase() == 'show')
      .toList();

  List<WatchlistItem> get watchlistItems =>
      _items.where((item) => item.status.toLowerCase() == 'watchlist').toList();

  List<WatchlistItem> get favoriteItems =>
      _items.where((item) => item.status.toLowerCase() == 'favorite').toList();

  /// Fetch user's saved watchlist from backend
  Future<void> fetchWatchlist({String? status, String? mediaType}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.getWatchlist(status: status, mediaType: mediaType);
      _items = data.map((json) => WatchlistItem.fromJson(json)).toList();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add or update a movie/show in the watchlist
  Future<bool> addToWatchlist({
    required int movieId,
    required String movieTitle,
    String? posterPath,
    String status = 'watchlist',
    String mediaType = 'movie',
  }) async {
    _errorMessage = null;
    try {
      await ApiService.addToWatchlist(
        movieId: movieId,
        movieTitle: movieTitle,
        posterPath: posterPath,
        status: status,
        mediaType: mediaType,
      );
      // Refresh list to update state across all screens
      await fetchWatchlist();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Remove a movie or show from the watchlist
  Future<bool> removeFromWatchlist(int movieId, {String? mediaType}) async {
    _errorMessage = null;
    try {
      await ApiService.removeFromWatchlist(movieId, mediaType: mediaType);
      
      _items.removeWhere((item) {
        final matchesId = item.movieId == movieId;
        if (mediaType == null) return matchesId;
        
        final itemType = item.mediaType.toLowerCase();
        final targetType = mediaType.toLowerCase();
        final isItemTv = itemType == 'tv' || itemType == 'show';
        final isTargetTv = targetType == 'tv' || targetType == 'show';

        return matchesId && (isItemTv == isTargetTv);
      });

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Check if a specific media item is already in the watchlist
  bool isMediaInWatchlist(int movieId, {String? mediaType}) {
    if (mediaType == null) {
      return _items.any((item) => item.movieId == movieId);
    }

    final targetType = mediaType.toLowerCase();
    final isTargetTv = targetType == 'tv' || targetType == 'show';

    return _items.any((item) {
      final itemType = item.mediaType.toLowerCase();
      final isItemTv = itemType == 'tv' || itemType == 'show';
      return item.movieId == movieId && (isItemTv == isTargetTv);
    });
  }

  /// Helper to check item status ('watchlist', 'favorite', or null)
  String? getMediaStatus(int movieId, {String? mediaType}) {
    try {
      if (mediaType == null) {
        return _items.firstWhere((item) => item.movieId == movieId).status;
      }

      final targetType = mediaType.toLowerCase();
      final isTargetTv = targetType == 'tv' || targetType == 'show';

      return _items.firstWhere((item) {
        final itemType = item.mediaType.toLowerCase();
        final isItemTv = itemType == 'tv' || itemType == 'show';
        return item.movieId == movieId && (isItemTv == isTargetTv);
      }).status;
    } catch (_) {
      return null;
    }
  }
}
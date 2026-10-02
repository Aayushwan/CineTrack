// frontend/lib/providers/watchlist_provider.dart
import 'package:flutter/material.dart';
import '../models/watchlist_item.dart';
import '../services/api_service.dart';

class WatchlistProvider extends ChangeNotifier {
  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Global Custom Lists from Database
  List<dynamic> _customLists = [];
  List<dynamic> get customLists => _customLists;

  List<WatchlistItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<WatchlistItem> get movies => _items.where((item) => item.mediaType.toLowerCase() == 'movie').toList();
  List<WatchlistItem> get shows => _items.where((item) => item.mediaType.toLowerCase() == 'tv' || item.mediaType.toLowerCase() == 'show').toList();
  List<WatchlistItem> get watchlistItems => _items.where((item) => item.status.toLowerCase() == 'watchlist').toList();
  List<WatchlistItem> get favoriteItems => _items.where((item) => item.status.toLowerCase() == 'favorite').toList();

  Future<void> fetchWatchlist({String? status, String? mediaType}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.getWatchlist(status: status, mediaType: mediaType);
      _items = data.map((json) => WatchlistItem.fromJson(json)).toList();
      
      // Fetch custom lists at the same time
      _customLists = await ApiService.getCustomLists();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCustomLists() async {
    try {
      _customLists = await ApiService.getCustomLists();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<bool> addToWatchlist({
    required int movieId, required String movieTitle, String? posterPath,
    String status = 'watchlist', String mediaType = 'movie',
    String? releaseYear, int? runtime, int? totalEpisodes, double? voteAverage,
  }) async {
    _errorMessage = null;
    try {
      await ApiService.addToWatchlist(
        movieId: movieId, movieTitle: movieTitle, posterPath: posterPath,
        status: status, mediaType: mediaType, releaseYear: releaseYear,
        runtime: runtime, totalEpisodes: totalEpisodes, voteAverage: voteAverage,
      );
      await fetchWatchlist();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

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

  bool isMediaInWatchlist(int movieId, {String? mediaType}) {
    if (mediaType == null) return _items.any((item) => item.movieId == movieId);
    final targetType = mediaType.toLowerCase();
    final isTargetTv = targetType == 'tv' || targetType == 'show';
    return _items.any((item) {
      final itemType = item.mediaType.toLowerCase();
      final isItemTv = itemType == 'tv' || itemType == 'show';
      return item.movieId == movieId && (isItemTv == isTargetTv);
    });
  }

  String? getMediaStatus(int movieId, {String? mediaType}) {
    try {
      if (mediaType == null) return _items.firstWhere((item) => item.movieId == movieId).status;
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

  // Database-Backed Custom List Management
  Future<void> createList(String title) async {
    if (title.trim().isNotEmpty) {
      try {
        await ApiService.createCustomList(title.trim());
        await fetchCustomLists();
      } catch (e) {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
    }
  }

  Future<void> deleteList(int listId) async {
    try {
      await ApiService.deleteCustomList(listId);
      await fetchCustomLists();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<void> addMediaToList(int listId, int movieId, String? posterUrl) async {
    try {
      await ApiService.addMediaToCustomList(listId, movieId, posterUrl);
      await fetchCustomLists(); // Refresh to get the updated poster array
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
  }
}
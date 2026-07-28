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

  /// Fetch user's saved watchlist from backend
  Future<void> fetchWatchlist({String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.getWatchlist(status: status);
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
  String mediaType = 'movie', // 👈 Added mediaType support
}) async {
  try {
    await ApiService.addToWatchlist(
      movieId: movieId,
      movieTitle: movieTitle,
      posterPath: posterPath,
      status: status,
      mediaType: mediaType, // 👈 Pass to ApiService
    );
    await fetchWatchlist();
    return true;
  } catch (e) {
    _errorMessage = e.toString().replaceAll('Exception: ', '');
    notifyListeners();
    return false;
  }
}

  /// Remove a movie from the watchlist
  Future<bool> removeFromWatchlist(int movieId) async {
    try {
      await ApiService.removeFromWatchlist(movieId);
      _items.removeWhere((item) => item.movieId == movieId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Check if a specific movie is already in the watchlist
  bool isMovieInWatchlist(int movieId) {
    return _items.any((item) => item.movieId == movieId);
  }
}
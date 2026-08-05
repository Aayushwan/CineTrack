// frontend/lib/models/watchlist_item.dart

class WatchlistItem {
  final int id;
  final int userId;
  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final String status;
  final String mediaType; // 👈 Added
  final DateTime createdAt;

  WatchlistItem({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    this.posterPath,
    required this.status,
    this.mediaType = 'movie', // 👈 Defaults to 'movie' if unspecified
    required this.createdAt,
  });

  /// Factory constructor to parse JSON from FastAPI Watchlist endpoint
  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      movieId: json['movie_id'] ?? 0,
      movieTitle: json['movie_title'] ?? 'Unknown',
      posterPath: json['poster_path'],
      status: json['status'] ?? 'watchlist',
      // Safely checks 'media_type' or 'type', defaulting to 'movie'
      mediaType: json['media_type'] ?? json['type'] ?? 'movie',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// Helper to get full image URL
  String get fullPosterUrl {
    if (posterPath != null && posterPath!.isNotEmpty) {
      if (posterPath!.startsWith('http')) {
        return posterPath!;
      }
      return 'https://image.tmdb.org/t/p/w500$posterPath';
    }
    return 'https://via.placeholder.com/500x750?text=No+Poster';
  }
}
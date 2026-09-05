// frontend/lib/models/watchlist_item.dart

class WatchlistItem {
  final int id;
  final int userId;
  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final String status;
  final String mediaType;
  final DateTime createdAt;
  
  // New optional fields for UI details
  final String? releaseYear;
  final int? runtime;
  final int? totalEpisodes;
  final double? voteAverage;

  WatchlistItem({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    this.posterPath,
    required this.status,
    this.mediaType = 'movie', 
    required this.createdAt,
    this.releaseYear,
    this.runtime,
    this.totalEpisodes,
    this.voteAverage,
  });

  /// Factory constructor to parse JSON from FastAPI Watchlist endpoint
  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      // Safely parse integers whether they arrive as Strings or Ints
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      userId: json['user_id'] != null ? int.tryParse(json['user_id'].toString()) ?? 0 : 0,
      movieId: json['movie_id'] != null ? int.tryParse(json['movie_id'].toString()) ?? 0 : 0,
      
      movieTitle: json['movie_title'] ?? 'Unknown',
      posterPath: json['poster_path'],
      status: json['status'] ?? 'watchlist',
      mediaType: json['media_type'] ?? json['type'] ?? 'movie',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
          
      // Safely parse new fields supporting camelCase and snake_case backend standards
      releaseYear: json['releaseYear']?.toString() ?? json['release_year']?.toString(),
      runtime: json['runtime'] != null ? int.tryParse(json['runtime'].toString()) : null,
      totalEpisodes: json['totalEpisodes'] != null ? int.tryParse(json['totalEpisodes'].toString()) : (json['total_episodes'] != null ? int.tryParse(json['total_episodes'].toString()) : null),
      voteAverage: json['voteAverage'] != null ? double.tryParse(json['voteAverage'].toString()) : (json['vote_average'] != null ? double.tryParse(json['vote_average'].toString()) : null),
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
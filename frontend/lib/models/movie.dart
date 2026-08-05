class Movie {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? releaseDate;
  final String mediaType; // 👈 Added mediaType field

  Movie({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    this.releaseDate,
    this.mediaType = 'movie', // 👈 Defaults to 'movie'
  });

  /// Factory constructor to parse JSON from TMDB API
  factory Movie.fromJson(Map<String, dynamic> json) {
    // Detect TV show if explicit 'media_type' is 'tv' OR if TV-specific keys ('name', 'first_air_date') exist
    final rawMediaType = json['media_type']?.toString().toLowerCase();
    final isTv = rawMediaType == 'tv' || 
                 json.containsKey('first_air_date') || 
                 (json.containsKey('name') && !json.containsKey('title'));

    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? 'Untitled',
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['release_date'] ?? json['first_air_date'],
      mediaType: isTv ? 'tv' : 'movie',
    );
  }

  /// Helper to get full TMDB poster URL
  String get fullPosterUrl {
    if (posterPath != null && posterPath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w500$posterPath';
    }
    return 'https://via.placeholder.com/500x750?text=No+Poster';
  }

  /// Helper to get full TMDB backdrop URL
  String get fullBackdropUrl {
    if (backdropPath != null && backdropPath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w1280$backdropPath';
    }
    return 'https://via.placeholder.com/1280x720?text=No+Backdrop';
  }
}
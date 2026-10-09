import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/review.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _decodeMap(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }

  static List<dynamic> _decodeList(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      return <dynamic>[];
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List<dynamic>) {
      return decoded;
    }

    return <dynamic>[];
  }

  static String _getErrorMessage(
    http.Response response,
    String fallback,
  ) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];

        if (detail is String && detail.isNotEmpty) {
          return detail;
        }

        if (detail is List) {
          return detail
              .map((item) {
                if (item is Map) {
                  return item['msg']?.toString() ?? '';
                }

                return item.toString();
              })
              .where((message) => message.isNotEmpty)
              .join(', ');
        }

        final message = decoded['message'];

        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Return the supplied fallback for non-JSON errors.
    }

    return fallback;
  }

  static Future<Map<String, String>> _authorizedHeaders({
    bool includeContentType = true,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    return {
      'Authorization': 'Bearer $token',
      if (includeContentType)
        'Content-Type': 'application/json',
    };
  }

  // ---------------------------------------------------------------------------
  // Token and user persistence
  // ---------------------------------------------------------------------------

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<void> saveUsername(
    String username,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  static Future<String?> getStoredUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');
    await prefs.remove('username');
  }

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      final data = _decodeMap(response);
      await saveUsername(username);
      return data;
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to register account',
      ),
    );
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = _decodeMap(response);

      final token = data['access_token']?.toString();
      final username = data['username']?.toString();

      if (token != null && token.isNotEmpty) {
        await saveToken(token);
      }

      if (username != null && username.isNotEmpty) {
        await saveUsername(username);
      }

      return data;
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to login',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Movies and media
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getTrendingMovies({
    int page = 1,
    String type = 'movie',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/movies/trending',
    ).replace(
      queryParameters: {
        'page': page.toString(),
        'type': type,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to load trending content',
      ),
    );
  }

  static Future<Map<String, dynamic>> searchMovies(
    String query, {
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/movies/search',
    ).replace(
      queryParameters: {
        'query': query,
        'page': page.toString(),
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to perform search',
      ),
    );
  }

  static Future<Map<String, dynamic>> getMovieDetails(
    int movieId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/$movieId'),
    );

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to load movie details',
      ),
    );
  }

  static Future<Map<String, dynamic>> getTvDetails(
    int tvId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/tv/$tvId'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to load TV show details',
      ),
    );
  }

  static Future<Map<String, dynamic>> getPersonDetails(
    int personId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/movies/person/$personId',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to load person details',
      ),
    );
  }

  static Future<List<dynamic>> getTvSeasonDetails(
    int tvId,
    int seasonNumber,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/movies/tv/$tvId/season/'
        '$seasonNumber',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List<dynamic>) {
        return decoded;
      }

      if (decoded is Map<String, dynamic>) {
        return decoded['episodes']
                as List<dynamic>? ??
            <dynamic>[];
      }

      return <dynamic>[];
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to load season details',
      ),
    );
  }

  static Future<Map<String, dynamic>> getUpcomingMedia({
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/movies/upcoming',
    ).replace(
      queryParameters: {
        'page': page.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to load upcoming releases',
      ),
    );
  }

  static Future<Map<String, dynamic>> getDiscoverMedia({
    String category = 'trending',
    int page = 1,
    String type = 'movie',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/movies/discover',
    ).replace(
      queryParameters: {
        'category': category,
        'page': page.toString(),
        'type': type,
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to load discover content',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Watchlist
  // ---------------------------------------------------------------------------

  static Future<List<dynamic>> getWatchlist({
    String? status,
    String? mediaType,
  }) async {
    final headers = await _authorizedHeaders();

    final queryParameters = <String, String>{};

    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }

    if (mediaType != null && mediaType.isNotEmpty) {
      queryParameters['media_type'] = mediaType;
    }

    final uri = Uri.parse(
      '$baseUrl/watchlist/',
    ).replace(
      queryParameters: queryParameters.isEmpty
          ? null
          : queryParameters,
    );

    final response = await http.get(
      uri,
      headers: headers,
    );

    if (response.statusCode == 200) {
      return _decodeList(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to fetch user watchlist',
      ),
    );
  }

  static Future<void> addToWatchlist({
    required int movieId,
    required String movieTitle,
    String? posterPath,
    String status = 'watchlist',
    String mediaType = 'movie',
    String? releaseYear,
    int? runtime,
    int? totalEpisodes,
    double? voteAverage,
  }) async {
    final headers = await _authorizedHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/watchlist/'),
      headers: headers,
      body: jsonEncode({
        'movie_id': movieId,
        'movie_title': movieTitle,
        'poster_path': posterPath,
        'status': status,
        'media_type': mediaType,
        'release_year': releaseYear,
        'runtime': runtime,
        'total_episodes': totalEpisodes,
        'vote_average': voteAverage,
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to update watchlist',
        ),
      );
    }
  }

  static Future<void> removeFromWatchlist(
    int movieId, {
    String? mediaType,
  }) async {
    final headers = await _authorizedHeaders(
      includeContentType: false,
    );

    final queryParameters = <String, String>{};

    if (mediaType != null && mediaType.isNotEmpty) {
      queryParameters['media_type'] = mediaType;
    }

    final uri = Uri.parse(
      '$baseUrl/watchlist/$movieId',
    ).replace(
      queryParameters: queryParameters.isEmpty
          ? null
          : queryParameters,
    );

    final response = await http.delete(
      uri,
      headers: headers,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to remove item from watchlist',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Reviews
  // ---------------------------------------------------------------------------

  static Future<List<Review>> getMovieReviews(
    int movieId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/reviews/movie/$movieId',
      ),
    );

    if (response.statusCode == 200) {
      final body = _decodeList(response);

      return body
          .map(
            (item) => Review.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    if (response.statusCode == 404) {
      return <Review>[];
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to load reviews',
      ),
    );
  }

  static Future<bool> postReview({
    required int movieId,
    required double rating,
    String? comment,
  }) async {
    final headers = await _authorizedHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/reviews/'),
      headers: headers,
      body: jsonEncode({
        'movie_id': movieId,
        'rating': rating,
        'comment': comment,
      }),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      return true;
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to post review',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Watch history
  // ---------------------------------------------------------------------------

  static Future<List<dynamic>> getWatchHistory([
    String? mediaType,
  ]) async {
    final headers = await _authorizedHeaders();

    final uri = Uri.parse(
      '$baseUrl/user/history',
    ).replace(
      queryParameters:
          mediaType != null && mediaType.isNotEmpty
              ? {
                  'media_type': mediaType.toLowerCase(),
                }
              : null,
    );

    final response = await http.get(
      uri,
      headers: headers,
    );

    if (response.statusCode == 200) {
      return _decodeList(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to fetch watch history',
      ),
    );
  }

  static Future<void> logWatchHistory({
    required int movieId,
    required String mediaType,
    required String title,
    String? subtitle,
    String? posterPath,
    double? userRating,
    int runtimeMinutes = 120,
    String? watchedAt,
    int? seasonNumber,
    int? episodeNumber,
    int? totalEpisodes,
    String? backdropPath,
  }) async {
    final headers = await _authorizedHeaders();

    final requestBody = <String, dynamic>{
      'media_id': movieId.toString(),
      'media_type': mediaType.toLowerCase(),
      'title': title,
      'poster_path': posterPath,
      'duration_watched_seconds':
          runtimeMinutes * 60,
      'watched_at': watchedAt ??
          DateTime.now().toUtc().toIso8601String(),
    };

    if (subtitle != null && subtitle.isNotEmpty) {
      requestBody['subtitle'] = subtitle;
    }

    if (userRating != null) {
      requestBody['user_rating'] = userRating;
    }

    if (seasonNumber != null) {
      requestBody['season_number'] = seasonNumber;
    }

    if (episodeNumber != null) {
      requestBody['episode_number'] = episodeNumber;
    }

    if (totalEpisodes != null) {
      requestBody['total_episodes'] = totalEpisodes;
    }

    if (backdropPath != null &&
        backdropPath.isNotEmpty) {
      requestBody['backdrop_path'] = backdropPath;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/user/history'),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to log watch history',
        ),
      );
    }
  }

  static Future<void> logShowWatchHistory({
    required int showId,
    required String title,
    required List<Map<String, dynamic>> episodes,
    required int totalEpisodes,
    String? posterPath,
    String? backdropPath,
    String? watchedAt,
  }) async {
    if (episodes.isEmpty) {
      throw Exception(
        'No episodes were supplied for tracking',
      );
    }

    final headers = await _authorizedHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/user/history/show'),
      headers: headers,
      body: jsonEncode({
        'media_id': showId.toString(),
        'title': title,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'total_episodes': totalEpisodes,
        'watched_at': watchedAt ??
            DateTime.now().toUtc().toIso8601String(),
        'episodes': episodes,
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to mark show as watched',
        ),
      );
    }
  }

  static Future<void> removeWatchHistory(
    int historyId,
  ) async {
    final headers = await _authorizedHeaders(
      includeContentType: false,
    );

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/user/history/$historyId',
      ),
      headers: headers,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to delete history log',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Show progress
  // ---------------------------------------------------------------------------

  static Future<List<dynamic>> getShowProgress() async {
    final headers = await _authorizedHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/user/progress/shows'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return _decodeList(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to fetch show progress',
      ),
    );
  }

  static Future<List<dynamic>> getSpecificShowProgress(
    int showId,
  ) async {
    final headers = await _authorizedHeaders();

    final response = await http.get(
      Uri.parse(
        '$baseUrl/user/progress/shows/$showId',
      ),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return _decodeList(response);
    }

    if (response.statusCode == 404) {
      return <dynamic>[];
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to fetch episode progress',
      ),
    );
  }

  static Future<void> removeShowHistory(
    int showId,
  ) async {
    final headers = await _authorizedHeaders();

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/user/progress/shows/$showId',
      ),
      headers: headers,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to remove show history',
        ),
      );
    }
  }

  static Future<Map<String, dynamic>> updateShowProgress({
    required int showId,
    required String title,
    required String season,
    required int totalEpisodes,
    int increment = 1,
  }) async {
    final headers = await _authorizedHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/user/progress/episode'),
      headers: headers,
      body: jsonEncode({
        'show_id': showId,
        'title': title,
        'season': season,
        'total_episodes': totalEpisodes,
        'increment': increment,
      }),
    );

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to update show progress',
      ),
    );
  }

  static Future<List<dynamic>>
      getContinueWatching() async {
    final headers = await _authorizedHeaders();

    final response = await http.get(
      Uri.parse(
        '$baseUrl/user/progress/continue-watching',
      ),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return _decodeList(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to fetch Continue Watching',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>>
      getProfileStats() async {
    final headers = await _authorizedHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/user/profile/stats'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to fetch profile stats',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Custom lists
  // ---------------------------------------------------------------------------

  static Future<List<dynamic>> getCustomLists() async {
    final headers = await _authorizedHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/lists/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return _decodeList(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to fetch custom lists',
      ),
    );
  }

  static Future<Map<String, dynamic>> createCustomList(
    String name,
  ) async {
    final headers = await _authorizedHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/lists/'),
      headers: headers,
      body: jsonEncode({
        'name': name,
      }),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      return _decodeMap(response);
    }

    throw Exception(
      _getErrorMessage(
        response,
        'Failed to create list',
      ),
    );
  }

  static Future<void> deleteCustomList(
    int listId,
  ) async {
    final headers = await _authorizedHeaders(
      includeContentType: false,
    );

    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$listId'),
      headers: headers,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to delete list',
        ),
      );
    }
  }

  static Future<void> addMediaToCustomList(
    int listId,
    int movieId,
    String? posterPath, {
    String title = 'Unknown',
    String mediaType = 'movie',
  }) async {
    final headers = await _authorizedHeaders();

    final response = await http.post(
      Uri.parse(
        '$baseUrl/lists/$listId/items',
      ),
      headers: headers,
      body: jsonEncode({
        'media_id': movieId.toString(),
        'movie_id': movieId,
        'media_type': mediaType,
        'title': title,
        'poster_path': posterPath,
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to add media to list',
        ),
      );
    }
  }

  static Future<void> renameCustomList(
    int listId,
    String newName,
  ) async {
    final headers = await _authorizedHeaders();

    final response = await http.put(
      Uri.parse('$baseUrl/lists/$listId'),
      headers: headers,
      body: jsonEncode({
        'name': newName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to rename list',
        ),
      );
    }
  }

  static Future<void> removeMediaFromCustomList(
    int listId,
    dynamic mediaId,
  ) async {
    final headers = await _authorizedHeaders(
      includeContentType: false,
    );

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/lists/$listId/items/$mediaId',
      ),
      headers: headers,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw Exception(
        _getErrorMessage(
          response,
          'Failed to remove item from list',
        ),
      );
    }
  }
}
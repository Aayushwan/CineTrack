import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review.dart';

class ApiService {
  // Base URL pointing to your FastAPI backend
  static const String baseUrl = 'http://127.0.0.1:8000';

  // --- Token & User Persistence Helpers ---

  /// Retrieve the stored JWT token from local storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Save JWT token to local storage after successful login
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  /// Save username to local storage
  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  /// Retrieve stored username from local storage
  static Future<String?> getStoredUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  /// Clear the stored token and user info on logout
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('username');
  }

  // --- Authentication Endpoints ---

  /// Register a new user
  static Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await saveUsername(username);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to register account');
    }
  }

  /// Login existing user & store returned JWT token
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['access_token'] != null) {
        await saveToken(data['access_token']);
      }
      if (data['username'] != null) {
        await saveUsername(data['username']);
      }
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to login');
    }
  }

  // --- Movies & Media Endpoints (TMDB via FastAPI) ---

  /// Fetch daily trending media ('movie', 'tv', or 'all')
  static Future<Map<String, dynamic>> getTrendingMovies({
    int page = 1,
    String type = 'movie',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/trending?page=$page&type=$type'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load trending content');
    }
  }

  /// Search movies, TV shows, and persons across TMDB multi-search
  static Future<Map<String, dynamic>> searchMovies(String query,
      {int page = 1}) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/movies/search?query=${Uri.encodeComponent(query)}&page=$page'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to perform search');
      } catch (_) {
        throw Exception('Failed to perform search');
      }
    }
  }

  /// Fetch details, cast, and video trailers for a single movie
  static Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/$movieId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load movie details');
    }
  }

  // Fetch TV Show Details
  static Future<Map<String, dynamic>> getTvDetails(int tvId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/tv/$tvId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load TV show details');
    }
  }

  // Fetch Person Details
  static Future<Map<String, dynamic>> getPersonDetails(int personId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/person/$personId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load person details');
    }
  }

  // Fetch Upcoming Movies/Shows from FastAPI
  static Future<Map<String, dynamic>> getUpcomingMedia({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/upcoming?page=$page'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load upcoming releases');
    }
  }

  /// Fetch Discover Media by Category (Trending, Releases, Anticipated, Popular)
  /// Pass [type] = 'tv' or 'movie' to load target media type
  static Future<Map<String, dynamic>> getDiscoverMedia({
    String category = 'trending',
    int page = 1,
    String type = 'movie',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/discover?category=$category&page=$page&type=$type'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load discover content');
    }
  }

  // --- Watchlist Endpoints (JWT Protected) ---

  /// Retrieve user's saved watchlist items with optional status and mediaType filters
  static Future<List<dynamic>> getWatchlist({
    String? status,
    String? mediaType,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final Map<String, String> queryParams = {};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (mediaType != null && mediaType.isNotEmpty) {
      queryParams['media_type'] = mediaType;
    }

    final uri = Uri.parse('$baseUrl/watchlist/').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch user watchlist');
    }
  }

  /// Add a movie/show to watchlist or update its status (JWT Protected)
  static Future<void> addToWatchlist({
    required int movieId,
    required String movieTitle,
    String? posterPath,
    String status = 'watchlist',
    String mediaType = 'movie',
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/watchlist/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'movie_id': movieId,
        'movie_title': movieTitle,
        'poster_path': posterPath,
        'status': status,
        'media_type': mediaType,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update watchlist');
    }
  }

  /// Remove an item from user's watchlist with optional mediaType
  static Future<void> removeFromWatchlist(
    int movieId, {
    String? mediaType,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final Map<String, String> queryParams = {};
    if (mediaType != null && mediaType.isNotEmpty) {
      queryParams['media_type'] = mediaType;
    }

    final uri = Uri.parse('$baseUrl/watchlist/$movieId').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to remove item from watchlist');
    }
  }

  // --- Reviews Endpoints ---

  /// Fetch all user reviews for a specific movie/show
  static Future<List<Review>> getMovieReviews(int movieId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reviews/movie/$movieId'),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Review.fromJson(item)).toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('Failed to load reviews');
    }
  }

  /// Submit a review for a movie/show (JWT protected)
  static Future<bool> postReview({
    required int movieId,
    required double rating,
    String? comment,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/reviews/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'movie_id': movieId,
        'rating': rating,
        'comment': comment,
      }),
    );

    return response.statusCode == 201;
  }

  // --- User Activity & Watch History Endpoints (JWT Protected) ---

  /// Retrieve full watch history log with optional filter (e.g., 'movie' or 'tv')
  static Future<List<dynamic>> getWatchHistory([String? mediaType]) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('$baseUrl/user/history').replace(
      queryParameters: mediaType != null && mediaType.isNotEmpty
          ? {'media_type': mediaType.toLowerCase()}
          : null,
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch watch history');
    }
  }

  /// Log a newly watched movie or show episode
  static Future<void> logWatchHistory({
    required int movieId,
    required String mediaType,
    required String title,
    String? subtitle,
    String? posterPath,
    double? userRating,
    int runtimeMinutes = 120,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/user/history'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'movie_id': movieId,
        'media_type': mediaType,
        'title': title,
        'subtitle': subtitle,
        'poster_path': posterPath,
        'user_rating': userRating,
        'runtime_minutes': runtimeMinutes,
      }),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to log watch history');
    }
  }

  /// Update show episode progress
  static Future<Map<String, dynamic>> updateShowProgress({
    required int showId,
    required String title,
    required String season,
    required int totalEpisodes,
    int increment = 1,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/user/progress/episode'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'show_id': showId,
        'title': title,
        'season': season,
        'total_episodes': totalEpisodes,
        'increment': increment,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update show progress');
    }
  }

  /// Retrieve profile screen time and analytics
  static Future<Map<String, dynamic>> getProfileStats() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/user/profile/stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch profile stats');
    }
  }
}
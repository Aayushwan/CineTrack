// frontend/lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review.dart';

class ApiService {
  // Base URL pointing to your FastAPI backend
  static const String baseUrl = 'http://localhost:8000';

  // --- Token & User Persistence Helpers ---

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<void> saveUsername(String username) async {
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

  // --- Authentication Endpoints ---

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

  static Future<List<dynamic>> getTvSeasonDetails(int tvId, int seasonNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movies/tv/$tvId/season/$seasonNumber'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

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
        'release_year': releaseYear,
        'runtime': runtime,
        'total_episodes': totalEpisodes,
        'vote_average': voteAverage,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update watchlist');
    }
  }

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

  static Future<void> logWatchHistory({
    required int movieId,
    required String mediaType,
    required String title,
    String? subtitle,
    String? posterPath,
    double? userRating,
    int runtimeMinutes = 120,
    String? watchedAt, 
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
        'media_id': movieId.toString(),
        'media_type': mediaType,
        'title': title,
        'poster_path': posterPath,
        'duration_watched_seconds': runtimeMinutes * 60,
        'watched_at': watchedAt ?? DateTime.now().toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to log watch history');
    }
  }

  static Future<void> removeWatchHistory(int historyId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/user/history/$historyId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete history log');
    }
  }

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

  // --- Custom Lists Endpoints ---

  static Future<List<dynamic>> getCustomLists() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/lists/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch custom lists');
    }
  }

  static Future<Map<String, dynamic>> createCustomList(String name) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/lists/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create list');
    }
  }

  static Future<void> deleteCustomList(int listId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$listId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete list');
    }
  }

  // 👇 Updated to support title and mediaType for the list_items table
  static Future<void> addMediaToCustomList(
    int listId, 
    int movieId, 
    String? posterPath, {
    String title = 'Unknown',
    String mediaType = 'movie',
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/lists/$listId/items'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'media_id': movieId.toString(),
        'movie_id': movieId, // Maintained for backward compatibility
        'media_type': mediaType,
        'title': title,
        'poster_path': posterPath,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to add media to list');
    }
  }

  // 👇 New endpoint to rename a list
  static Future<void> renameCustomList(int listId, String newName) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('$baseUrl/lists/$listId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': newName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to rename list');
    }
  }

  // 👇 New endpoint to remove an item from a list
  static Future<void> removeMediaFromCustomList(int listId, dynamic mediaId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/lists/$listId/items/$mediaId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to remove item from list');
    }
  }
}
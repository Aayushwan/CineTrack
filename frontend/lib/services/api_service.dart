import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL pointing to your FastAPI backend
  static const String baseUrl = 'http://localhost:8000';

  // --- Token Management Helpers ---

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

  /// Clear the stored token on logout
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
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
      return jsonDecode(response.body);
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
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to login');
    }
  }

  // --- Movies Endpoints (TMDB) ---

  /// Fetch daily trending movies
  static Future<Map<String, dynamic>> getTrendingMovies({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movies/trending?page=$page'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load trending movies');
    }
  }

  /// Search movies by title/keyword
  static Future<Map<String, dynamic>> searchMovies(String query,
      {int page = 1}) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/movies/search?query=${Uri.encodeComponent(query)}&page=$page'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search movies');
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

  // --- Watchlist Endpoints (JWT Protected) ---

  /// Retrieve user's saved watchlist items
  static Future<List<dynamic>> getWatchlist({String? status}) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = status != null
        ? Uri.parse('$baseUrl/watchlist/?status=$status')
        : Uri.parse('$baseUrl/watchlist/');

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

  /// Add a movie to watchlist or update its status
  static Future<Map<String, dynamic>> addToWatchlist({
    required int movieId,
    required String movieTitle,
    String? posterPath,
    String status = 'watchlist',
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
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update watchlist');
    }
  }

  /// Remove a movie from user's watchlist
  static Future<void> removeFromWatchlist(int movieId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/watchlist/$movieId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to remove item from watchlist');
    }
  }
}
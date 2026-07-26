import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/navbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Movie> _trendingMovies = [];
  List<Movie> _searchResults = [];
  bool _isLoadingTrending = true;
  bool _isSearching = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchTrendingMovies();
  }

  Future<void> _fetchTrendingMovies() async {
    setState(() {
      _isLoadingTrending = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.getTrendingMovies();
      final List results = response['results'] ?? [];
      setState(() {
        _trendingMovies = results.map((json) => Movie.fromJson(json)).toList();
        _isLoadingTrending = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoadingTrending = false;
      });
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await ApiService.searchMovies(query);
      final List results = response['results'] ?? [];
      setState(() {
        _searchResults = results.map((json) => Movie.fromJson(json)).toList();
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isQueryActive = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: const CustomNavbar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner / Search Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E293B),
                      const Color(0xFF0F172A).withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Welcome to CineTrack',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Discover millions of movies, build your personal watchlist, and track your favorites.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    // Search Input Box
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _handleSearch,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search for movies by title...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                          suffixIcon: isQueryActive
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                                  onPressed: () {
                                    _searchController.clear();
                                    _handleSearch('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Color(0xFFE11D48)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Title Section
              Text(
                isQueryActive ? 'Search Results' : 'Trending Movies',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 16),

              // Movies Grid or Loading Indicator
              if (_isLoadingTrending || _isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: Color(0xFFE11D48)),
                  ),
                )
              else if (_errorMessage.isNotEmpty)
                Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              else ...[
                Builder(
                  builder: (context) {
                    final displayMovies = isQueryActive ? _searchResults : _trendingMovies;

                    if (displayMovies.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            isQueryActive
                                ? 'No movies found matching "${_searchController.text}".'
                                : 'No trending movies available.',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.start,
                      children: displayMovies
                          .map((movie) => MovieCard(movie: movie))
                          .toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
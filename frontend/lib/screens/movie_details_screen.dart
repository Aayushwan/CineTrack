import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../widgets/navbar.dart';

class MovieDetailsScreen extends StatefulWidget {
  final int movieId;

  const MovieDetailsScreen({super.key, required this.movieId});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  Map<String, dynamic>? _movieData;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final data = await ApiService.getMovieDetails(widget.movieId);
      if (mounted) {
        setState(() {
          _movieData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    final isInWatchlist = watchlistProvider.isMovieInWatchlist(widget.movieId);

    return Scaffold(
      appBar: const CustomNavbar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE11D48)),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Backdrop & Hero Header
                      Stack(
                        children: [
                          Container(
                            height: 380,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(
                                  _movieData?['backdrop_path'] != null
                                      ? 'https://image.tmdb.org/t/p/w1280${_movieData!['backdrop_path']}'
                                      : 'https://via.placeholder.com/1280x720?text=No+Backdrop',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            height: 380,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF0F172A).withValues(alpha: 0.9),
                                  const Color(0xFF0F172A),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 24,
                            left: 24,
                            right: 24,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Poster Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _movieData?['poster_path'] != null
                                        ? 'https://image.tmdb.org/t/p/w500${_movieData!['poster_path']}'
                                        : 'https://via.placeholder.com/500x750?text=No+Poster',
                                    height: 180,
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _movieData?['title'] ?? 'Untitled',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: Colors.amber, size: 20),
                                          const SizedBox(width: 4),
                                          Text(
                                            (_movieData?['vote_average'] as num?)
                                                    ?.toStringAsFixed(1) ??
                                                '0.0',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          const Icon(Icons.calendar_today_rounded,
                                              color: Colors.white54, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            _movieData?['release_date'] ?? 'N/A',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Actions and Details Body
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Watchlist Buttons
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isInWatchlist
                                        ? Colors.grey.shade800
                                        : const Color(0xFFE11D48),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 14),
                                  ),
                                  onPressed: () async {
                                    if (!authProvider.isAuthenticated) {
                                      context.go('/login');
                                      return;
                                    }

                                    if (isInWatchlist) {
                                      await watchlistProvider
                                          .removeFromWatchlist(widget.movieId);
                                    } else {
                                      await watchlistProvider.addToWatchlist(
                                        movieId: widget.movieId,
                                        movieTitle: _movieData?['title'] ?? '',
                                        posterPath: _movieData?['poster_path'],
                                        status: 'watchlist',
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    isInWatchlist
                                        ? Icons.check_circle_rounded
                                        : Icons.bookmark_add_rounded,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    isInWatchlist
                                        ? 'In Watchlist'
                                        : 'Add to Watchlist',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.amber),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  onPressed: () async {
                                    if (!authProvider.isAuthenticated) {
                                      context.go('/login');
                                      return;
                                    }
                                    await watchlistProvider.addToWatchlist(
                                      movieId: widget.movieId,
                                      movieTitle: _movieData?['title'] ?? '',
                                      posterPath: _movieData?['poster_path'],
                                      status: 'favorite',
                                    );
                                  },
                                  icon: const Icon(Icons.favorite_rounded,
                                      color: Colors.amber),
                                  label: const Text('Favorite',
                                      style: TextStyle(color: Colors.amber)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Overview Section
                            Text(
                              'Overview',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _movieData?['overview'] ?? 'No overview available.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
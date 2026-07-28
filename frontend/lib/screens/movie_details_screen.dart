// frontend/lib/screens/movie_details_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MovieDetailsScreen extends StatefulWidget {
  final int movieId;

  const MovieDetailsScreen({super.key, required this.movieId});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isLoading = true;
  bool _isInWatchlist = false;
  bool _isLogging = false;
  Map<String, dynamic>? _movieData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await ApiService.getMovieDetails(widget.movieId);
      
      // Check if item is already in watchlist
      bool inWatchlist = false;
      try {
        final watchlist = await ApiService.getWatchlist();
        inWatchlist = watchlist.any((item) => item['movie_id'] == widget.movieId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _movieData = details;
          _isInWatchlist = inWatchlist;
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

  // Toggle Watchlist
  Future<void> _toggleWatchlist() async {
    if (_movieData == null) return;
    final title = _movieData!['title'] ?? _movieData!['name'] ?? 'Untitled';
    final poster = _movieData!['poster_path'];

    try {
      if (_isInWatchlist) {
        await ApiService.removeFromWatchlist(widget.movieId);
        setState(() => _isInWatchlist = false);
        _showSnackBar('Removed from Watchlist');
      } else {
        await ApiService.addToWatchlist(
          movieId: widget.movieId,
          movieTitle: title,
          posterPath: poster,
        );
        setState(() => _isInWatchlist = true);
        _showSnackBar('Added to Watchlist');
      }
    } catch (e) {
      _showSnackBar('Action failed: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // Log as Watched
  Future<void> _markAsWatched() async {
    if (_movieData == null || _isLogging) return;
    setState(() => _isLogging = true);

    final title = _movieData!['title'] ?? _movieData!['name'] ?? 'Untitled';
    final poster = _movieData!['poster_path'];
    final runtime = _movieData!['runtime'] ?? 120;

    try {
      await ApiService.logWatchHistory(
        movieId: widget.movieId,
        mediaType: 'movie',
        title: title,
        posterPath: poster,
        runtimeMinutes: runtime,
        userRating: 4.5, // Default or prompt rating dialog
      );
      _showSnackBar('Marked "$title" as Watched!');
    } catch (e) {
      _showSnackBar('Failed to log watch history: $e');
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE11D48))),
      );
    }

    if (_errorMessage.isNotEmpty || _movieData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: Center(
          child: Text(_errorMessage.isNotEmpty ? _errorMessage : 'Movie not found',
              style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    final title = _movieData!['title'] ?? _movieData!['name'] ?? 'Untitled';
    final overview = _movieData!['overview'] ?? 'No overview available.';
    final posterPath = _movieData!['poster_path'];
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : 'https://via.placeholder.com/500x750';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Poster
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  posterUrl,
                  height: 320,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 320,
                    width: 200,
                    color: const Color(0xFF1E293B),
                    child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 50),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markAsWatched,
                    icon: _isLogging
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Watched'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _toggleWatchlist,
                  icon: Icon(
                    _isInWatchlist ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                    color: _isInWatchlist ? const Color(0xFFE11D48) : Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF131316),
                    padding: const EdgeInsets.all(14),
                    side: const BorderSide(color: Colors.white10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Overview Section
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              overview,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
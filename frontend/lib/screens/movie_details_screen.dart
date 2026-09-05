// frontend/lib/screens/movie_details_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';

class MovieDetailsScreen extends StatefulWidget {
  final int movieId;

  const MovieDetailsScreen({super.key, required this.movieId});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isLoading = true;
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

      if (mounted) {
        setState(() {
          _movieData = details;
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
        userRating: 4.5,
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
        backgroundColor: const Color(0xFF131316),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatRuntime(int totalMinutes) {
    if (totalMinutes <= 0) return '';
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFA855F7))),
      );
    }

    if (_errorMessage.isNotEmpty || _movieData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
        ),
        body: Center(
          child: Text(
            _errorMessage.isNotEmpty ? _errorMessage : 'Movie details not found',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final title = _movieData!['title'] ?? _movieData!['name'] ?? 'Untitled';
    final overview = _movieData!['overview'] ?? 'No overview available.';
    final posterPath = _movieData!['poster_path'];
    final backdropPath = _movieData!['backdrop_path'];
    final releaseDate = _movieData!['release_date'] ?? '';
    final runtime = _movieData!['runtime'] is int
        ? (_movieData!['runtime'] as int)
        : int.tryParse(_movieData!['runtime']?.toString() ?? '0') ?? 0;
    final formattedRuntime = _formatRuntime(runtime);
    final voteAverage = (_movieData!['vote_average'] ?? 0.0).toStringAsFixed(1);
    final genres = (_movieData!['genres'] as List<dynamic>?)
            ?.map((g) => g['name'].toString())
            .toList() ??
        [];
    final cast = (_movieData!['credits']?['cast'] as List<dynamic>?) ?? [];

    final backdropUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
        : (posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '');

    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    final currentStatus = watchlistProvider.getMediaStatus(widget.movieId);
    final isWatchlist = currentStatus == 'watchlist';
    final isFavorite = currentStatus == 'favorite';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: CustomScrollView(
        slivers: [
          // Banner Backdrop Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF09090B),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: backdropUrl.isNotEmpty
                  ? Image.network(
                      backdropUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: const Color(0xFF131316)),
                    )
                  : Container(
                      color: const Color(0xFF131316),
                      child: const Center(
                        child: Icon(Icons.movie_rounded, size: 60, color: Colors.white24),
                      ),
                    ),
            ),
          ),

          // Details Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Metadata Row (Rating, Runtime, Release Year)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              voteAverage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (formattedRuntime.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          formattedRuntime,
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                      if (releaseDate.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          releaseDate.length >= 4 ? releaseDate.substring(0, 4) : releaseDate,
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Row (Watched, Watchlist, Favorite)
                  Row(
                    children: [
                      // Watched Log Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _markAsWatched,
                          icon: _isLogging
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Watched'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA855F7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Watchlist Toggle Button
                      IconButton(
                        onPressed: () async {
                          if (isWatchlist) {
                            await watchlistProvider.removeFromWatchlist(widget.movieId);
                          } else {
                            await watchlistProvider.addToWatchlist(
                              movieId: widget.movieId,
                              movieTitle: title,
                              posterPath: posterPath,
                              status: 'watchlist',
                              mediaType: 'movie',
                              releaseYear: releaseDate.length >= 4 ? releaseDate.substring(0, 4) : releaseDate,
                              runtime: runtime,
                              voteAverage: double.tryParse(voteAverage) ?? 0.0,
                            );
                          }
                        },
                        icon: Icon(
                          isWatchlist ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                          color: isWatchlist ? const Color(0xFFA855F7) : Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF131316),
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Favorite Toggle Button
                      IconButton(
                        onPressed: () async {
                          if (isFavorite) {
                            await watchlistProvider.removeFromWatchlist(widget.movieId);
                          } else {
                            await watchlistProvider.addToWatchlist(
                              movieId: widget.movieId,
                              movieTitle: title,
                              posterPath: posterPath,
                              status: 'favorite',
                              mediaType: 'movie',
                              releaseYear: releaseDate.length >= 4 ? releaseDate.substring(0, 4) : releaseDate,
                              runtime: runtime,
                              voteAverage: double.tryParse(voteAverage) ?? 0.0,
                            );
                          }
                        },
                        icon: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? Colors.redAccent : Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF131316),
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isFavorite ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Genres
                  if (genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: genres.map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131316),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            genre,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),

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
                  const SizedBox(height: 24),

                  // Cast Section
                  if (cast.isNotEmpty) ...[
                    const Text(
                      'Cast',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: cast.length,
                        itemBuilder: (context, index) {
                          final person = cast[index];
                          final personId = person['id'];
                          final personName = person['name'] ?? '';
                          final character = person['character'] ?? '';
                          final profilePath = person['profile_path'];
                          final profileUrl = profilePath != null
                              ? 'https://image.tmdb.org/t/p/w185$profilePath'
                              : '';

                          return GestureDetector(
                            onTap: () => context.go('/person/$personId'),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundColor: const Color(0xFF131316),
                                    backgroundImage: profileUrl.isNotEmpty
                                        ? NetworkImage(profileUrl)
                                        : null,
                                    child: profileUrl.isEmpty
                                        ? const Icon(Icons.person_rounded, color: Colors.white24)
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    personName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    character,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
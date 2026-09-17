// frontend/lib/screens/movie_details_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for Trailer Button
import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../models/review.dart';

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
  List<Review> _reviews = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await ApiService.getMovieDetails(widget.movieId);
      
      List<Review> fetchedReviews = [];
      try {
        fetchedReviews = await ApiService.getMovieReviews(widget.movieId);
      } catch (_) {
        // Fail silently if reviews cannot be fetched
      }

      if (mounted) {
        setState(() {
          _movieData = details;
          _reviews = fetchedReviews;
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

  // Handle Mark as Watched with Date Option
  Future<void> _markAsWatched(String title, String? poster, int runtime, String option, {String? releaseDateStr}) async {
    Navigator.pop(context); // Close the menu
    if (_isLogging) return;
    setState(() => _isLogging = true);

    // Determine the watched_at timestamp based on the selection
    DateTime? watchedAtDate;
    if (option == 'Just now' || option == 'Now watching') {
      watchedAtDate = DateTime.now().toUtc();
    } else if (option == 'Release date' && releaseDateStr != null && releaseDateStr.isNotEmpty) {
      try {
        watchedAtDate = DateTime.parse(releaseDateStr).toUtc();
      } catch (_) {
        watchedAtDate = DateTime.now().toUtc(); // Fallback
      }
    } else if (option == 'Unknown date') {
      watchedAtDate = DateTime.utc(1970, 1, 1); 
    }

    try {
      await ApiService.logWatchHistory(
        movieId: widget.movieId,
        mediaType: 'movie',
        title: title,
        posterPath: poster,
        runtimeMinutes: runtime,
        userRating: 0.0,
        watchedAt: watchedAtDate?.toIso8601String(), // Passes date to ApiService
      );
      _showSnackBar('Marked "$title" as Watched ($option)!');
    } catch (e) {
      _showSnackBar('Failed to log watch history: $e');
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  // Show the Trakt-style Options Menu for Watched
  void _showMarkWatchedMenu(String title, String? poster, int runtime, String? releaseDate) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title, 
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              
              // Options List
              _buildMenuOption(Icons.visibility_outlined, 'Now watching', () => _markAsWatched(title, poster, runtime, 'Now watching')),
              _buildMenuOption(Icons.check_rounded, 'Just now', () => _markAsWatched(title, poster, runtime, 'Just now')),
              _buildMenuOption(Icons.calendar_today_rounded, 'Release date', () => _markAsWatched(title, poster, runtime, 'Release date', releaseDateStr: releaseDate)),
              _buildMenuOption(Icons.edit_calendar_rounded, 'Other date', () => _markAsWatched(title, poster, runtime, 'Other date')),
              _buildMenuOption(Icons.help_outline_rounded, 'Unknown date', () => _markAsWatched(title, poster, runtime, 'Unknown date')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // Show Add Review Dialog
  void _showAddReviewDialog() {
    final TextEditingController reviewController = TextEditingController();
    double currentRating = 5.0;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Review', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rating:', style: TextStyle(color: Colors.white70)),
                      Text('${currentRating.toInt()}/10', style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: currentRating,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: const Color(0xFFA855F7),
                    onChanged: (val) => setDialogState(() => currentRating = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Write your thoughts...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF131316),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            await ApiService.postReview(
                              movieId: widget.movieId,
                              rating: currentRating,
                              comment: reviewController.text,
                            );
                            Navigator.pop(context); // ignore: use_build_context_synchronously
                            _fetchDetails(); // Refresh reviews
                            _showSnackBar('Review added successfully!');
                          } catch (e) {
                            _showSnackBar('Failed to post review');
                            setDialogState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7)),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper to Launch Trailer
  Future<void> _launchTrailer() async {
    // Check if backend returned video results
    final videos = _movieData!['videos']?['results'] as List<dynamic>?;
    if (videos != null && videos.isNotEmpty) {
      // Find the first official YouTube Trailer
      final trailer = videos.firstWhere(
        (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer', 
        orElse: () => videos.first,
      );
      final url = Uri.parse('https://www.youtube.com/watch?v=${trailer['key']}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }
    _showSnackBar('No trailer available');
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: const Color(0xFF131316), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatRuntime(int totalMinutes) {
    if (totalMinutes <= 0) return '';
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
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
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
        body: Center(child: Text(_errorMessage.isNotEmpty ? _errorMessage : 'Movie details not found', style: const TextStyle(color: Colors.redAccent))),
      );
    }

    final title = _movieData!['title'] ?? _movieData!['name'] ?? 'Untitled';
    final overview = _movieData!['overview'] ?? 'No overview available.';
    final posterPath = _movieData!['poster_path'];
    final backdropPath = _movieData!['backdrop_path'];
    final releaseDate = _movieData!['release_date'] ?? '';
    final releaseYear = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
    final runtime = _movieData!['runtime'] is int ? (_movieData!['runtime'] as int) : int.tryParse(_movieData!['runtime']?.toString() ?? '0') ?? 0;
    final formattedRuntime = _formatRuntime(runtime);
    final voteAverage = (_movieData!['vote_average'] ?? 0.0).toStringAsFixed(1);
    final genres = (_movieData!['genres'] as List<dynamic>?)?.map((g) => g['name'].toString()).toList() ?? [];
    final cast = (_movieData!['credits']?['cast'] as List<dynamic>?) ?? [];
    final director = (_movieData!['credits']?['crew'] as List<dynamic>?)?.firstWhere((crew) => crew['job'] == 'Director', orElse: () => null)?['name'] ?? 'Unknown Director';

    final backdropUrl = backdropPath != null ? 'https://image.tmdb.org/t/p/w1280$backdropPath' : (posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '');

    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    final currentStatus = watchlistProvider.getMediaStatus(widget.movieId, mediaType: 'movie');
    final isWatchlist = currentStatus == 'watchlist';
    final isFavorite = currentStatus == 'favorite';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: CustomScrollView(
        slivers: [
          // Banner Backdrop Header with Trailer Overlay
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF09090B),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  backdropUrl.isNotEmpty
                      ? Image.network(backdropUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF131316)))
                      : Container(color: const Color(0xFF131316), child: const Center(child: Icon(Icons.movie_rounded, size: 60, color: Colors.white24))),
                  // Dark Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, const Color(0xFF09090B).withValues(alpha: 0.9)],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                  // Trakt-style Red Trailer Button
                  GestureDetector(
                    onTap: _launchTrailer,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD92525).withValues(alpha: 0.9), // Trakt Red
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                    ),
                  ),
                ],
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
                  // Title & Where to Watch Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                            const SizedBox(height: 4),
                            Text('Directed by $director', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 8),
                            // Metadata Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFA855F7), borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(voteAverage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (releaseYear.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Text(releaseYear, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                ],
                                if (formattedRuntime.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Text('• $formattedRuntime', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Where to Watch UI
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Row(
                            children: [
                              Text('Where to Watch', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 10),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('Powered by ', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              Text('JustWatch', style: TextStyle(color: Colors.yellow[600], fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ⚡ Trakt-Style Action Row
                  Row(
                    children: [
                      // Mark as Watched Menu Button
                      InkWell(
                        onTap: () => _showMarkWatchedMenu(title, posterPath, runtime, releaseDate),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B26),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _isLogging 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFFA855F7), strokeWidth: 2))
                              : const Icon(Icons.check_rounded, color: Color(0xFFA855F7), size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Watchlist Icon Button
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (isWatchlist) {
                              await watchlistProvider.removeFromWatchlist(widget.movieId, mediaType: 'movie');
                            } else {
                              await watchlistProvider.addToWatchlist(
                                movieId: widget.movieId,
                                movieTitle: title,
                                posterPath: posterPath,
                                status: 'watchlist',
                                mediaType: 'movie',
                                releaseYear: releaseYear,
                                runtime: runtime,
                                voteAverage: double.tryParse(voteAverage) ?? 0.0,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131316),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isWatchlist ? const Color(0xFFA855F7) : Colors.white10),
                            ),
                            child: Icon(
                              isWatchlist ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                              color: isWatchlist ? const Color(0xFFA855F7) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Favorite Icon Button
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (isFavorite) {
                              await watchlistProvider.removeFromWatchlist(widget.movieId, mediaType: 'movie');
                            } else {
                              await watchlistProvider.addToWatchlist(
                                movieId: widget.movieId,
                                movieTitle: title,
                                posterPath: posterPath,
                                status: 'favorite',
                                mediaType: 'movie',
                                releaseYear: releaseYear,
                                runtime: runtime,
                                voteAverage: double.tryParse(voteAverage) ?? 0.0,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131316),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isFavorite ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white10),
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFavorite ? Colors.redAccent : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 3-Dot Options
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131316),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Genres
                  if (genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: genres.map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131316),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(genre, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),

                  // Overview
                  const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(overview, style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 14)),
                  const SizedBox(height: 24),

                  // Cast Section
                  if (cast.isNotEmpty) ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Actors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ],
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
                          final profileUrl = profilePath != null ? 'https://image.tmdb.org/t/p/w185$profilePath' : '';

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
                                    backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                                    child: profileUrl.isEmpty ? const Icon(Icons.person_rounded, color: Colors.white24) : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(personName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  Text(character, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Reviews Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      TextButton.icon(
                        onPressed: _showAddReviewDialog,
                        icon: const Icon(Icons.add_rounded, color: Color(0xFFA855F7), size: 18),
                        label: const Text('Add Review', style: TextStyle(color: Color(0xFFA855F7))),
                        style: TextButton.styleFrom(backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _reviews.isEmpty
                      ? const Text('No reviews yet for this movie.', style: TextStyle(color: Colors.white54, fontSize: 14))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _reviews.length,
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            final authorLetter = review.username.isNotEmpty ? review.username[0].toUpperCase() : '?';
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131316),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.2),
                                        child: Text(authorLetter, style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(review.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFA855F7), size: 14),
                                          const SizedBox(width: 4),
                                          Text('${review.rating}/10', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(review.comment ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
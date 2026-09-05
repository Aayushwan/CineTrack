// frontend/lib/screens/show_details_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';

class ShowDetailsScreen extends StatefulWidget {
  final int showId;

  const ShowDetailsScreen({super.key, required this.showId});

  @override
  State<ShowDetailsScreen> createState() => _ShowDetailsScreenState();
}

class _ShowDetailsScreenState extends State<ShowDetailsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _showDetails;

  @override
  void initState() {
    super.initState();
    _fetchShowDetails();
  }

  Future<void> _fetchShowDetails() async {
    try {
      final details = await ApiService.getTvDetails(widget.showId);
      if (mounted) {
        setState(() {
          _showDetails = details;
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFA855F7)),
        ),
      );
    }

    if (_errorMessage.isNotEmpty || _showDetails == null) {
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
            _errorMessage.isNotEmpty ? _errorMessage : 'Failed to load show details',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final name = _showDetails!['name'] ?? 'Untitled Show';
    final backdropPath = _showDetails!['backdrop_path'];
    final posterPath = _showDetails!['poster_path'];
    final overview = _showDetails!['overview'] ?? 'No overview available.';
    final firstAirDate = _showDetails!['first_air_date'] ?? '';
    final voteAverage = (_showDetails!['vote_average'] ?? 0.0).toStringAsFixed(1);
    final numberOfSeasons = _showDetails!['number_of_seasons'] ?? 0;
    final numberOfEpisodes = _showDetails!['number_of_episodes'] ?? 0;
    final genres = (_showDetails!['genres'] as List<dynamic>?)
            ?.map((g) => g['name'].toString())
            .toList() ??
        [];
    final cast = (_showDetails!['credits']?['cast'] as List<dynamic>?) ?? [];

    final backdropUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
        : (posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '');

    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    final currentStatus = watchlistProvider.getMediaStatus(widget.showId);
    final isWatchlist = currentStatus == 'watchlist';
    final isFavorite = currentStatus == 'favorite';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: CustomScrollView(
        slivers: [
          // Header Image & Back Button
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
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: const Color(0xFF131316)),
                    )
                  : Container(
                      color: const Color(0xFF131316),
                      child: const Center(
                        child: Icon(Icons.tv_rounded, size: 60, color: Colors.white24),
                      ),
                    ),
            ),
          ),

          // Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Metadata Row (Rating, Seasons, Episodes, Year)
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
                      const SizedBox(width: 12),
                      Text(
                        '$numberOfSeasons ${numberOfSeasons == 1 ? 'Season' : 'Seasons'} • $numberOfEpisodes Ep',
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      if (firstAirDate.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          firstAirDate.substring(0, 4),
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ⚡ Watchlist & Favorite Quick-Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (isWatchlist) {
                              await watchlistProvider.removeFromWatchlist(widget.showId);
                            } else {
                              await watchlistProvider.addToWatchlist(
                                movieId: widget.showId,
                                movieTitle: name,
                                posterPath: posterPath,
                                status: 'watchlist',
                                mediaType: 'tv',
                              );
                            }
                          },
                          icon: Icon(
                            isWatchlist ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            isWatchlist ? 'In Watchlist' : 'Watchlist',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isWatchlist ? const Color(0xFFA855F7) : const Color(0xFF131316),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (isFavorite) {
                              await watchlistProvider.removeFromWatchlist(widget.showId);
                            } else {
                              await watchlistProvider.addToWatchlist(
                                movieId: widget.showId,
                                movieTitle: name,
                                posterPath: posterPath,
                                status: 'favorite',
                                mediaType: 'tv',
                              );
                            }
                          },
                          icon: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFavorite ? Colors.redAccent : Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            isFavorite ? 'Favorited' : 'Favorite',
                            style: TextStyle(
                              color: isFavorite ? Colors.redAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF131316),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isFavorite ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

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

                  // Overview
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
                    style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 14),
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
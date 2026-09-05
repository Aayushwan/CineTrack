// frontend/lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/watchlist_provider.dart';
import '../models/watchlist_item.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _activeFilter = 'media'; // 'media', 'shows', 'movies'

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    
    List<WatchlistItem> favorites = watchlistProvider.favoriteItems;

    // Apply Filter
    if (_activeFilter == 'movies') {
      favorites = favorites.where((item) => item.mediaType.toLowerCase() == 'movie').toList();
    } else if (_activeFilter == 'shows') {
      favorites = favorites.where((item) => item.mediaType.toLowerCase() == 'tv' || item.mediaType.toLowerCase() == 'show').toList();
    }

    // Group items by Year Added to Favorites
    final Map<String, List<WatchlistItem>> groupedFavorites = {};
    for (var item in favorites) {
      String year = 'Unknown Year';
      try {
        final dynamic dItem = item;
        
        // Priority 1: Check when it was added to favorites
        final addedDate = dItem.addedAt ?? dItem.created_at;
        if (addedDate != null) {
            final DateTime parsedDate = DateTime.parse(addedDate.toString());
            year = parsedDate.year.toString();
        } else {
            // Priority 2: Fallback to current year if parsing fails or data is missing
             year = DateTime.now().year.toString();
        }
      } catch (_) {
          year = DateTime.now().year.toString();
      }

      if (!groupedFavorites.containsKey(year)) {
        groupedFavorites[year] = [];
      }
      groupedFavorites[year]!.add(item);
    }

    // Sort years descending (2026, 2025, 2024...)
    final List<String> sortedYears = groupedFavorites.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown Year') return 1;
        if (b == 'Unknown Year') return -1;
        return b.compareTo(a);
      });

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Favorites', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            Text(
              _activeFilter == 'movies' ? 'Movies' : _activeFilter == 'shows' ? 'Shows' : 'Media',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF131316),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterPill('media', 'Media', Icons.dashboard_rounded),
                _buildFilterPill('shows', 'Shows', Icons.tv_rounded),
                _buildFilterPill('movies', 'Movies', Icons.movie_creation_rounded),
              ],
            ),
          )
        ],
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Text(
                'No favorites found.',
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sortedYears.map((year) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Text(
                          year,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: groupedFavorites[year]!.map((item) {
                          return _buildFavoriteCard(context, item);
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildFilterPill(String filterValue, String label, IconData icon) {
    final isActive = _activeFilter == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFA855F7) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white60,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, WatchlistItem item) {
    final posterUrl = item.posterPath != null ? 'https://image.tmdb.org/t/p/w300${item.posterPath}' : '';
    final title = item.movieTitle;
    final mediaType = item.mediaType.isNotEmpty ? item.mediaType.toLowerCase() : 'movie';
    final id = item.movieId;

    final dynamic dItem = item;
    
    // 1. Fetch Release Year
    String releaseYearStr = '';
    try { 
      final date = dItem.releaseDate ?? dItem.release_date ?? dItem.first_air_date;
      if (date != null && date.toString().length >= 4) {
        releaseYearStr = date.toString().substring(0, 4);
      }
    } catch (_) {}
    
    // 2. Fetch Runtime (for Movies) OR Episodes (for Shows)
    String detailStr = '';
    try {
      if (mediaType == 'movie' || mediaType == 'media') {
         if (dItem.runtime != null && dItem.runtime > 0) {
            final int totalMins = dItem.runtime as int;
            final int hours = totalMins ~/ 60;
            final int mins = totalMins % 60;
            detailStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
          }
      } else {
          // It's a TV Show
          final eps = dItem.totalEpisodes ?? dItem.number_of_episodes ?? dItem.episodes;
          if (eps != null && eps > 0) {
              detailStr = '$eps eps.';
          }
      }
    } catch (_) {}

    // 3. Fetch Rating
    String ratingStr = '';
    try { 
      final vote = dItem.voteAverage ?? dItem.vote_average;
      if (vote != null && vote > 0) {
        ratingStr = '${(vote * 10).toInt()}%'; 
      }
    } catch (_) {}
    
    // 4. Fetch Genre & Certification (Only show if real data exists)
    String genre = '';
    try {
        if (dItem.genre != null) genre = dItem.genre;
    } catch(_) {}
    
    String certification = '';
    try {
        if (dItem.certification != null) certification = dItem.certification;
    } catch (_) {}

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/$mediaType/$id'),
        child: Container(
          width: 330,
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF131316),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA855F7), width: 1.5), // Purple border
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  // Poster (Left Side)
                  SizedBox(
                    width: 110,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                          child: posterUrl.isNotEmpty
                              ? Image.network(posterUrl, width: 110, height: 160, fit: BoxFit.cover)
                              : Container(color: Colors.grey[900]),
                        ),
                        // Trakt-style Checkmark
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2))
                                ],
                              ),
                              child: const Icon(Icons.check_rounded, size: 12, color: Colors.black),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),

                  // Details (Right Side)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 36, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Display actual genre if available, otherwise fallback to Media Type
                          if (genre.isNotEmpty)
                            Text(genre, style: const TextStyle(color: Colors.white54, fontSize: 12))
                          else
                            Text(mediaType.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          
                          const Spacer(),

                          // Release Year & Runtime/Episodes Row
                          if (releaseYearStr.isNotEmpty || detailStr.isNotEmpty) ...[
                            Row(
                              children: [
                                if (releaseYearStr.isNotEmpty)
                                  Text(releaseYearStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                if (releaseYearStr.isNotEmpty && detailStr.isNotEmpty)
                                  const SizedBox(width: 24),
                                if (detailStr.isNotEmpty)
                                  Text(detailStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Certification & Rating Row
                          if (certification.isNotEmpty || ratingStr.isNotEmpty)
                            Row(
                              children: [
                                if (certification.isNotEmpty)
                                  Text(certification, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                if (ratingStr.isNotEmpty) ...[
                                    const Spacer(),
                                    const Icon(Icons.star_rounded, color: Color(0xFFA855F7), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      ratingStr,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                ]
                              ],
                            )
                        ],
                      ),
                    ),
                  )
                ],
              ),
              
              // 3-Dot Options Menu
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  tooltip: 'Options',
                  onSelected: (value) {
                    if (value == 'remove') {
                      Provider.of<WatchlistProvider>(context, listen: false)
                          .removeFromWatchlist(item.movieId, mediaType: item.mediaType);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.heart_broken_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Remove Favorite', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
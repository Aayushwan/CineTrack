// frontend/lib/widgets/movie_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/watchlist_provider.dart';

class MovieCard extends StatelessWidget {
  final int id;
  final String title;
  final String imageUrl; // Can be poster or backdrop
  final String mediaType;
  final bool isLandscape; // Toggle for 16:9 vs 2:3
  final String? year;
  final double? rating; // Star rating out of 10
  final String? subtitle; // e.g., "S1 • E4 - Episode Title"
  final String? overlayLeftText; // e.g., "1h"
  final String? overlayRightText; // e.g., "7 left"
  final double? progress; // e.g., 0.5 for 50% watched

  const MovieCard({
    super.key,
    required this.id,
    required this.title,
    required this.imageUrl,
    this.mediaType = 'movie',
    this.isLandscape = false,
    this.year,
    this.rating,
    this.subtitle,
    this.overlayLeftText,
    this.overlayRightText,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (mediaType == 'tv') {
                context.go('/tv/$id');
              } else {
                context.go('/movie/$id');
              }
            },
            child: Stack(
              children: [
                // 1. Poster / Backdrop Image
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF1E293B),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl.trim().isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                              child: Icon(Icons.movie_rounded,
                                  color: Colors.white24, size: 36),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.movie_rounded,
                                color: Colors.white24, size: 36),
                          ),
                  ),
                ),

                // Gradient Overlay for readability on landscape
                if (isLandscape)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Overlay Texts (e.g., "1h" and "7 left")
                if (overlayLeftText != null || overlayRightText != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (overlayLeftText != null)
                          Text(
                            overlayLeftText!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        if (overlayRightText != null)
                          Text(
                            overlayRightText!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),

                // Progress Bar at the very bottom
                if (progress != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                        minHeight: 3,
                      ),
                    ),
                  ),

                // 2. ⚡ 3-Dot Quick-Action Menu Overlay
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    height: 26,
                    width: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (value) {
                        final watchlistProvider =
                            Provider.of<WatchlistProvider>(context, listen: false);

                        if (value == 'watchlist') {
                          watchlistProvider.addToWatchlist(
                            movieId: id,
                            movieTitle: title,
                            posterPath: imageUrl,
                            status: 'watchlist',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "$title" to Watchlist'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'favorite') {
                          watchlistProvider.addToWatchlist(
                            movieId: id,
                            movieTitle: title,
                            posterPath: imageUrl,
                            status: 'favorite',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "$title" to Favorites'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'watchlist',
                          child: Row(
                            children: [
                              Icon(Icons.bookmark_add_outlined,
                                  color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text('Watchlist',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'favorite',
                          child: Row(
                            children: [
                              Icon(Icons.favorite_border_rounded,
                                  color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text('Favorite',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Title
        GestureDetector(
          onTap: () {
            if (mediaType == 'tv') {
              context.go('/tv/$id');
            } else {
              context.go('/movie/$id');
            }
          },
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        
        // Optional Subtitle (e.g. Continue Watching episodes)
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],

        // 🌟 Metadata Row: Year (Left) & Rating (Right)
        if (year != null || (rating != null && rating! > 0)) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Year
              Text(
                year ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              
              // Right: Rating
              if (rating != null && rating! > 0)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
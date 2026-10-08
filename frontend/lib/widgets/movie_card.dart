// frontend/lib/widgets/movie_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/watchlist_provider.dart';

class MovieCard extends StatefulWidget {
  final int id;
  final String title;
  final String imageUrl; 
  final String mediaType;
  final bool isLandscape; 
  final String? year;
  final double? rating; 
  final String? subtitle; 
  final String? overlayLeftText; 
  final String? overlayRightText; 
  final double? progress; 
  final bool hideActionMenu; // 👇 Added property to allow hiding the 3-dot menu

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
    this.hideActionMenu = false, // Defaults to false so it doesn't break other screens
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isLogging = false;

  Future<void> _markAsWatched(String targetType, String option) async {
    Navigator.pop(context); 
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    if (_isLogging) return;
    setState(() => _isLogging = true);

    String exactReleaseDate = '';
    int exactRuntime = 120;
    
    try {
      if (targetType == 'movie') {
        final details = await ApiService.getMovieDetails(widget.id);
        exactReleaseDate = details['release_date'] ?? '';
        exactRuntime = details['runtime'] ?? 120;
      } else {
        final details = await ApiService.getTvDetails(widget.id);
        exactReleaseDate = details['first_air_date'] ?? '';
        if (details['episode_run_time'] != null && (details['episode_run_time'] as List).isNotEmpty) {
          exactRuntime = details['episode_run_time'][0];
        }
      }
    } catch (_) {
      exactReleaseDate = widget.year ?? '';
    }

    DateTime? watchedAtDate;
    final now = DateTime.now();

    if (option == 'Just now') {
      watchedAtDate = now.toUtc();
    } else if (option == 'Release date') {
      if (exactReleaseDate.isNotEmpty && exactReleaseDate != 'null') {
        try { 
          if (exactReleaseDate.length == 4) {
            watchedAtDate = DateTime(int.parse(exactReleaseDate), 1, 1).toUtc();
          } else {
            watchedAtDate = DateTime.parse(exactReleaseDate).toUtc(); 
          }
        } catch (_) { 
          watchedAtDate = now.toUtc(); 
        }
      } else {
        watchedAtDate = now.toUtc();
      }
    } else if (option == 'Other date') {
      if (!mounted) {
        setState(() => _isLogging = false);
        return;
      }
      
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(1900), 
        lastDate: now, 
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFA855F7), 
                onPrimary: Colors.white,
                surface: Color(0xFF131316),
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF131316)),
            ),
            child: child!,
          );
        },
      );

      if (pickedDate == null) {
        if (mounted) setState(() => _isLogging = false);
        return;
      }
      
      watchedAtDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        now.hour,
        now.minute,
        now.second,
      ).toUtc();
    }

    try {
      await ApiService.logWatchHistory(
        movieId: widget.id,
        mediaType: targetType,
        title: widget.title,
        posterPath: widget.imageUrl,
        runtimeMinutes: exactRuntime, 
        userRating: 0.0,
        watchedAt: watchedAtDate?.toIso8601String(),
      );
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Marked "${widget.title}" as Watched!', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF131316), behavior: SnackBarBehavior.floating));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to log watch history', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  void _showMarkWatchedMenu(String targetType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              _buildMenuOption(Icons.check_rounded, 'Just now', () => _markAsWatched(targetType, 'Just now')),
              _buildMenuOption(Icons.calendar_today_rounded, 'Release date', () => _markAsWatched(targetType, 'Release date')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1)),
              _buildMenuOption(Icons.edit_calendar_rounded, 'Other date', () => _markAsWatched(targetType, 'Other date')),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptions(WatchlistProvider provider, String targetType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add to Custom List', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              if (provider.customLists.isEmpty)
                const Padding(padding: EdgeInsets.all(24.0), child: Text('No custom lists found. Create one in the Lists tab!', style: TextStyle(color: Colors.white54)))
              else
                ...provider.customLists.map((listData) {
                  int listId = listData['id'];
                  String listTitle = listData['title'] ?? listData['name'];
                  return _buildMenuOption(Icons.playlist_add_rounded, listTitle, () {
                    provider.addMediaToList(
                      listId, 
                      widget.id, 
                      widget.imageUrl,
                      title: widget.title,
                      mediaType: targetType,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "${widget.title}" to "$listTitle"', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF131316), behavior: SnackBarBehavior.floating));
                  });
                }),
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

  @override
  Widget build(BuildContext context) {
    final normalizedType = widget.mediaType.toLowerCase();
    final isTvShow = normalizedType == 'tv' || normalizedType == 'show';
    final targetType = isTvShow ? 'tv' : 'movie';
    final targetRoute = '/$targetType/${widget.id}';
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.go(targetRoute),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF1E293B),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.imageUrl.trim().isNotEmpty
                        ? Image.network(
                            widget.imageUrl,
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

                if (widget.isLandscape)
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

                if (widget.overlayLeftText != null || widget.overlayRightText != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.overlayLeftText != null)
                          Text(
                            widget.overlayLeftText!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        if (widget.overlayRightText != null)
                          Text(
                            widget.overlayRightText!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),

                if (widget.progress != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                      child: LinearProgressIndicator(
                        value: widget.progress,
                        backgroundColor: Colors.white24,
                        color: const Color(0xFFA855F7),
                        minHeight: 3,
                      ),
                    ),
                  ),

                // 👇 Wrapped in an if block to allow hiding in Custom Lists
                if (!widget.hideActionMenu)
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
                        color: const Color(0xFF131316),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white12),
                        ),
                        onSelected: (value) async {
                          if (value == 'watchlist') {
                            final isWatchlist = watchlistProvider.getMediaStatus(widget.id, mediaType: targetType) == 'watchlist';
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            
                            if (isWatchlist) {
                              await watchlistProvider.removeFromWatchlist(widget.id, mediaType: targetType);
                              scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Removed from Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                            } else {
                              String exactDate = '';
                              int runtime = 120;
                              try {
                                if (targetType == 'movie') {
                                  final details = await ApiService.getMovieDetails(widget.id);
                                  exactDate = details['release_date'] ?? '';
                                  runtime = details['runtime'] ?? 120;
                                } else {
                                  final details = await ApiService.getTvDetails(widget.id);
                                  exactDate = details['first_air_date'] ?? '';
                                  if (details['episode_run_time'] != null && (details['episode_run_time'] as List).isNotEmpty) {
                                    runtime = details['episode_run_time'][0];
                                  }
                                }
                              } catch (_) {}

                              await watchlistProvider.addToWatchlist(
                                movieId: widget.id, 
                                movieTitle: widget.title, 
                                posterPath: widget.imageUrl, 
                                status: 'watchlist', 
                                mediaType: targetType, 
                                releaseYear: exactDate, 
                                runtime: runtime, 
                                voteAverage: widget.rating ?? 0.0
                              );
                              scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Added to Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                            }
                          } else if (value == 'track') {
                            _showMarkWatchedMenu(targetType);
                          } else if (value == 'manage') {
                            _showMoreOptions(watchlistProvider, targetType);
                          }
                        },
                        itemBuilder: (context) {
                          final isWatchlist = watchlistProvider.getMediaStatus(widget.id, mediaType: targetType) == 'watchlist';
                          return [
                            PopupMenuItem(
                              value: 'watchlist',
                              child: Row(
                                children: [
                                  Icon(isWatchlist ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(isWatchlist ? 'Remove from Watchlist' : 'Watchlist', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'track',
                              child: Row(
                                children: [
                                  Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Track', style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'manage',
                              child: Row(
                                children: [
                                  Icon(Icons.list_alt_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Manage List', style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        GestureDetector(
          onTap: () => context.go(targetRoute),
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],

        if (widget.year != null || (widget.rating != null && widget.rating! > 0)) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.year ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              
              if (widget.rating != null && widget.rating! > 0)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12),
                    const SizedBox(width: 3),
                    Text(
                      widget.rating!.toStringAsFixed(1),
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
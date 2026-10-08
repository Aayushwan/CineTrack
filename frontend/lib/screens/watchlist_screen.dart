// frontend/lib/screens/watchlist_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/trakt_filter_bar.dart';
import '../providers/watchlist_provider.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  bool _isLoading = true;
  bool _isLogging = false;
  List<dynamic> _allWatchlistItems = [];
  List<dynamic> _filteredItems = [];

  String _selectedFilter = 'media';

  @override
  void initState() {
    super.initState();
    _fetchWatchlist();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WatchlistProvider>(context, listen: false).fetchCustomLists();
    });
  }

  Future<void> _fetchWatchlist() async {
    setState(() => _isLoading = true);
    try {
      final items = await ApiService.getWatchlist();
      if (mounted) {
        setState(() {
          _allWatchlistItems = items;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    _filteredItems = _allWatchlistItems.where((item) {
      final mediaType = (item['media_type'] ?? item['type'] ?? 'movie').toString().toLowerCase();
      final bool isTv = mediaType == 'tv' || mediaType == 'show';

      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'movies' && isTv) return false;

      return true;
    }).toList();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  Future<void> _removeFromWatchlist(int movieId, String title) async {
    try {
      await ApiService.removeFromWatchlist(movieId);
      if (mounted) {
        setState(() {
          _allWatchlistItems.removeWhere((item) => (item['movie_id'] ?? item['id']) == movieId);
          _applyFilter();
        });
        Provider.of<WatchlistProvider>(context, listen: false).fetchWatchlist();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove item', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _markAsWatched(dynamic item, String mediaType, String option) async {
    Navigator.pop(context); 
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    if (_isLogging) return;
    setState(() => _isLogging = true);

    final title = item['title'] ?? item['movie_title'] ?? item['name'] ?? 'Untitled';
    final poster = item['poster_path'];
    final releaseDateStr = (item['release_year'] ?? item['release_date'] ?? item['first_air_date'] ?? '').toString();

    DateTime? watchedAtDate;
    final now = DateTime.now();

    if (option == 'Just now') {
      watchedAtDate = now.toUtc();
    } else if (option == 'Release date') {
      if (releaseDateStr.isNotEmpty && releaseDateStr != 'null') {
        try { 
          if (releaseDateStr.length == 4) {
             watchedAtDate = DateTime(int.parse(releaseDateStr), 1, 1).toUtc();
          } else {
             watchedAtDate = DateTime.parse(releaseDateStr).toUtc(); 
          }
        } catch (_) { 
          watchedAtDate = now.toUtc(); 
        }
      } else {
        watchedAtDate = now.toUtc();
      }
    } else if (option == 'Other date') {
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
        movieId: item['movie_id'] ?? item['id'],
        mediaType: mediaType,
        title: title,
        posterPath: poster,
        runtimeMinutes: 120, 
        userRating: 0.0,
        watchedAt: watchedAtDate?.toIso8601String(),
      );
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Marked "$title" as Watched!', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF131316), behavior: SnackBarBehavior.floating));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to log watch history: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  void _showMarkWatchedMenu(dynamic item, String mediaType) {
    final title = item['title'] ?? item['movie_title'] ?? item['name'] ?? 'Untitled';
    
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
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              _buildMenuOption(Icons.check_rounded, 'Just now', () => _markAsWatched(item, mediaType, 'Just now')),
              _buildMenuOption(Icons.calendar_today_rounded, 'Release date', () => _markAsWatched(item, mediaType, 'Release date')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1)),
              _buildMenuOption(Icons.edit_calendar_rounded, 'Other date', () => _markAsWatched(item, mediaType, 'Other date')),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptions(WatchlistProvider provider, dynamic item, String mediaType) {
    final title = item['title'] ?? item['movie_title'] ?? item['name'] ?? 'Untitled';
    final posterPath = item['poster_path'];
    final id = item['movie_id'] ?? item['id'];
    
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
                    provider.addMediaToList(listId, id, posterPath);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "$title" to "$listTitle"', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF131316), behavior: SnackBarBehavior.floating));
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
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Watchlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: _onFilterChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFA855F7)),
                    )
                  : _filteredItems.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(0xFFA855F7),
                          backgroundColor: const Color(0xFF131316),
                          onRefresh: _fetchWatchlist,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              final String mediaTypeStr = (item['media_type'] ?? item['type'] ?? 'movie').toString().toLowerCase();
                              
                              return _WatchlistGridCard(
                                item: item,
                                provider: watchlistProvider,
                                mediaTypeStr: mediaTypeStr,
                                onRemove: (id, title) => _removeFromWatchlist(id, title),
                                onTrack: () => _showMarkWatchedMenu(item, mediaTypeStr),
                                onManage: () => _showMoreOptions(watchlistProvider, item, mediaTypeStr),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String filterText = 'items';
    if (_selectedFilter == 'shows') filterText = 'shows';
    if (_selectedFilter == 'movies') filterText = 'movies';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_outline_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Your Watchlist is Empty',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'media'
                  ? 'Items you bookmark from Home or Discover will show up here.'
                  : 'No $filterText found matching your active criteria.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistGridCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final WatchlistProvider provider;
  final String mediaTypeStr;
  final Function(int id, String title) onRemove;
  final VoidCallback onTrack;
  final VoidCallback onManage;

  const _WatchlistGridCard({
    required this.item,
    required this.provider,
    required this.mediaTypeStr,
    required this.onRemove,
    required this.onTrack,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final int id = item['movie_id'] ?? item['id'] ?? 0;
    final String title = item['movie_title'] ?? item['title'] ?? item['name'] ?? 'Untitled';
    final bool isTv = mediaTypeStr == 'tv' || mediaTypeStr == 'show';

    final String imagePath = item['poster_path'] ?? '';
    final String imageUrl = imagePath.isNotEmpty
        ? (imagePath.startsWith('http') ? imagePath : 'https://image.tmdb.org/t/p/w500$imagePath')
        : '';

    final double ratingVal = double.tryParse((item['vote_average'] ?? item['rating'] ?? 0.0).toString()) ?? 0.0;
    final String ratingStr = ratingVal > 0 ? ratingVal.toStringAsFixed(1) : '0.0';

    return GestureDetector(
      onTap: () {
        if (isTv) {
          context.go('/tv/$id');
        } else {
          context.go('/movie/$id');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: const Color(0xFF1E1E24),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.movie_rounded, color: Colors.white24, size: 40),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.movie_rounded, color: Colors.white24, size: 40),
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isTv ? 'TV' : 'MOVIE',
                      style: const TextStyle(
                        color: Color(0xFFA855F7),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                      color: const Color(0xFF131316),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.white10),
                      ),
                      onSelected: (value) async {
                        if (value == 'watchlist') {
                          final isWatchlist = provider.getMediaStatus(id, mediaType: mediaTypeStr) == 'watchlist';
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          
                          if (isWatchlist) {
                            await provider.removeFromWatchlist(id, mediaType: mediaTypeStr);
                            onRemove(id, title);
                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Removed from Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                          } else {
                            final fullDateStr = (item['release_year'] ?? item['release_date'] ?? item['first_air_date'] ?? '').toString();
                            final voteAverage = double.tryParse((item['vote_average'] ?? 0.0).toString()) ?? 0.0;
                            await provider.addToWatchlist(
                              movieId: id, 
                              movieTitle: title, 
                              posterPath: imagePath, 
                              status: 'watchlist', 
                              mediaType: mediaTypeStr, 
                              releaseYear: fullDateStr, 
                              runtime: 120, 
                              voteAverage: voteAverage
                            );
                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Added to Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                          }
                        } else if (value == 'track') {
                          onTrack();
                        } else if (value == 'manage') {
                          onManage();
                        }
                      },
                      itemBuilder: (context) {
                        final isWatchlist = provider.getMediaStatus(id, mediaType: mediaTypeStr) == 'watchlist';
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
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          
          if (ratingVal > 0)
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12),
                const SizedBox(width: 4),
                Text(
                  ratingStr,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
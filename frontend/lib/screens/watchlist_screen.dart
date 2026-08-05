// frontend/lib/screens/watchlist_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/trakt_filter_bar.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  List<dynamic> _allWatchlistItems = [];
  List<dynamic> _filteredItems = [];

  // Active Trakt Capsule Filter: 'media', 'shows', 'movies'
  String _selectedFilter = 'media';

  // Active Sidebar Filters
  String _selectedGenre = 'All';
  String _selectedStatus = 'All';
  String _selectedDecade = 'All';

  @override
  void initState() {
    super.initState();
    _fetchWatchlist();
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

      // 1. Trakt Media Type Filter
      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'movies' && isTv) return false;

      // 2. Sidebar Genre Filter
      if (_selectedGenre != 'All') {
        final List<dynamic> genreIds = item['genre_ids'] ?? [];
        final targetGenreId = FilterDrawer.genreMap[_selectedGenre];
        if (targetGenreId != null && !genreIds.contains(targetGenreId)) return false;
      }

      // 3. Sidebar Status Filter
      if (_selectedStatus != 'All') {
        final dateStr = item['release_date'] ?? item['first_air_date'] ?? '';
        final isUpcoming = dateStr.isNotEmpty && (DateTime.tryParse(dateStr)?.isAfter(DateTime.now()) ?? false);
        if (_selectedStatus == 'Upcoming' && !isUpcoming) return false;
        if (_selectedStatus == 'Released' && isUpcoming) return false;
      }

      // 4. Sidebar Decade Filter
      if (_selectedDecade != 'All') {
        final dateStr = item['release_date'] ?? item['first_air_date'] ?? item['year'] ?? '';
        final year = DateTime.tryParse(dateStr)?.year ?? int.tryParse(dateStr.length >= 4 ? dateStr.substring(0, 4) : '');
        if (year != null) {
          if (_selectedDecade == 'This Year' && year != 2026) return false;
          if (_selectedDecade == '2020s' && (year < 2020 || year > 2029)) return false;
          if (_selectedDecade == '2010s' && (year < 2010 || year > 2019)) return false;
          if (_selectedDecade == '2000s' && (year < 2000 || year > 2009)) return false;
          if (_selectedDecade == '1990s' && (year < 1990 || year > 1999)) return false;
          if (_selectedDecade == '1980s' && (year < 1980 || year > 1989)) return false;
          if (_selectedDecade == '1970s' && (year < 1970 || year > 1979)) return false;
          if (_selectedDecade == '1960s' && (year < 1960 || year > 1969)) return false;
          if (_selectedDecade == 'Before 1960' && year >= 1960) return false;
        }
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$title" from Watchlist'),
            backgroundColor: const Color(0xFF131316),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove item from watchlist'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  bool get _hasActiveSidebarFilters =>
      _selectedGenre != 'All' || _selectedStatus != 'All' || _selectedDecade != 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF09090B),
      endDrawer: FilterDrawer(
        selectedGenre: _selectedGenre,
        selectedStatus: _selectedStatus,
        selectedDecade: _selectedDecade,
        onApply: (genre, status, decade) {
          setState(() {
            _selectedGenre = genre;
            _selectedStatus = status;
            _selectedDecade = decade;
            _applyFilter();
          });
        },
        onReset: () {
          setState(() {
            _selectedGenre = 'All';
            _selectedStatus = 'All';
            _selectedDecade = 'All';
            _applyFilter();
          });
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── STICKY TOP HEADER (PERSISTENT ON SCROLL) ────────────────────
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

                  // Sticky Trakt Filter Capsule
                  TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: _onFilterChanged,
                  ),
                  const SizedBox(width: 8),

                  // Sticky Filter Drawer Trigger Button
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    icon: Stack(
                      children: [
                        const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                        if (_hasActiveSidebarFilters)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFA855F7),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF131316),
                      padding: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── SCROLLABLE VERTICAL GRID SECTION ─────────────────────────────
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
                              return _WatchlistGridCard(
                                item: item,
                                onRemove: (id, title) => _removeFromWatchlist(id, title),
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
              _selectedFilter == 'media' && !_hasActiveSidebarFilters
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

// ─────────────────────────────────────────────────────────────────────────────
// VERTICAL GRID POSTER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _WatchlistGridCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(int id, String title) onRemove;

  const _WatchlistGridCard({
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final int movieId = item['movie_id'] ?? item['id'] ?? 0;
    final String title = item['movie_title'] ?? item['title'] ?? item['name'] ?? 'Untitled';
    final String rawMediaType = (item['media_type'] ?? item['type'] ?? 'movie').toString().toLowerCase();
    final bool isTv = rawMediaType == 'tv' || rawMediaType == 'show';
    final String mediaTypeLabel = isTv ? 'tv' : 'movie';

    final String posterPath = item['poster_path'] ?? '';
    final String imageUrl = posterPath.isNotEmpty
        ? (posterPath.startsWith('http') ? posterPath : 'https://image.tmdb.org/t/p/w500$posterPath')
        : '';

    final String dateStr = item['release_date'] ?? item['first_air_date'] ?? item['year'] ?? '';
    final String year = dateStr.length >= 4 ? dateStr.substring(0, 4) : '2026';

    final double ratingVal = (item['vote_average'] ?? item['rating'] ?? 0.0).toDouble();
    final String ratingStr = ratingVal > 0 ? ratingVal.toStringAsFixed(1) : '7.5';

    return GestureDetector(
      onTap: () {
        if (isTv) {
          context.go('/tv/$movieId');
        } else {
          context.go('/movie/$movieId');
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

                // Top Left Media Type Tag (Movie / TV)
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
                      mediaTypeLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFA855F7),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Top Right Options Popup Menu (Remove Action)
                Positioned(
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                    ),
                    color: const Color(0xFF131316),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.white12),
                    ),
                    onSelected: (value) {
                      if (value == 'remove') {
                        onRemove(movieId, title);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.bookmark_remove_rounded, color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text('Remove from Watchlist', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Bookmark Badge
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      color: Color(0xFFA855F7),
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Title
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

          // Metadata Row (Year & Rating)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.public_rounded, color: Colors.white38, size: 11),
                  const SizedBox(width: 4),
                  Text(
                    year,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12),
                  const SizedBox(width: 2),
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
        ],
      ),
    );
  }
}
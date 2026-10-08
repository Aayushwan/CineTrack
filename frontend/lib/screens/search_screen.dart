// frontend/lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/trakt_filter_bar.dart';
import '../providers/watchlist_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'media';
  bool _isLoading = false;
  bool _isLogging = false;
  String _errorMessage = '';
  List<dynamic> _searchResults = [];

  String _selectedGenre = 'All';
  String _selectedStatus = 'All';
  String _selectedDecade = 'All';

  final Map<String, int> _genreMap = {
    'Action': 28, 'Adventure': 12, 'Animation': 16, 'Comedy': 35,
    'Crime': 80, 'Documentary': 99, 'Drama': 18, 'Family': 10749,
    'Fantasy': 14, 'Horror': 27, 'Mystery': 9648, 'Romance': 10749,
    'Sci-Fi': 878, 'Thriller': 53,
  };

  final List<String> _statuses = ['All', 'Released', 'Upcoming'];

  final List<String> _decades = [
    'All', 'This Year', '2020s', '2010s', '2000s',
    '1990s', '1980s', '1970s', '1960s', 'Before 1960',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WatchlistProvider>(context, listen: false).fetchCustomLists();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.searchMovies(query);
      final results = response['results'] ?? [];

      if (mounted) {
        setState(() {
          _searchResults = results;
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

  Future<void> _markAsWatched(dynamic item, String mediaType, String option) async {
    Navigator.pop(context); 
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    if (_isLogging) return;
    setState(() => _isLogging = true);

    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final poster = item['poster_path'];
    final releaseDateStr = item['release_date'] ?? item['first_air_date'];

    DateTime? watchedAtDate;
    final now = DateTime.now();

    if (option == 'Just now') {
      watchedAtDate = now.toUtc();
    } else if (option == 'Release date') {
      if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
        try { watchedAtDate = DateTime.parse(releaseDateStr).toUtc(); } catch (_) { watchedAtDate = now.toUtc(); }
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
        movieId: item['id'],
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
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    
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
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final posterPath = item['poster_path'];
    final id = item['id'];
    
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

  List<dynamic> get _filteredResults {
    return _searchResults.where((item) {
      final String rawMediaType = (item['media_type'] ?? '').toString().toLowerCase();

      final bool isPerson = rawMediaType == 'person' ||
          item['known_for'] != null ||
          (item['profile_path'] != null && item['title'] == null && item['name'] != null);

      final bool isTv = !isPerson &&
          (rawMediaType == 'tv' ||
              rawMediaType == 'show' ||
              item['first_air_date'] != null ||
              (item['name'] != null && item['title'] == null));

      final bool isMovie = !isPerson && !isTv;

      if (_selectedFilter == 'movies' && !isMovie) return false;
      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'people' && !isPerson) return false;
      if (_selectedFilter == 'media' && isPerson) return false; 

      if (isPerson) return true;

      if (_selectedGenre != 'All') {
        final List<dynamic> genreIds = item['genre_ids'] ?? [];
        final targetGenreId = _genreMap[_selectedGenre];
        if (targetGenreId != null && !genreIds.contains(targetGenreId)) {
          return false;
        }
      }

      if (_selectedStatus != 'All') {
        final releaseDateStr = item['release_date'] ?? item['first_air_date'] ?? '';
        final derivedStatus = _deriveStatus(releaseDateStr, item['status']);
        if (derivedStatus.toLowerCase() != _selectedStatus.toLowerCase()) {
          return false;
        }
      }

      if (_selectedDecade != 'All') {
        final releaseDateStr = item['release_date'] ?? item['first_air_date'] ?? '';
        if (!_matchesDecade(releaseDateStr, _selectedDecade)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _deriveStatus(String dateStr, String? explicitStatus) {
    if (explicitStatus != null && explicitStatus.isNotEmpty) {
      if (explicitStatus.toLowerCase().contains('upcom') ||
          explicitStatus.toLowerCase().contains('in prod')) {
        return 'Upcoming';
      }
      return 'Released';
    }
    if (dateStr.isEmpty) return 'Released';

    final releaseDate = DateTime.tryParse(dateStr);
    if (releaseDate == null) return 'Released';

    final now = DateTime.now();
    return releaseDate.isAfter(now) ? 'Upcoming' : 'Released';
  }

  bool _matchesDecade(String dateStr, String decade) {
    if (dateStr.isEmpty) return false;
    final year = DateTime.tryParse(dateStr)?.year;
    if (year == null) return false;

    switch (decade) {
      case 'This Year':
        return year == 2026;
      case '2020s':
        return year >= 2020 && year <= 2029;
      case '2010s':
        return year >= 2010 && year <= 2019;
      case '2000s':
        return year >= 2000 && year <= 2009;
      case '1990s':
        return year >= 1990 && year <= 1999;
      case '1980s':
        return year >= 1980 && year <= 1989;
      case '1970s':
        return year >= 1970 && year <= 1979;
      case '1960s':
        return year >= 1960 && year <= 1969;
      case 'Before 1960':
        return year < 1960;
      default:
        return true;
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedGenre = 'All';
      _selectedStatus = 'All';
      _selectedDecade = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredResults;
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF09090B),
      endDrawer: _buildFilterDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131316),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _performSearch,
                        decoration: const InputDecoration(
                          hintText: 'Search movies, TV shows, actors...',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    icon: Stack(
                      children: [
                        const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                        if (_selectedGenre != 'All' ||
                            _selectedStatus != 'All' ||
                            _selectedDecade != 'All')
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
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.white10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TraktFilterBar(
                selectedFilter: _selectedFilter,
                showPeople: true,
                onFilterChanged: (newFilter) {
                  setState(() => _selectedFilter = newFilter);
                },
              ),
              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFA855F7)),
                      )
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          )
                        : filteredList.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.isEmpty
                                      ? 'Search for titles or persons to get started'
                                      : 'No results found matching criteria',
                                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                                ),
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 180,
                                  childAspectRatio: 0.62,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final item = filteredList[index];
                                  final id = item['id'];
                                  final title = item['title'] ?? item['name'] ?? 'Untitled';

                                  final imagePath = item['poster_path'] ?? item['profile_path'];
                                  final imageUrl = (imagePath != null && imagePath.toString().trim().isNotEmpty)
                                      ? 'https://image.tmdb.org/t/p/w500$imagePath'
                                      : '';

                                  final rawMediaType = (item['media_type'] ?? '').toString().toLowerCase();

                                  final bool isPerson = rawMediaType == 'person' ||
                                      item['known_for'] != null ||
                                      (item['profile_path'] != null && item['title'] == null && item['name'] != null);

                                  final bool isTv = !isPerson &&
                                      (rawMediaType == 'tv' ||
                                          rawMediaType == 'show' ||
                                          item['first_air_date'] != null ||
                                          (item['name'] != null && item['title'] == null));

                                  final bool isMovie = !isPerson && !isTv;
                                  final String mediaTypeStr = isTv ? 'tv' : 'movie';
                                  final String badgeText = isPerson ? 'PERSON' : (isTv ? 'TV' : 'MOVIE');

                                  return GestureDetector(
                                    onTap: () {
                                      if (isMovie) {
                                        context.go('/movie/$id');
                                      } else if (isTv) {
                                        context.go('/tv/$id');
                                      } else if (isPerson) {
                                        context.go('/person/$id');
                                      }
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                height: double.infinity,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  color: const Color(0xFF1E293B),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: imageUrl.isNotEmpty
                                                      ? Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.cover,
                                                          width: double.infinity,
                                                          errorBuilder: (context, error, stackTrace) => Center(
                                                            child: Icon(
                                                              isPerson ? Icons.person_rounded : Icons.movie_rounded,
                                                              color: Colors.white24,
                                                              size: 40,
                                                            ),
                                                          ),
                                                        )
                                                      : Center(
                                                          child: Icon(
                                                            isPerson ? Icons.person_rounded : Icons.movie_rounded,
                                                            color: Colors.white24,
                                                            size: 40,
                                                          ),
                                                        ),
                                                ),
                                              ),

                                              Positioned(
                                                top: 6,
                                                left: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.75),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    badgeText,
                                                    style: const TextStyle(
                                                      color: Color(0xFFA855F7),
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              if (!isPerson)
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
                                                          final isWatchlist = watchlistProvider.getMediaStatus(id, mediaType: mediaTypeStr) == 'watchlist';
                                                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                                                          
                                                          if (isWatchlist) {
                                                            await watchlistProvider.removeFromWatchlist(id, mediaType: mediaTypeStr);
                                                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Removed from Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                                                          } else {
                                                            final releaseYear = (item['release_date'] ?? item['first_air_date'] ?? '').toString();
                                                            final yearStr = releaseYear.length >= 4 ? releaseYear.substring(0, 4) : '';
                                                            final voteAverage = double.tryParse((item['vote_average'] ?? 0.0).toString()) ?? 0.0;
                                                            await watchlistProvider.addToWatchlist(
                                                              movieId: id, 
                                                              movieTitle: title, 
                                                              posterPath: imagePath, 
                                                              status: 'watchlist', 
                                                              mediaType: mediaTypeStr, 
                                                              releaseYear: yearStr, 
                                                              runtime: 120, 
                                                              voteAverage: voteAverage
                                                            );
                                                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Added to Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                                                          }
                                                        } else if (value == 'track') {
                                                          _showMarkWatchedMenu(item, mediaTypeStr);
                                                        } else if (value == 'manage') {
                                                          _showMoreOptions(watchlistProvider, item, mediaTypeStr);
                                                        }
                                                      },
                                                      itemBuilder: (context) {
                                                        final isWatchlist = watchlistProvider.getMediaStatus(id, mediaType: mediaTypeStr) == 'watchlist';
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
                                        const SizedBox(height: 6),
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isPerson && item['known_for_department'] != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item['known_for_department'],
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF131316),
      width: 320,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),

              Expanded(
                child: ListView(
                  children: [
                    _buildDropdownLabel('Genre'),
                    _buildDropdown(
                      value: _selectedGenre,
                      items: ['All', ..._genreMap.keys],
                      onChanged: (val) => setState(() => _selectedGenre = val!),
                    ),
                    const SizedBox(height: 18),

                    _buildDropdownLabel('Status'),
                    _buildDropdown(
                      value: _selectedStatus,
                      items: _statuses,
                      onChanged: (val) => setState(() => _selectedStatus = val!),
                    ),
                    const SizedBox(height: 18),

                    _buildDropdownLabel('Decade'),
                    _buildDropdown(
                      value: _selectedDecade,
                      items: _decades,
                      onChanged: (val) => setState(() => _selectedDecade = val!),
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFilters,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA855F7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
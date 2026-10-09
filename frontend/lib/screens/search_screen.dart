// frontend/lib/screens/search_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../widgets/trakt_filter_bar.dart';

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
    'Action': 28,
    'Adventure': 12,
    'Animation': 16,
    'Comedy': 35,
    'Crime': 80,
    'Documentary': 99,
    'Drama': 18,
    'Family': 10749,
    'Fantasy': 14,
    'Horror': 27,
    'Mystery': 9648,
    'Romance': 10749,
    'Sci-Fi': 878,
    'Thriller': 53,
  };

  final List<String> _statuses = ['All', 'Released', 'Upcoming'];

  final List<String> _decades = [
    'All',
    'This Year',
    '2020s',
    '2010s',
    '2000s',
    '1990s',
    '1980s',
    '1970s',
    '1960s',
    'Before 1960',
  ];

  bool get _hasActiveFilters {
    return _selectedGenre != 'All' ||
        _selectedStatus != 'All' ||
        _selectedDecade != 'All';
  }

  int get _activeFilterCount {
    int count = 0;

    if (_selectedGenre != 'All') count++;
    if (_selectedStatus != 'All') count++;
    if (_selectedDecade != 'All') count++;

    return count;
  }

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

  Future<void> _markAsWatched(
    dynamic item,
    String mediaType,
    String option,
  ) async {
    Navigator.pop(context);

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_isLogging) return;

    setState(() {
      _isLogging = true;
    });

    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final poster = item['poster_path'];
    final releaseDateStr = item['release_date'] ?? item['first_air_date'];

    DateTime? watchedAtDate;
    final now = DateTime.now();

    if (option == 'Just now') {
      watchedAtDate = now.toUtc();
    } else if (option == 'Release date') {
      if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
        try {
          watchedAtDate = DateTime.parse(releaseDateStr).toUtc();
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
                surface: Color(0xFF15151B),
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF15151B),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedDate == null) {
        if (mounted) {
          setState(() {
            _isLogging = false;
          });
        }

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

      scaffoldMessenger.showSnackBar(
        _buildSnackBar('Marked "$title" as watched'),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to log watch history: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFE34D67),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }

  void _showMarkWatchedMenu(dynamic item, String mediaType) {
    final title = item['title'] ?? item['name'] ?? 'Untitled';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151B),
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF45404B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB143EB), Color(0xFF8431D9)],
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mark as watched',
                              style: TextStyle(
                                color: Color(0xFFF5F3F8),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF817C87),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF202026),
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFC1BBC6),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2D2933), height: 1),
                const SizedBox(height: 8),
                _buildMenuOption(
                  Icons.bolt_rounded,
                  'Just now',
                  () => _markAsWatched(item, mediaType, 'Just now'),
                ),
                _buildMenuOption(
                  Icons.calendar_today_rounded,
                  'Release date',
                  () => _markAsWatched(item, mediaType, 'Release date'),
                ),
                _buildMenuOption(
                  Icons.edit_calendar_rounded,
                  'Other date',
                  () => _markAsWatched(item, mediaType, 'Other date'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreOptions(
    WatchlistProvider provider,
    dynamic item,
    String mediaType,
  ) {
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final posterPath = item['poster_path'];
    final id = item['id'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151B),
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF45404B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB143EB), Color(0xFF8431D9)],
                          ),
                        ),
                        child: const Icon(
                          Icons.playlist_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add to custom list',
                          style: TextStyle(
                            color: Color(0xFFF5F3F8),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF202026),
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFC1BBC6),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2D2933), height: 1),
                const SizedBox(height: 8),
                if (provider.customLists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.playlist_add_rounded,
                          color: Color(0xFF655F6B),
                          size: 34,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No custom lists found.\nCreate one in the Lists tab.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF817C87),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...provider.customLists.map((listData) {
                    final int listId = listData['id'];
                    final String listTitle =
                        listData['title'] ?? listData['name'];

                    return _buildMenuOption(
                      Icons.playlist_add_rounded,
                      listTitle,
                      () {
                        provider.addMediaToList(listId, id, posterPath);

                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          _buildSnackBar('Added "$title" to "$listTitle"'),
                        );
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF271630),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4B2A59)),
                  ),
                  child: Icon(icon, color: const Color(0xFFCA66FF), size: 19),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFE8E4EB),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF69636E),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<dynamic> get _filteredResults {
    return _searchResults.where((item) {
      final String rawMediaType = (item['media_type'] ?? '')
          .toString()
          .toLowerCase();

      final bool isPerson =
          rawMediaType == 'person' ||
          item['known_for'] != null ||
          (item['profile_path'] != null &&
              item['title'] == null &&
              item['name'] != null);

      final bool isTv =
          !isPerson &&
          (rawMediaType == 'tv' ||
              rawMediaType == 'show' ||
              item['first_air_date'] != null ||
              (item['name'] != null && item['title'] == null));

      final bool isMovie = !isPerson && !isTv;

      if (_selectedFilter == 'movies' && !isMovie) {
        return false;
      }

      if (_selectedFilter == 'shows' && !isTv) {
        return false;
      }

      if (_selectedFilter == 'people' && !isPerson) {
        return false;
      }

      if (_selectedFilter == 'media' && isPerson) {
        return false;
      }

      if (isPerson) return true;

      if (_selectedGenre != 'All') {
        final List<dynamic> genreIds = item['genre_ids'] ?? [];
        final targetGenreId = _genreMap[_selectedGenre];

        if (targetGenreId != null && !genreIds.contains(targetGenreId)) {
          return false;
        }
      }

      if (_selectedStatus != 'All') {
        final releaseDateStr =
            item['release_date'] ?? item['first_air_date'] ?? '';

        final derivedStatus = _deriveStatus(releaseDateStr, item['status']);

        if (derivedStatus.toLowerCase() != _selectedStatus.toLowerCase()) {
          return false;
        }
      }

      if (_selectedDecade != 'All') {
        final releaseDateStr =
            item['release_date'] ?? item['first_air_date'] ?? '';

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
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF08080B),
      endDrawer: _buildFilterDrawer(),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, -0.9),
                  radius: 1.15,
                  colors: [Color(0x292A0A42), Color(0xFF08080B)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -180,
            right: -140,
            child: _buildBackgroundGlow(
              size: 420,
              color: const Color(0xFF9E3DDA),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 700
                    ? 16.0
                    : 28.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchHeader(),
                      const SizedBox(height: 18),
                      TraktFilterBar(
                        selectedFilter: _selectedFilter,
                        showPeople: true,
                        onFilterChanged: (newFilter) {
                          setState(() {
                            _selectedFilter = newFilter;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      Expanded(child: _buildResultsContent(watchlistProvider)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xE615151B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2D2933)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Color(0xFFF5F3F8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFFBD4DFF),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              decoration: const InputDecoration(
                hintText: 'Search movies, TV shows, actors...',
                hintStyle: TextStyle(color: Color(0xFF68626E), fontSize: 14),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 6, right: 2),
                  child: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF77717D),
                    size: 23,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 19,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _hasActiveFilters
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFB143EB), Color(0xFF8431D9)],
                      )
                    : null,
                color: _hasActiveFilters ? null : const Color(0xE615151B),
                border: Border.all(
                  color: _hasActiveFilters
                      ? const Color(0xFFCA66FF)
                      : const Color(0xFF2D2933),
                ),
                boxShadow: _hasActiveFilters
                    ? const [
                        BoxShadow(
                          color: Color(0x447C2BE8),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                tooltip: 'Search filters',
                onPressed: () {
                  _scaffoldKey.currentState?.openEndDrawer();
                },
                padding: const EdgeInsets.all(16),
                icon: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            if (_hasActiveFilters)
              Positioned(
                top: -6,
                right: -5,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1D5FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF08080B),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$_activeFilterCount',
                    style: const TextStyle(
                      color: Color(0xFF6C1A9B),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsContent(WatchlistProvider watchlistProvider) {
    final filteredList = _filteredResults;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: Color(0xFFB84AF5),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Searching CineTrack...',
              style: TextStyle(
                color: Color(0xFF817C87),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return _buildMessageState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        message: _errorMessage,
        iconColor: const Color(0xFFFF647C),
      );
    }

    if (filteredList.isEmpty) {
      if (_searchController.text.isEmpty) {
        return _buildMessageState(
          icon: Icons.search_rounded,
          title: 'Find your next favorite',
          message: 'Search for movies, TV shows, or people to start exploring.',
          iconColor: const Color(0xFFBD4DFF),
        );
      }

      return _buildMessageState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No matching results',
        message:
            'Try another search or remove some filters to see more titles.',
        iconColor: const Color(0xFFBD4DFF),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${filteredList.length} '
              '${filteredList.length == 1 ? 'result' : 'results'}',
              style: const TextStyle(
                color: Color(0xFFDAD6DF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF271632),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF553067)),
                ),
                child: Text(
                  '$_activeFilterCount active',
                  style: const TextStyle(
                    color: Color(0xFFCA66FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 28),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 205,
              childAspectRatio: 0.61,
              crossAxisSpacing: 18,
              mainAxisSpacing: 20,
            ),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              return _buildResultCard(
                item: filteredList[index],
                watchlistProvider: watchlistProvider,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required dynamic item,
    required WatchlistProvider watchlistProvider,
  }) {
    final id = item['id'];
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final imagePath = item['poster_path'] ?? item['profile_path'];

    final imageUrl = imagePath != null && imagePath.toString().trim().isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500$imagePath'
        : '';

    final rawMediaType = (item['media_type'] ?? '').toString().toLowerCase();

    final bool isPerson =
        rawMediaType == 'person' ||
        item['known_for'] != null ||
        (item['profile_path'] != null &&
            item['title'] == null &&
            item['name'] != null);

    final bool isTv =
        !isPerson &&
        (rawMediaType == 'tv' ||
            rawMediaType == 'show' ||
            item['first_air_date'] != null ||
            (item['name'] != null && item['title'] == null));

    final bool isMovie = !isPerson && !isTv;
    final String mediaTypeStr = isTv ? 'tv' : 'movie';

    final String badgeText = isPerson
        ? 'PERSON'
        : isTv
        ? 'TV'
        : 'MOVIE';

    final date = item['release_date'] ?? item['first_air_date'] ?? '';

    final year = date.toString().length >= 4
        ? date.toString().substring(0, 4)
        : '';

    final voteAverage =
        double.tryParse((item['vote_average'] ?? 0).toString()) ?? 0;

    final isWatchlist =
        !isPerson &&
        watchlistProvider.getMediaStatus(id, mediaType: mediaTypeStr) ==
            'watchlist';

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
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15151B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF292630)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3D000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPosterPlaceholder(isPerson);
                        },
                      )
                    else
                      _buildPosterPlaceholder(isPerson),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x12000000),
                              Color(0x00000000),
                              Color(0xB3000000),
                            ],
                            stops: [0, 0.58, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xD90C0B0F),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF4B2A59)),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Color(0xFFCA66FF),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    if (isWatchlist)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xE6A943E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.bookmark_added_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    if (!isPerson)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xCC0C0B0F),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF39343F)),
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: 'More options',
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            color: const Color(0xFF17151B),
                            surfaceTintColor: const Color(0xFF17151B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF38333F)),
                            ),
                            onSelected: (value) async {
                              if (value == 'watchlist') {
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                );

                                if (isWatchlist) {
                                  await watchlistProvider.removeFromWatchlist(
                                    id,
                                    mediaType: mediaTypeStr,
                                  );

                                  scaffoldMessenger.showSnackBar(
                                    _buildSnackBar('Removed from Watchlist'),
                                  );
                                } else {
                                  final fullDateStr =
                                      (item['release_date'] ??
                                              item['first_air_date'] ??
                                              '')
                                          .toString();

                                  final rating =
                                      double.tryParse(
                                        (item['vote_average'] ?? 0.0)
                                            .toString(),
                                      ) ??
                                      0.0;

                                  await watchlistProvider.addToWatchlist(
                                    movieId: id,
                                    movieTitle: title,
                                    posterPath: imagePath,
                                    status: 'watchlist',
                                    mediaType: mediaTypeStr,
                                    releaseYear: fullDateStr,
                                    runtime: 120,
                                    voteAverage: rating,
                                  );

                                  scaffoldMessenger.showSnackBar(
                                    _buildSnackBar('Added to Watchlist'),
                                  );
                                }
                              } else if (value == 'track') {
                                _showMarkWatchedMenu(item, mediaTypeStr);
                              } else if (value == 'manage') {
                                _showMoreOptions(
                                  watchlistProvider,
                                  item,
                                  mediaTypeStr,
                                );
                              }
                            },
                            itemBuilder: (context) {
                              return [
                                PopupMenuItem(
                                  value: 'watchlist',
                                  child: _buildPopupItem(
                                    icon: isWatchlist
                                        ? Icons.bookmark_added_rounded
                                        : Icons.bookmark_add_outlined,
                                    label: isWatchlist
                                        ? 'Remove from Watchlist'
                                        : 'Watchlist',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'track',
                                  child: _buildPopupItem(
                                    icon: Icons.check_rounded,
                                    label: 'Track',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'manage',
                                  child: _buildPopupItem(
                                    icon: Icons.list_alt_rounded,
                                    label: 'Manage List',
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
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF3F1F5),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          if (isPerson)
            Text(
              item['known_for_department'] ?? 'Person',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF77717D),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Row(
              children: [
                if (year.isNotEmpty)
                  Text(
                    year,
                    style: const TextStyle(
                      color: Color(0xFF77717D),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (year.isNotEmpty && voteAverage > 0)
                  Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4B4650),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (voteAverage > 0) ...[
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFC94A),
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    voteAverage.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF918B99),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPosterPlaceholder(bool isPerson) {
    return Container(
      color: const Color(0xFF15151B),
      alignment: Alignment.center,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Color(0xFF201824),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPerson ? Icons.person_rounded : Icons.movie_outlined,
          color: const Color(0xFF694078),
          size: 30,
        ),
      ),
    );
  }

  Widget _buildPopupItem({required IconData icon, required String label}) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF281732),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFCA66FF), size: 17),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE8E4EB),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  SnackBar _buildSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFFCA66FF),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF17151B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF39333F)),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
    required Color iconColor,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            color: const Color(0x9915151B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF28242E)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF211528),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4B2A59)),
                ),
                child: Icon(icon, color: iconColor, size: 29),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF5F3F8),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF817C87),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Reset filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFCA66FF),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      width: 340,
      backgroundColor: const Color(0xFF101014),
      surfaceTintColor: const Color(0xFF101014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
        side: BorderSide(color: Color(0xFF2D2933)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFCA53FF), Color(0xFF7C2BE8)],
                      ),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search filters',
                          style: TextStyle(
                            color: Color(0xFFF8F6FA),
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Refine your results',
                          style: TextStyle(
                            color: Color(0xFF77717D),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF19191E),
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFB6B0BC),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Divider(color: Color(0xFF2D2933), height: 1),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildDropdownLabel(
                      label: 'Genre',
                      icon: Icons.local_movies_outlined,
                    ),
                    const SizedBox(height: 9),
                    _buildDropdown(
                      value: _selectedGenre,
                      items: ['All', ..._genreMap.keys],
                      onChanged: (value) {
                        setState(() {
                          _selectedGenre = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    _buildDropdownLabel(
                      label: 'Status',
                      icon: Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 9),
                    _buildDropdown(
                      value: _selectedStatus,
                      items: _statuses,
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    _buildDropdownLabel(
                      label: 'Release decade',
                      icon: Icons.history_rounded,
                    ),
                    const SizedBox(height: 9),
                    _buildDropdown(
                      value: _selectedDecade,
                      items: _decades,
                      onChanged: (value) {
                        setState(() {
                          _selectedDecade = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFilters,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD2CDD6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF3A3540)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB143EB), Color(0xFF8431D9)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x447C2BE8),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
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

  Widget _buildDropdownLabel({required String label, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9B5ABB), size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFDAD6DF),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != 'All'
              ? const Color(0xFF8E3CB9)
              : const Color(0xFF35303B),
        ),
        boxShadow: value != 'All'
            ? const [BoxShadow(color: Color(0x227C2BE8), blurRadius: 12)]
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF17151B),
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            color: Color(0xFFF2EFF4),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF918B99),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

// frontend/lib/screens/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import '../widgets/trakt_filter_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String _errorMessage = '';

  String _selectedFilter = 'media';

  String _selectedGenre = 'All';
  String _selectedStatus = 'All';
  String _selectedDecade = 'All';

  List<dynamic> _continueWatching = [];
  List<dynamic> _startWatching = [];
  List<dynamic> _upcomingReleases = []; // Re-purposed for Last 30 Days
  List<dynamic> _recommended = [];
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      // Fetch Watchlist and History data safely
      List<dynamic> watchlistData = [];
      try {
        watchlistData = await ApiService.getWatchlist();
      } catch (_) {}

      List<dynamic> historyData = [];
      try {
        historyData = await ApiService.getWatchHistory();
      } catch (_) {
        try {
          historyData = (await (ApiService as dynamic).getHistory()) as List<dynamic>;
        } catch (_) {}
      }

      // 💡 Fetching multiple endpoints to guarantee a rich pool of recent releases
      final results = await Future.wait([
        ApiService.getTrendingMovies(type: 'all'),
        ApiService.getDiscoverMedia(category: 'releases', page: 1, type: 'movie'),
        ApiService.getDiscoverMedia(category: 'releases', page: 1, type: 'tv'),
        ApiService.getDiscoverMedia(category: 'releases', page: 2, type: 'movie'),
        ApiService.getDiscoverMedia(category: 'releases', page: 2, type: 'tv'),
      ]);

      final trendingList = (results[0]['results'] as List<dynamic>?) ?? [];

      List<dynamic> rawReleases = [];
      rawReleases.addAll((results[1]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll((results[2]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll((results[3]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll((results[4]['results'] as List<dynamic>?) ?? []);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));

      // 1. Strict Filter: Only keep releases from the LAST 30 days
      List<dynamic> last30DaysReleases = rawReleases.where((item) {
        final dateStr = item['calendar_date'] ?? item['release_date'] ?? item['first_air_date'];
        if (dateStr == null || dateStr.toString().trim().isEmpty) return false;
        try {
          final dt = DateTime.parse(dateStr.toString());
          final releaseDay = DateTime(dt.year, dt.month, dt.day);
          
          return !releaseDay.isBefore(thirtyDaysAgo) && !releaseDay.isAfter(today); 
        } catch (_) {
          return false;
        }
      }).toList();

      // 2. Sort Descending (Newest releases closest to today show up first)
      last30DaysReleases.sort((a, b) {
        final dateA = DateTime.tryParse(a['calendar_date'] ?? a['release_date'] ?? a['first_air_date'] ?? '') ?? DateTime(1900);
        final dateB = DateTime.tryParse(b['calendar_date'] ?? b['release_date'] ?? b['first_air_date'] ?? '') ?? DateTime(1900);
        return dateB.compareTo(dateA); 
      });

      // 3. Remove duplicates
      final seenIds = <int>{};
      last30DaysReleases = last30DaysReleases.where((item) {
        final id = item['id'] as int? ?? 0;
        if (seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _startWatching = watchlistData; 
          _recommended = trendingList;
          _upcomingReleases = last30DaysReleases; // Assigned to the Calendar section
          _continueWatching = [];
          _history = historyData; 
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

  List<dynamic> _filterList(List<dynamic> list) {
    return list.where((item) {
      final String rawType = (item['media_type'] ?? item['type'] ?? '').toString().toLowerCase();
      final bool isTv = rawType == 'tv' ||
          rawType == 'show' ||
          item['first_air_date'] != null ||
          (item['name'] != null && item['title'] == null);

      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'movies' && isTv) return false;

      if (_selectedGenre != 'All') {
        final List<dynamic> genreIds = item['genre_ids'] ?? [];
        final targetGenreId = FilterDrawer.genreMap[_selectedGenre];
        if (targetGenreId != null && !genreIds.contains(targetGenreId)) return false;
      }

      if (_selectedStatus != 'All') {
        final dateStr = item['release_date'] ?? item['first_air_date'] ?? '';
        final isUpcoming = dateStr.isNotEmpty && (DateTime.tryParse(dateStr)?.isAfter(DateTime.now()) ?? false);
        if (_selectedStatus == 'Upcoming' && !isUpcoming) return false;
        if (_selectedStatus == 'Released' && isUpcoming) return false;
      }

      if (_selectedDecade != 'All') {
        final dateStr = item['release_year'] ?? item['release_date'] ?? item['first_air_date'] ?? item['year'] ?? '';
        final year = int.tryParse(dateStr.toString().length >= 4 ? dateStr.toString().substring(0, 4) : '');
        if (year != null) {
          if (_selectedDecade == 'This Year' && year != DateTime.now().year) return false;
          if (_selectedDecade == '2020s' && (year < 2020 || year > 2029)) return false;
          if (_selectedDecade == '2010s' && (year < 2010 || year > 2019)) return false;
          if (_selectedDecade == '2000s' && (year < 2000 || year > 2009)) return false;
          if (_selectedDecade == 'Before 1960' && year >= 1960) return false;
        }
      }

      return true;
    }).toList();
  }

  bool get _hasActiveSidebarFilters =>
      _selectedGenre != 'All' || _selectedStatus != 'All' || _selectedDecade != 'All';

  @override
  Widget build(BuildContext context) {
    final filteredContinue = _filterList(_continueWatching);
    final filteredStart = _filterList(_startWatching);
    final filteredUpcoming = _filterList(_upcomingReleases);
    final filteredRecommended = _filterList(_recommended);
    final filteredHistory = _filterList(_history);

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
          });
        },
        onReset: () {
          setState(() {
            _selectedGenre = 'All';
            _selectedStatus = 'All';
            _selectedDecade = 'All';
          });
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  const Text(
                    'CineTrack',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
                  ),
                  const SizedBox(width: 8),
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFA855F7)))
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionHeader(
                                title: 'Continue Watching',
                                onTap: () => context.go('/progress'),
                              ),
                              const SizedBox(height: 12),
                              _buildMediaList(
                                items: filteredContinue,
                                emptyMessage: 'Start watching $_selectedFilter',
                                isLandscape: true,
                                isContinueWatching: true,
                              ),
                              const SizedBox(height: 28),

                              SectionHeader(
                                title: 'Start Watching',
                                onTap: () => context.go('/watchlist'),
                              ),
                              const SizedBox(height: 12),
                              _buildMediaList(
                                items: filteredStart,
                                emptyMessage: 'No $_selectedFilter in your watchlist',
                                isLandscape: false,
                              ),
                              const SizedBox(height: 28),

                              SectionHeader(
                                title: 'Calendar',
                                onTap: () => context.go('/calendar'),
                              ),
                              const SizedBox(height: 12),
                              _buildMediaList(
                                items: filteredUpcoming,
                                emptyMessage: 'No recent $_selectedFilter releases found',
                                isLandscape: false, 
                                isCalendar: true,
                              ),
                              const SizedBox(height: 28),

                              SectionHeader(
                                title: 'Recommended',
                                onTap: () => context.go('/recommended'),
                              ),
                              const SizedBox(height: 12),
                              _buildMediaList(
                                items: filteredRecommended,
                                emptyMessage: 'No recommended $_selectedFilter found',
                                isLandscape: false,
                              ),
                              const SizedBox(height: 28),

                              SectionHeader(
                                title: 'History',
                                onTap: () => context.go('/history'),
                              ),
                              const SizedBox(height: 12),
                              _buildMediaList(
                                items: filteredHistory,
                                emptyMessage: 'Watch $_selectedFilter to view history',
                                isLandscape: true,
                                isHistory: true,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaList({
    required List<dynamic> items,
    required String emptyMessage,
    required bool isLandscape,
    bool isContinueWatching = false,
    bool isHistory = false,
    bool isCalendar = false,
  }) {
    if (items.isEmpty) {
      return Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF131316),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Text(emptyMessage, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    // 💡 Expanded the limit so the Calendar section explicitly handles 30 items
    final int itemLimit = isCalendar ? 30 : (isHistory ? 7 : 20);
    final displayItems = items.take(itemLimit).toList();

    final double listHeight = isLandscape ? 170 : 230;
    final double cardWidth = isLandscape ? 240 : 115;

    return SizedBox(
      height: listHeight,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            
            final rawId = item['id'] ?? item['movie_id'] ?? item['media_id'];
            final int id = rawId != null ? int.tryParse(rawId.toString()) ?? 0 : 0;
            
            final String title = item['title'] ?? item['movie_title'] ?? item['name'] ?? 'Untitled';
            
            final String rawType = (item['media_type'] ?? item['type'] ?? '').toString().toLowerCase();
            final String mediaType = (rawType == 'tv' || rawType == 'show' || item['name'] != null) ? 'tv' : 'movie';

            final String imagePath = isLandscape
                ? (item['backdrop_path'] ?? item['poster_path'] ?? item['poster'] ?? '')
                : (item['poster_path'] ?? item['poster'] ?? '');

            final String imageUrl = imagePath.isNotEmpty
                ? (imagePath.startsWith('http') ? imagePath : 'https://image.tmdb.org/t/p/w500$imagePath')
                : '';

            final releaseDate = (item['release_year'] ?? item['release_date'] ?? item['first_air_date'] ?? item['year'] ?? '').toString();
            String? metadataLeftText;

            if (isCalendar && releaseDate.isNotEmpty) {
              try {
                final DateTime dt = DateTime.parse(releaseDate);
                final List<String> months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                ];
                metadataLeftText = isLandscape 
                    ? '${months[dt.month - 1]} ${dt.day}, ${dt.year}' 
                    : '${months[dt.month - 1]} ${dt.day}';
              } catch (_) {
                metadataLeftText = releaseDate;
              }
            } else {
              metadataLeftText = (releaseDate.length >= 4) ? releaseDate.substring(0, 4) : null;
            }

            final num voteAverage = item['vote_average'] ?? item['rating'] ?? 0.0;

            String? subtitle;
            String? overlayLeft;
            String? overlayRight;
            double? progress;

            if (isContinueWatching) {
              subtitle = 'S1 • E${(index % 10) + 1} - Next Episode';
              overlayLeft = '45m';
              overlayRight = '${(index % 5) + 2} left';
              progress = 0.3 + (index * 0.1).clamp(0.0, 1.0);
            } else if (isHistory) {
              final String watchedDate = (item['watchedDate'] ?? item['watched_date'] ?? item['watched_at'] ?? 'Recently').toString();
              overlayLeft = watchedDate;
            }

            return Container(
              width: cardWidth,
              margin: const EdgeInsets.only(right: 14),
              child: MovieCard(
                id: id,
                title: title,
                imageUrl: imageUrl,
                mediaType: mediaType, 
                isLandscape: isLandscape,
                year: metadataLeftText,
                rating: voteAverage.toDouble(),
                subtitle: subtitle,
                overlayLeftText: overlayLeft,
                overlayRightText: overlayRight,
                progress: progress,
              ),
            );
          },
        ),
      ),
    );
  }
}
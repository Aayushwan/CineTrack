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

  // Active Trakt Capsule Filter: 'media', 'shows', 'movies'
  String _selectedFilter = 'media';

  // Sidebar Filters
  String _selectedGenre = 'All';
  String _selectedStatus = 'All';
  String _selectedDecade = 'All';

  List<dynamic> _continueWatching = [];
  List<dynamic> _startWatching = [];
  List<dynamic> _upcomingReleases = [];
  List<dynamic> _recommended = [];
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final trendingData = await ApiService.getTrendingMovies();
      final upcomingData = await ApiService.getUpcomingMedia();

      final trendingList = (trendingData['results'] as List<dynamic>?) ?? [];
      final upcomingList = (upcomingData['results'] as List<dynamic>?) ?? [];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final upcomingFromToday = upcomingList.where((item) {
        final dateStr = item['release_date'] ?? item['first_air_date'];
        if (dateStr == null || dateStr.toString().trim().isEmpty) return false;
        try {
          final releaseDate = DateTime.parse(dateStr.toString());
          final releaseDay = DateTime(releaseDate.year, releaseDate.month, releaseDate.day);
          return !releaseDay.isBefore(today);
        } catch (_) {
          return false;
        }
      }).toList();

      upcomingFromToday.sort((a, b) {
        final dateA = DateTime.tryParse(a['release_date'] ?? a['first_air_date'] ?? '') ?? DateTime(2099);
        final dateB = DateTime.tryParse(b['release_date'] ?? b['first_air_date'] ?? '') ?? DateTime(2099);
        return dateA.compareTo(dateB);
      });

      if (mounted) {
        setState(() {
          _startWatching = trendingList;
          _recommended = trendingList.reversed.toList();
          _upcomingReleases = upcomingFromToday;
          _continueWatching = [];
          _history = [];
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

  // --- Combined Capsule & Sidebar Filtering Logic ---
  List<dynamic> _filterList(List<dynamic> list) {
    return list.where((item) {
      final String rawType = (item['media_type'] ?? '').toString().toLowerCase();
      final bool isTv = rawType == 'tv' ||
          item['first_air_date'] != null ||
          (item['name'] != null && item['title'] == null);

      // 1. Media Type Filter
      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'movies' && isTv) return false;

      // 2. Genre Filter
      if (_selectedGenre != 'All') {
        final List<dynamic> genreIds = item['genre_ids'] ?? [];
        final targetGenreId = FilterDrawer.genreMap[_selectedGenre];
        if (targetGenreId != null && !genreIds.contains(targetGenreId)) return false;
      }

      // 3. Status Filter
      if (_selectedStatus != 'All') {
        final dateStr = item['release_date'] ?? item['first_air_date'] ?? '';
        final isUpcoming = dateStr.isNotEmpty && (DateTime.tryParse(dateStr)?.isAfter(DateTime.now()) ?? false);
        if (_selectedStatus == 'Upcoming' && !isUpcoming) return false;
        if (_selectedStatus == 'Released' && isUpcoming) return false;
      }

      // 4. Decade Filter
      if (_selectedDecade != 'All') {
        final dateStr = item['release_date'] ?? item['first_air_date'] ?? '';
        final year = DateTime.tryParse(dateStr)?.year;
        if (year != null) {
          if (_selectedDecade == 'This Year' && year != 2026) return false;
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
            // ── STICKY TOP HEADER (PERSISTENT ON SCROLL) ────────────────────
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
                  // Sticky Trakt Filter Capsule
                  TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
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

            // ── SCROLLABLE BODY CONTENT ─────────────────────────────────────
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
                              // 1. Continue Watching
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

                              // 2. Start Watching
                              SectionHeader(
                                title: 'Start Watching',
                                onTap: () => context.go('/watchlist'),
                              ),
                              const SizedBox(height: 12),
                              _buildMediaList(
                                items: filteredStart,
                                emptyMessage: 'No $_selectedFilter available to watch',
                                isLandscape: false,
                              ),
                              const SizedBox(height: 28),

                              // 3. Calendar
                              SectionHeader(
                                title: 'Calendar',
                                onTap: () => context.go('/calendar'),
                              ),
                              const SizedBox(height: 12),
                              _buildMediaList(
                                items: filteredUpcoming,
                                emptyMessage: 'No upcoming $_selectedFilter found',
                                isLandscape: true,
                                isCalendar: true,
                              ),
                              const SizedBox(height: 28),

                              // 4. Recommended
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

                              // 5. History
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

    final int itemLimit = (isHistory || isCalendar) ? 7 : 20;
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
            final id = item['id'];
            final title = item['title'] ?? item['name'] ?? 'Untitled';
            final mediaType = item['media_type'] ?? (item['name'] != null ? 'tv' : 'movie');

            final imagePath = isLandscape
                ? (item['backdrop_path'] ?? item['poster_path'])
                : item['poster_path'];

            final imageUrl = (imagePath != null && imagePath.toString().trim().isNotEmpty)
                ? 'https://image.tmdb.org/t/p/w500$imagePath'
                : '';

            final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
            String? metadataLeftText;

            if (isCalendar && releaseDate.isNotEmpty) {
              try {
                final DateTime dt = DateTime.parse(releaseDate);
                final List<String> months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                ];
                metadataLeftText = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
              } catch (_) {
                metadataLeftText = releaseDate;
              }
            } else {
              metadataLeftText = (releaseDate.length >= 4) ? releaseDate.substring(0, 4) : null;
            }

            final voteAverage = (item['vote_average'] ?? 0.0) as num;

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
              final watchedDate = item['watched_date'] ?? 'Jul 28, 2026';
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
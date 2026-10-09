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
  static const Color _background = Color(0xFF08080B);
  static const Color _surface = Color(0xFF141419);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String _errorMessage = '';

  String _selectedFilter = 'media';

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
    List<dynamic> continueWatchingData = [];

    try {
      continueWatchingData = await ApiService.getContinueWatching();
    } catch (_) {}

    try {
      List<dynamic> watchlistData = [];

      try {
        watchlistData = await ApiService.getWatchlist();
      } catch (_) {}

      List<dynamic> historyData = [];

      try {
        historyData = await ApiService.getWatchHistory();
      } catch (_) {
        try {
          historyData =
              (await (ApiService as dynamic).getHistory()) as List<dynamic>;
        } catch (_) {}
      }

      final fallback = <String, dynamic>{'results': <dynamic>[]};

      final results = await Future.wait([
        ApiService.getTrendingMovies(type: 'all').catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'releases',
          page: 1,
          type: 'movie',
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'releases',
          page: 1,
          type: 'tv',
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'releases',
          page: 2,
          type: 'movie',
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'releases',
          page: 2,
          type: 'tv',
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'popular',
          page: 1,
          type: 'movie',
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'popular',
          page: 1,
          type: 'tv',
        ).catchError((_) => fallback),
      ]);

      final trendingList = (results[0]['results'] as List<dynamic>?) ?? [];

      List<dynamic> rawReleases = [];

      rawReleases.addAll(trendingList);
      rawReleases.addAll((results[1]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll((results[2]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll((results[3]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll((results[4]['results'] as List<dynamic>?) ?? []);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      List<dynamic> lastReleases = rawReleases.where((item) {
        final dateStr =
            item['calendar_date'] ??
            item['release_date'] ??
            item['first_air_date'];

        if (dateStr == null || dateStr.toString().trim().isEmpty) {
          return false;
        }

        try {
          final dt = DateTime.parse(dateStr.toString());

          final releaseDay = DateTime(dt.year, dt.month, dt.day);

          return !releaseDay.isAfter(today);
        } catch (_) {
          return false;
        }
      }).toList();

      lastReleases.sort((a, b) {
        final dateA =
            DateTime.tryParse(
              a['calendar_date'] ??
                  a['release_date'] ??
                  a['first_air_date'] ??
                  '',
            ) ??
            DateTime(1900);

        final dateB =
            DateTime.tryParse(
              b['calendar_date'] ??
                  b['release_date'] ??
                  b['first_air_date'] ??
                  '',
            ) ??
            DateTime(1900);

        return dateB.compareTo(dateA);
      });

      final seenReleaseIds = <int>{};

      lastReleases = lastReleases.where((item) {
        final id = item['id'] as int? ?? 0;

        if (seenReleaseIds.contains(id)) {
          return false;
        }

        seenReleaseIds.add(id);
        return true;
      }).toList();

      if (lastReleases.isEmpty && trendingList.isNotEmpty) {
        lastReleases = List.from(trendingList);
      }

      List<dynamic> rawRecommended = [];

      rawRecommended.addAll((results[5]['results'] as List<dynamic>?) ?? []);

      rawRecommended.addAll((results[6]['results'] as List<dynamic>?) ?? []);

      rawRecommended.sort((a, b) {
        final popA = (a['popularity'] ?? 0.0) as num;
        final popB = (b['popularity'] ?? 0.0) as num;

        return popB.compareTo(popA);
      });

      final seenRecIds = <int>{};

      rawRecommended = rawRecommended.where((item) {
        final id = item['id'] as int? ?? 0;

        if (seenRecIds.contains(id)) {
          return false;
        }

        seenRecIds.add(id);
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _startWatching = watchlistData;
          _upcomingReleases = lastReleases;
          _recommended = rawRecommended;

          _continueWatching = continueWatchingData.where((item) {
            final watched =
                int.tryParse((item['watchedEpisodes'] ?? 0).toString()) ?? 0;

            final total =
                int.tryParse((item['totalEpisodes'] ?? 0).toString()) ?? 0;

            return total > 0 && watched < total;
          }).toList();

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
      final String rawType = (item['media_type'] ?? item['type'] ?? '')
          .toString()
          .toLowerCase();

      final bool isTv =
          rawType == 'tv' ||
          rawType == 'show' ||
          item['first_air_date'] != null ||
          (item['name'] != null && item['title'] == null);

      if (_selectedFilter == 'shows' && !isTv) {
        return false;
      }

      if (_selectedFilter == 'movies' && isTv) {
        return false;
      }

      if (_selectedGenre != 'All') {
        final List<dynamic> genreIds = item['genre_ids'] ?? [];
        final targetGenreId = FilterDrawer.genreMap[_selectedGenre];

        if (targetGenreId != null && !genreIds.contains(targetGenreId)) {
          return false;
        }
      }

      if (_selectedStatus != 'All') {
        final dateStr = item['release_date'] ?? item['first_air_date'] ?? '';

        final isUpcoming =
            dateStr.isNotEmpty &&
            (DateTime.tryParse(dateStr)?.isAfter(DateTime.now()) ?? false);

        if (_selectedStatus == 'Upcoming' && !isUpcoming) {
          return false;
        }

        if (_selectedStatus == 'Released' && isUpcoming) {
          return false;
        }
      }

      if (_selectedDecade != 'All') {
        final dateStr =
            item['release_year'] ??
            item['release_date'] ??
            item['first_air_date'] ??
            item['year'] ??
            '';

        final year = int.tryParse(
          dateStr.toString().length >= 4
              ? dateStr.toString().substring(0, 4)
              : '',
        );

        if (year != null) {
          if (_selectedDecade == 'This Year' && year != DateTime.now().year) {
            return false;
          }

          if (_selectedDecade == '2020s' && (year < 2020 || year > 2029)) {
            return false;
          }

          if (_selectedDecade == '2010s' && (year < 2010 || year > 2019)) {
            return false;
          }

          if (_selectedDecade == '2000s' && (year < 2000 || year > 2009)) {
            return false;
          }

          if (_selectedDecade == 'Before 1960' && year >= 1960) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  bool get _hasActiveSidebarFilters =>
      _selectedGenre != 'All' ||
      _selectedStatus != 'All' ||
      _selectedDecade != 'All';

  int get _activeSidebarFilterCount {
    int count = 0;

    if (_selectedGenre != 'All') count++;
    if (_selectedStatus != 'All') count++;
    if (_selectedDecade != 'All') count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final filteredContinue = _filterList(_continueWatching);
    final filteredStart = _filterList(_startWatching);
    final filteredUpcoming = _filterList(_upcomingReleases);
    final filteredRecommended = _filterList(_recommended);
    final filteredHistory = _filterList(_history);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
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
      body: Stack(
        children: [
          const Positioned.fill(child: _HomeBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _buildBody(
                      filteredContinue: filteredContinue,
                      filteredStart: filteredStart,
                      filteredUpcoming: filteredUpcoming,
                      filteredRecommended: filteredRecommended,
                      filteredHistory: filteredHistory,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 15),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.86),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;

          final brand = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_lightPurple, _darkPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.26),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.movie_filter_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CineTrack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'YOUR PERSONAL CINEMA',
                    style: TextStyle(
                      color: _lightPurple,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.15,
                    ),
                  ),
                ],
              ),
            ],
          );

          final filterControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TraktFilterBar(
                selectedFilter: _selectedFilter,
                showPeople: false,
                onFilterChanged: (filter) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
              const SizedBox(width: 9),
              _buildFilterButton(),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [brand, const Spacer(), _buildFilterButton()]),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                ),
                if (_hasActiveSidebarFilters) ...[
                  const SizedBox(height: 12),
                  _buildActiveFilters(),
                ],
              ],
            );
          }

          return Column(
            children: [
              Row(children: [brand, const Spacer(), filterControls]),
              if (_hasActiveSidebarFilters) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildActiveFilters(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _scaffoldKey.currentState?.openEndDrawer();
        },
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: _hasActiveSidebarFilters
                ? _purple.withValues(alpha: 0.14)
                : _surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _hasActiveSidebarFilters
                  ? _purple.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                color: _hasActiveSidebarFilters
                    ? _lightPurple
                    : Colors.white.withValues(alpha: 0.8),
                size: 21,
              ),
              if (_hasActiveSidebarFilters)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: _lightPurple,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_activeSidebarFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedGenre != 'All')
            _buildFilterChip(
              icon: Icons.theaters_outlined,
              label: _selectedGenre,
            ),
          if (_selectedStatus != 'All') ...[
            if (_selectedGenre != 'All') const SizedBox(width: 7),
            _buildFilterChip(
              icon: Icons.schedule_rounded,
              label: _selectedStatus,
            ),
          ],
          if (_selectedDecade != 'All') ...[
            if (_selectedGenre != 'All' || _selectedStatus != 'All')
              const SizedBox(width: 7),
            _buildFilterChip(
              icon: Icons.calendar_month_outlined,
              label: _selectedDecade,
            ),
          ],
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedGenre = 'All';
                  _selectedStatus = 'All';
                  _selectedDecade = 'All';
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _lightPurple, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _lightPurple,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required List<dynamic> filteredContinue,
    required List<dynamic> filteredStart,
    required List<dynamic> filteredUpcoming,
    required List<dynamic> filteredRecommended,
    required List<dynamic> filteredHistory,
  }) {
    if (_isLoading) {
      return const _HomeLoadingState(key: ValueKey('loading'));
    }

    if (_errorMessage.isNotEmpty) {
      return _HomeErrorState(
        key: const ValueKey('error'),
        message: _errorMessage,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _errorMessage = '';
          });

          _loadHomeData();
        },
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('content'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomePanel(
            continueCount: filteredContinue.length,
            watchlistCount: filteredStart.length,
          ),
          const SizedBox(height: 27),
          _buildHomeSection(
            title: 'Continue Watching',
            icon: Icons.play_circle_outline_rounded,
            itemCount: filteredContinue.length,
            onTap: () => context.go('/progress'),
            child: _buildMediaList(
              items: filteredContinue,
              emptyMessage: 'Start watching $_selectedFilter',
              isLandscape: true,
              isContinueWatching: true,
            ),
          ),
          _buildHomeSection(
            title: 'Start Watching',
            icon: Icons.bookmark_outline_rounded,
            itemCount: filteredStart.length,
            onTap: () => context.go('/watchlist'),
            child: _buildMediaList(
              items: filteredStart,
              emptyMessage: 'No $_selectedFilter in your watchlist',
              isLandscape: false,
            ),
          ),
          _buildHomeSection(
            title: 'Calendar',
            icon: Icons.calendar_month_outlined,
            itemCount: filteredUpcoming.length,
            onTap: () => context.go('/calendar'),
            child: _buildMediaList(
              items: filteredUpcoming,
              emptyMessage: 'No recent $_selectedFilter releases found',
              isLandscape: false,
              isCalendar: true,
            ),
          ),
          _buildHomeSection(
            title: 'Recommended',
            icon: Icons.auto_awesome_outlined,
            itemCount: filteredRecommended.length,
            onTap: () => context.go('/recommended'),
            child: _buildMediaList(
              items: filteredRecommended,
              emptyMessage: 'No recommended $_selectedFilter found',
              isLandscape: false,
            ),
          ),
          _buildHomeSection(
            title: 'History',
            icon: Icons.history_rounded,
            itemCount: filteredHistory.length,
            onTap: () => context.go('/history'),
            isLast: true,
            child: _buildMediaList(
              items: filteredHistory,
              emptyMessage: 'Watch $_selectedFilter to view history',
              isLandscape: true,
              isHistory: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePanel({
    required int continueCount,
    required int watchlistCount,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF201129), Color(0xFF15121A), Color(0xFF101014)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _lightPurple.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.23),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -65,
            right: -55,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _lightPurple.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.local_movies_outlined,
                          color: _lightPurple,
                          size: 14,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'YOUR CINEMA',
                          style: TextStyle(
                            color: _lightPurple,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.25,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'Pick up where you\nleft off.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Everything you watch, save, and discover is organized in one place.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 11,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Column(
                children: [
                  _buildWelcomeStat(
                    value: '$continueCount',
                    label: 'IN PROGRESS',
                  ),
                  const SizedBox(height: 10),
                  _buildWelcomeStat(
                    value: '$watchlistCount',
                    label: 'WATCHLIST',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStat({required String value, required String label}) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSection({
    required String title,
    required IconData icon,
    required int itemCount,
    required VoidCallback onTap,
    required Widget child,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 29),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _purple.withValues(alpha: 0.14)),
                  ),
                  child: Icon(icon, color: _lightPurple, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SectionHeader(title: title, onTap: onTap),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$itemCount',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.44),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
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
        height: 112,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isHistory
                    ? Icons.history_toggle_off_rounded
                    : isContinueWatching
                    ? Icons.play_circle_outline_rounded
                    : Icons.movie_filter_outlined,
                color: _lightPurple.withValues(alpha: 0.68),
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Flexible(
              child: Text(
                emptyMessage,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final int itemLimit = isCalendar ? 30 : (isHistory ? 7 : 20);

    final displayItems = items.take(itemLimit).toList();

    final double listHeight = isLandscape ? 188 : 252;
    final double cardWidth = isLandscape ? 268 : 128;

    return SizedBox(
      height: listHeight,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];

            final rawId = isContinueWatching
                ? item['show_id']
                : item['id'] ?? item['movie_id'] ?? item['media_id'];

            final int id = rawId != null
                ? int.tryParse(rawId.toString()) ?? 0
                : 0;

            final String title =
                item['title'] ??
                item['movie_title'] ??
                item['name'] ??
                'Untitled';

            final String rawType = (item['media_type'] ?? item['type'] ?? '')
                .toString()
                .toLowerCase();

            final String mediaType = isContinueWatching
                ? 'tv'
                : (rawType == 'tv' || rawType == 'show' || item['name'] != null)
                ? 'tv'
                : 'movie';

            final String imagePath = isLandscape
                ? (item['backdrop_path'] ??
                      item['poster_path'] ??
                      item['poster'] ??
                      '')
                : (item['poster_path'] ?? item['poster'] ?? '');

            final String imageUrl = imagePath.isNotEmpty
                ? (imagePath.startsWith('http')
                      ? imagePath
                      : 'https://image.tmdb.org/t/p/w500$imagePath')
                : '';

            final releaseDate =
                (item['release_year'] ??
                        item['release_date'] ??
                        item['first_air_date'] ??
                        item['year'] ??
                        '')
                    .toString();

            String? metadataLeftText;

            if (isCalendar && releaseDate.isNotEmpty) {
              try {
                final DateTime dt = DateTime.parse(releaseDate);

                final List<String> months = [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'May',
                  'Jun',
                  'Jul',
                  'Aug',
                  'Sep',
                  'Oct',
                  'Nov',
                  'Dec',
                ];

                metadataLeftText = isLandscape
                    ? '${months[dt.month - 1]} ${dt.day}, ${dt.year}'
                    : '${months[dt.month - 1]} ${dt.day}';
              } catch (_) {
                metadataLeftText = releaseDate;
              }
            } else {
              metadataLeftText = releaseDate.length >= 4
                  ? releaseDate.substring(0, 4)
                  : null;
            }

            final num voteAverage =
                item['vote_average'] ?? item['rating'] ?? 0.0;

            String? subtitle;
            String? overlayLeft;
            String? overlayRight;
            double? progress;

            if (isContinueWatching) {
              final watched =
                  int.tryParse((item['watchedEpisodes'] ?? 0).toString()) ?? 0;

              final total =
                  int.tryParse((item['totalEpisodes'] ?? 1).toString()) ?? 1;

              final nextSeason =
                  int.tryParse((item['nextSeasonNumber'] ?? 1).toString()) ?? 1;

              final nextEpisode =
                  int.tryParse(
                    (item['nextEpisodeNumber'] ?? watched + 1).toString(),
                  ) ??
                  watched + 1;

              subtitle = 'Next: S$nextSeason • E$nextEpisode';
              overlayLeft = '${item['nextEpisodeRuntime'] ?? 45}m';
              overlayRight = '${total - watched} left';

              progress = total > 0 ? (watched / total).clamp(0.0, 1.0) : 0;
            } else if (isHistory) {
              final String watchedDate =
                  (item['watchedDate'] ??
                          item['watched_date'] ??
                          item['watched_at'] ??
                          'Recently')
                      .toString();

              overlayLeft = watchedDate;
            }

            return Container(
              width: cardWidth,
              margin: EdgeInsets.only(
                right: index == displayItems.length - 1 ? 0 : 15,
              ),
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

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFF08080B), child: SizedBox.expand()),
          Positioned(
            top: -190,
            right: -170,
            child: Container(
              width: 430,
              height: 430,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB143EB).withValues(alpha: 0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -260,
            left: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8431D9).withValues(alpha: 0.065),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            color: Color(0xFFCA66FF),
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF647C).withValues(alpha: 0.17),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.23),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF647C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF647C).withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFFF647C),
                  size: 29,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load your home feed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.43),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 21),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB143EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 21,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try again',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

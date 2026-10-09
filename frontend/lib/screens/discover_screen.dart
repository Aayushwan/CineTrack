// frontend/lib/screens/discover_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import '../widgets/trakt_filter_bar.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
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

  List<dynamic> _trending = [];
  List<dynamic> _releases = [];
  List<dynamic> _anticipated = [];
  List<dynamic> _popular = [];

  @override
  void initState() {
    super.initState();
    _loadDiscoverData();
  }

  String get _apiMediaType {
    if (_selectedFilter == 'shows') return 'tv';
    return 'movie';
  }

  Future<void> _loadDiscoverData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final targetType = _apiMediaType;

      // Prevent an individual endpoint failure from crashing the screen.
      final fallback = <String, dynamic>{'results': <dynamic>[]};

      final results = await Future.wait([
        ApiService.getDiscoverMedia(
          category: 'trending',
          type: targetType,
        ).catchError((_) => fallback),
        ApiService.getUpcomingMedia().catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'releases',
          page: 1,
          type: targetType,
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'releases',
          page: 2,
          type: targetType,
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'anticipated',
          type: targetType,
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'popular',
          type: targetType,
        ).catchError((_) => fallback),
      ]);

      final anticipatedList = (results[4]['results'] as List<dynamic>?) ?? [];

      List<dynamic> rawReleases = [];

      rawReleases.addAll((results[1]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll((results[2]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll((results[3]['results'] as List<dynamic>?) ?? []);
      rawReleases.addAll(anticipatedList);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      List<dynamic> upcomingReleases = rawReleases.where((item) {
        final rawType = (item['media_type'] ?? '').toString().toLowerCase();

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

        final dateStr =
            item['release_date'] ??
            item['first_air_date'] ??
            item['calendar_date'];

        if (dateStr == null || dateStr.toString().trim().isEmpty) {
          return false;
        }

        try {
          final dt = DateTime.parse(dateStr.toString());

          final releaseDay = DateTime(dt.year, dt.month, dt.day);

          return !releaseDay.isBefore(today);
        } catch (_) {
          return false;
        }
      }).toList();

      upcomingReleases.sort((a, b) {
        final dateA =
            DateTime.tryParse(
              a['release_date'] ??
                  a['first_air_date'] ??
                  a['calendar_date'] ??
                  '',
            ) ??
            DateTime(2099);

        final dateB =
            DateTime.tryParse(
              b['release_date'] ??
                  b['first_air_date'] ??
                  b['calendar_date'] ??
                  '',
            ) ??
            DateTime(2099);

        return dateA.compareTo(dateB);
      });

      final seenIds = <int>{};

      upcomingReleases = upcomingReleases.where((item) {
        final id = item['id'] as int? ?? 0;

        if (seenIds.contains(id)) {
          return false;
        }

        seenIds.add(id);
        return true;
      }).toList();

      if (upcomingReleases.isEmpty && anticipatedList.isNotEmpty) {
        upcomingReleases = List.from(anticipatedList);
      }

      if (mounted) {
        setState(() {
          _trending = (results[0]['results'] as List<dynamic>?) ?? [];
          _releases = upcomingReleases;
          _anticipated = anticipatedList;
          _popular = (results[5]['results'] as List<dynamic>?) ?? [];
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
      final String rawType = (item['media_type'] ?? '')
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
    final filteredTrending = _filterList(_trending);
    final filteredAnticipated = _filterList(_anticipated);
    final filteredPopular = _filterList(_popular);
    final filteredReleases = _filterList(_releases);

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
          const Positioned.fill(child: _DiscoverBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _buildBody(
                      filteredTrending: filteredTrending,
                      filteredReleases: filteredReleases,
                      filteredAnticipated: filteredAnticipated,
                      filteredPopular: filteredPopular,
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

          final titleSection = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 45,
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
                  Icons.explore_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'FIND YOUR NEXT STORY',
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

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    titleSection,
                    const Spacer(),
                    _buildFilterButton(),
                  ],
                ),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: _handleMediaFilterChanged,
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
              Row(
                children: [
                  titleSection,
                  const Spacer(),
                  TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: _handleMediaFilterChanged,
                  ),
                  const SizedBox(width: 9),
                  _buildFilterButton(),
                ],
              ),
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

  void _handleMediaFilterChanged(String filter) {
    if (_selectedFilter != filter) {
      setState(() {
        _selectedFilter = filter;
      });

      _loadDiscoverData();
    }
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
    required List<dynamic> filteredTrending,
    required List<dynamic> filteredReleases,
    required List<dynamic> filteredAnticipated,
    required List<dynamic> filteredPopular,
  }) {
    if (_isLoading) {
      return const _DiscoverLoadingState(key: ValueKey('loading'));
    }

    if (_errorMessage.isNotEmpty) {
      return _DiscoverErrorState(
        key: const ValueKey('error'),
        message: _errorMessage,
        onRetry: _loadDiscoverData,
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('content'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDiscoveryOverview(
            trendingCount: filteredTrending.length,
            releaseCount: filteredReleases.length,
            anticipatedCount: filteredAnticipated.length,
          ),
          const SizedBox(height: 28),
          _buildDiscoverSection(
            title: 'Trending',
            subtitle: 'What everyone is watching right now',
            icon: Icons.local_fire_department_outlined,
            itemCount: filteredTrending.length,
            onTap: () => context.go('/discover/trending'),
            child: _buildHorizontalMediaList(
              items: filteredTrending,
              isLandscape: false,
            ),
          ),
          _buildDiscoverSection(
            title: 'Releases',
            subtitle: 'Coming in the next 30 days',
            icon: Icons.calendar_month_outlined,
            itemCount: filteredReleases.length,
            onTap: () => context.go('/releases'),
            child: _buildHorizontalMediaList(
              items: filteredReleases,
              isLandscape: true,
              isReleases: true,
            ),
          ),
          _buildDiscoverSection(
            title: 'Anticipated',
            subtitle: 'The stories audiences cannot wait to see',
            icon: Icons.auto_awesome_outlined,
            itemCount: filteredAnticipated.length,
            onTap: () => context.go('/discover/anticipated'),
            child: _buildHorizontalMediaList(
              items: filteredAnticipated,
              isLandscape: false,
            ),
          ),
          _buildDiscoverSection(
            title: 'Popular',
            subtitle: 'The most talked-about titles',
            icon: Icons.trending_up_rounded,
            itemCount: filteredPopular.length,
            onTap: () => context.go('/discover/popular'),
            isLast: true,
            child: _buildHorizontalMediaList(
              items: filteredPopular,
              isLandscape: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryOverview({
    required int trendingCount,
    required int releaseCount,
    required int anticipatedCount,
  }) {
    final mediaLabel = _selectedFilter == 'shows'
        ? 'shows'
        : _selectedFilter == 'movies'
        ? 'movies'
        : 'stories';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF21112A), Color(0xFF16121C), Color(0xFF101014)],
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
            top: -70,
            right: -55,
            child: Container(
              width: 180,
              height: 180,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.explore_outlined, color: _lightPurple, size: 14),
                  SizedBox(width: 7),
                  Text(
                    'CURATED FOR YOU',
                    style: TextStyle(
                      color: _lightPurple,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Find your next\nfavorite $mediaLabel.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.75,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Explore what is trending, arriving soon, and capturing everyone’s attention.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: 11,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildOverviewStat(
                    value: '$trendingCount',
                    label: 'TRENDING',
                  ),
                  const SizedBox(width: 8),
                  _buildOverviewStat(value: '$releaseCount', label: 'RELEASES'),
                  const SizedBox(width: 8),
                  _buildOverviewStat(
                    value: '$anticipatedCount',
                    label: 'ANTICIPATED',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({required String value, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.36),
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.65,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required int itemCount,
    required VoidCallback onTap,
    required Widget child,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withValues(alpha: 0.14)),
                  ),
                  child: Icon(icon, color: _lightPurple, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: title, onTap: onTap),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.34),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _buildHorizontalMediaList({
    required List<dynamic> items,
    required bool isLandscape,
    bool isReleases = false,
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
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: _lightPurple,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Flexible(
              child: Text(
                'No titles found matching your criteria',
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

    final int limit = isReleases ? 30 : 20;
    final displayItems = items.take(limit).toList();

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

            final rawId = item['id'] ?? item['movie_id'] ?? item['media_id'];

            final int id = rawId != null
                ? int.tryParse(rawId.toString()) ?? 0
                : 0;

            final title = item['title'] ?? item['name'] ?? 'Untitled';

            final rawType = (item['media_type'] ?? '').toString().toLowerCase();

            final mediaType =
                rawType == 'tv' || rawType == 'show' || item['name'] != null
                ? 'tv'
                : 'movie';

            final imagePath = isLandscape
                ? (item['backdrop_path'] ?? item['poster_path'])
                : item['poster_path'];

            final imageUrl =
                imagePath != null && imagePath.toString().trim().isNotEmpty
                ? 'https://image.tmdb.org/t/p/w500$imagePath'
                : '';

            final releaseDate =
                (item['release_date'] ?? item['first_air_date'] ?? '')
                    .toString();

            final yearStr = releaseDate.length >= 4
                ? releaseDate.substring(0, 4)
                : null;

            final voteAverage =
                double.tryParse((item['vote_average'] ?? 0.0).toString()) ??
                0.0;

            String? overlayLeft;

            if (isReleases && releaseDate.isNotEmpty) {
              try {
                final dt = DateTime.parse(releaseDate);

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

                overlayLeft = '${months[dt.month - 1]} ${dt.day}';
              } catch (_) {}
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
                year: yearStr,
                rating: voteAverage,
                overlayLeftText: overlayLeft,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DiscoverBackground extends StatelessWidget {
  const _DiscoverBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFF08080B), child: SizedBox.expand()),
          Positioned(
            top: -200,
            right: -170,
            child: Container(
              width: 440,
              height: 440,
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
            bottom: -250,
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

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState({super.key});

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

class _DiscoverErrorState extends StatelessWidget {
  const _DiscoverErrorState({
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
                'Unable to load Discover',
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

// frontend/lib/screens/profile_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedAnalyticsPeriod = 0;

  bool _isLoadingStats = true;
  bool _isLoadingHistory = true;

  Map<String, dynamic>? _statsData;
  List<dynamic> _historyItems = [];

  String _username = 'User';

  // Ready to connect to your Continue Watching backend data.
  final List<Map<String, dynamic>> _continueWatching = [];

  String get _usernameInitial {
    final trimmedName = _username.trim();

    if (trimmedName.isEmpty) {
      return 'U';
    }

    return trimmedName[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString('username');

      if (storedName != null &&
          storedName.isNotEmpty &&
          mounted) {
        setState(() {
          _username = storedName;
        });
      }

      final results = await Future.wait([
        ApiService.getProfileStats(),
        ApiService.getWatchHistory(),
      ]);

      if (mounted) {
        setState(() {
          _statsData = results[0] as Map<String, dynamic>;
          _isLoadingStats = false;

          final historyData = results[1] as List<dynamic>;
          _historyItems = historyData.take(10).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _isLoadingHistory = false;
        });
      }
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null ||
        isoString.isEmpty ||
        isoString == 'null') {
      return '';
    }

    try {
      final date = DateTime.parse(isoString).toLocal();

      const months = [
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

      return '${months[date.month - 1]} '
          '${date.day.toString().padLeft(2, '0')}, '
          '${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, -0.9),
                  radius: 1.15,
                  colors: [
                    Color(0x292A0A42),
                    Color(0xFF08080B),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -180,
            right: -140,
            child: _buildBackgroundGlow(
              size: 430,
              color: const Color(0xFF9E3DDA),
            ),
          ),
          Positioned(
            bottom: -220,
            left: -180,
            child: _buildBackgroundGlow(
              size: 480,
              color: const Color(0xFF5D1B89),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFFB143EB),
              backgroundColor: const Color(0xFF17151B),
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1400,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserHeader(context),
                        const SizedBox(height: 32),
                        _buildAnalyticsHeader(),
                        const SizedBox(height: 16),
                        _buildAnalyticsCard(),
                        const SizedBox(height: 32),
                        _buildSectionHeader(
                          icon: Icons.play_circle_outline_rounded,
                          title: 'Continue Watching',
                          subtitle: 'Pick up where you left off',
                        ),
                        const SizedBox(height: 14),
                        _buildContinueWatchingList(),
                        const SizedBox(height: 32),
                        _buildDynamicFavoritesSection(context),
                        const SizedBox(height: 32),
                        _buildDynamicHistorySection(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xD915151B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2D2933),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;

          return Row(
            children: [
              Container(
                width: isCompact ? 64 : 74,
                height: isCompact ? 64 : 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    isCompact ? 19 : 22,
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFCA53FF),
                      Color(0xFF7C2BE8),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0x55D9A8FF),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x557C2BE8),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _usernameInitial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 26 : 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 14 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFBE4EFF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x55BE4EFF),
                                blurRadius: 8,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 7,
                            height: 7,
                          ),
                        ),
                        SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            'CINETRACK PROFILE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFCA66FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFFAF9FC),
                        fontSize: isCompact ? 21 : 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your personal movie and television journal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF817C87),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Log out',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await ApiService.clearToken();

                      if (!context.mounted) return;

                      context.go('/login');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF24151B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF57303D),
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFFF647C),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                icon: Icons.insights_rounded,
                title: 'Analytics',
                subtitle: 'Your watching activity',
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildPeriodSelector(),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(
              icon: Icons.insights_rounded,
              title: 'Analytics',
              subtitle: 'Your watching activity',
            ),
            _buildPeriodSelector(),
          ],
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D2933),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodTab('This Month', 0),
          _buildPeriodTab('All Time', 1),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String title, int index) {
    final isSelected = _selectedAnalyticsPeriod == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedAnalyticsPeriod = index;
          });
        },
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFFB143EB),
                      Color(0xFF8431D9),
                    ],
                  )
                : null,
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x447C2BE8),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : const Color(0xFF817C87),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    if (_isLoadingStats) {
      return Container(
        width: double.infinity,
        height: 142,
        decoration: BoxDecoration(
          color: const Color(0xD915151B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF2D2933),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Color(0xFFB84AF5),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Loading your analytics...',
                style: TextStyle(
                  color: Color(0xFF817C87),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final periodKey =
        _selectedAnalyticsPeriod == 0 ? 'thisMonth' : 'allTime';

    final currentStats = _statsData?[periodKey] ?? {};

    final totalTime = currentStats['totalScreenTime'] ??
        currentStats['total_screen_time'] ??
        currentStats['screenTime'] ??
        '0h 0m';

    final moviesCount = currentStats['moviesCount'] ??
        currentStats['movies_count'] ??
        '0';

    final seriesCount = currentStats['seriesCount'] ??
        currentStats['series_count'] ??
        currentStats['episodesCount'] ??
        '0';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 25,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xD915151B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2D2933),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatMetric(
              icon: Icons.schedule_rounded,
              label: 'Watch Time',
              value: totalTime.toString(),
            ),
          ),
          _buildMetricDivider(),
          Expanded(
            child: _buildStatMetric(
              icon: Icons.movie_outlined,
              label: 'Movies',
              value: moviesCount.toString(),
            ),
          ),
          _buildMetricDivider(),
          Expanded(
            child: _buildStatMetric(
              icon: Icons.tv_rounded,
              label: 'Series',
              value: seriesCount.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 54,
      color: const Color(0xFF2D2933),
    );
  }

  Widget _buildStatMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF281732),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF4B2A59),
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFCA66FF),
            size: 17,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF6F4F8),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF817C87),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWatchingList() {
    if (_continueWatching.isEmpty) {
      return _buildEmptyState(
        icon: Icons.play_arrow_rounded,
        title: 'Nothing in progress',
        message: 'Start watching something and it will appear here.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _continueWatching.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        final show = _continueWatching[index];

        final double factor =
            show['watchedEpisodes'] / show['totalEpisodes'];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xD915151B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2D2933),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF281732),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFFCA66FF),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      show['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF5F3F8),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${show['watchedEpisodes']}/'
                    '${show['totalEpisodes']} eps',
                    style: const TextStyle(
                      color: Color(0xFFCA66FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                show['season'],
                style: const TextStyle(
                  color: Color(0xFF817C87),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: factor,
                  backgroundColor: const Color(0xFF2A2730),
                  color: const Color(0xFFB143EB),
                  minHeight: 7,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicFavoritesSection(
    BuildContext context,
  ) {
    return Consumer<WatchlistProvider>(
      builder: (context, watchlistProvider, child) {
        final favorites = watchlistProvider.favoriteItems;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNavigableSectionHeader(
              context: context,
              icon: Icons.favorite_rounded,
              title: 'Favorites',
              subtitle: 'The titles you love most',
              route: '/favorites',
            ),
            const SizedBox(height: 14),
            if (favorites.isEmpty)
              _buildEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'No favorites yet',
                message:
                    'Add movies and shows to build your favorites.',
              )
            else
              SizedBox(
                height: 190,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        favorites.length > 10 ? 10 : favorites.length,
                    itemBuilder: (context, index) {
                      final item = favorites[index];

                      final rawPoster =
                          (item.posterPath ?? '').toString();

                      final posterUrl = rawPoster.isNotEmpty &&
                              rawPoster != 'null'
                          ? rawPoster.startsWith('http')
                              ? rawPoster
                              : 'https://image.tmdb.org/t/p/w300'
                                  '$rawPoster'
                          : '';

                      final mediaType = item.mediaType.isNotEmpty
                          ? item.mediaType
                          : 'movie';

                      final id = item.movieId;

                      return GestureDetector(
                        onTap: () {
                          context.go('/$mediaType/$id');
                        },
                        child: Container(
                          width: 126,
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15151B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF2D2933),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 18,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (posterUrl.isNotEmpty)
                                  Image.network(
                                    posterUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return _buildPosterPlaceholder();
                                    },
                                  )
                                else
                                  _buildPosterPlaceholder(),
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0x05000000),
                                          Color(0x00000000),
                                          Color(0xA6000000),
                                        ],
                                        stops: [0, 0.6, 1],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  child: Container(
                                    width: 29,
                                    height: 29,
                                    decoration: BoxDecoration(
                                      color: const Color(0xE6A943E9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: _buildFavoritesMenu(
                                    context: context,
                                    watchlistProvider:
                                        watchlistProvider,
                                    id: id,
                                    mediaType: mediaType,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFavoritesMenu({
    required BuildContext context,
    required WatchlistProvider watchlistProvider,
    required dynamic id,
    required String mediaType,
  }) {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: const Color(0xD90C0B0F),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF39343F),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Favorite options',
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 17,
        ),
        color: const Color(0xFF17151B),
        surfaceTintColor: const Color(0xFF17151B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: Color(0xFF38333F),
          ),
        ),
        onSelected: (value) async {
          if (value == 'remove') {
            final success =
                await watchlistProvider.removeFromWatchlist(
              id,
              mediaType: mediaType,
            );

            if (!context.mounted) return;

            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                _buildSnackBar('Removed from Favorites'),
              );
            }
          }
        },
        itemBuilder: (context) {
          return [
            PopupMenuItem(
              value: 'remove',
              child: _buildPopupItem(
                icon: Icons.heart_broken_rounded,
                label: 'Remove from Favorites',
                isDestructive: true,
              ),
            ),
          ];
        },
      ),
    );
  }

  Widget _buildDynamicHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNavigableSectionHeader(
          context: context,
          icon: Icons.history_rounded,
          title: 'History',
          subtitle: 'Recently watched titles',
          route: '/history',
        ),
        const SizedBox(height: 14),
        if (_isLoadingHistory)
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0x9915151B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF28242E),
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Color(0xFFB84AF5),
                  strokeWidth: 3,
                ),
              ),
            ),
          )
        else if (_historyItems.isEmpty)
          _buildEmptyState(
            icon: Icons.history_rounded,
            title: 'Your history is empty',
            message:
                'Titles you watch will automatically appear here.',
          )
        else
          SizedBox(
            height: 224,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _historyItems.length,
                itemBuilder: (context, index) {
                  final item = _historyItems[index];

                  final int historyId = int.tryParse(
                        (
                          item['id'] ??
                              item['history_id'] ??
                              item['historyId'] ??
                              '0'
                        ).toString(),
                      ) ??
                      0;

                  final String mediaId = (
                    item['media_id'] ??
                        item['mediaId'] ??
                        item['movie_id'] ??
                        item['movieId'] ??
                        '0'
                  ).toString();

                  final String mediaType = (
                    item['media_type'] ??
                        item['mediaType'] ??
                        item['type'] ??
                        'movie'
                  ).toString().toLowerCase();

                  final String title = (
                    item['title'] ??
                        item['movie_title'] ??
                        item['movieTitle'] ??
                        item['name'] ??
                        'Unknown'
                  ).toString();

                  final String rawDate = (
                    item['watched_at'] ??
                        item['watchedAt'] ??
                        ''
                  ).toString();

                  final String displayDate =
                      _formatDate(rawDate);

                  final String rawPoster = (
                    item['poster_path'] ??
                        item['posterPath'] ??
                        item['poster'] ??
                        item['image_url'] ??
                        ''
                  ).toString();

                  final String posterUrl = rawPoster.isNotEmpty &&
                          rawPoster != 'null'
                      ? rawPoster.startsWith('http')
                          ? rawPoster
                          : 'https://image.tmdb.org/t/p/w300'
                              '$rawPoster'
                      : '';

                  return GestureDetector(
                    onTap: () {
                      context.go('/$mediaType/$mediaId');
                    },
                    child: Container(
                      width: 128,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF15151B),
                                borderRadius:
                                    BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      const Color(0xFF2D2933),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 18,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(15),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (posterUrl.isNotEmpty)
                                      Image.network(
                                        posterUrl,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return _buildPosterPlaceholder();
                                        },
                                      )
                                    else
                                      _buildPosterPlaceholder(),
                                    const Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient:
                                              LinearGradient(
                                            begin:
                                                Alignment.topCenter,
                                            end: Alignment
                                                .bottomCenter,
                                            colors: [
                                              Color(0x00000000),
                                              Color(0x10000000),
                                              Color(0xCC000000),
                                            ],
                                            stops: [0, 0.56, 1],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (displayDate.isNotEmpty)
                                      Positioned(
                                        left: 8,
                                        right: 8,
                                        bottom: 8,
                                        child: Text(
                                          displayDate,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: _buildHistoryMenu(
                                        context: context,
                                        item: item,
                                        historyId: historyId,
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
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryMenu({
    required BuildContext context,
    required dynamic item,
    required int historyId,
  }) {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: const Color(0xD90C0B0F),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF39343F),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'History options',
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 17,
        ),
        color: const Color(0xFF17151B),
        surfaceTintColor: const Color(0xFF17151B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: Color(0xFF38333F),
          ),
        ),
        onSelected: (value) async {
          if (value == 'remove') {
            try {
              await ApiService.removeWatchHistory(historyId);

              if (!context.mounted) return;

              setState(() {
                _historyItems.removeWhere(
                  (element) => element['id'] == item['id'],
                );
              });

              ScaffoldMessenger.of(context).showSnackBar(
                _buildSnackBar('Removed from history'),
              );
            } catch (e) {
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to remove: $e',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: const Color(0xFFE34D67),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        },
        itemBuilder: (context) {
          return [
            PopupMenuItem(
              value: 'remove',
              child: _buildPopupItem(
                icon: Icons.remove_circle_outline_rounded,
                label: 'Remove from History',
                isDestructive: true,
              ),
            ),
          ];
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF281732),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: const Color(0xFF4B2A59),
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFCA66FF),
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF5F3F8),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF77717D),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigableSectionHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: _buildSectionHeader(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF18181D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2D2933),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF918B99),
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: const Color(0x9915151B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF28242E),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF211528),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF4B2A59),
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFBD4DFF),
              size: 25,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF5F3F8),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF817C87),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: const Color(0xFF15151B),
      alignment: Alignment.center,
      child: Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          color: Color(0xFF201824),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.movie_outlined,
          color: Color(0xFF694078),
          size: 27,
        ),
      ),
    );
  }

  Widget _buildPopupItem({
    required IconData icon,
    required String label,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? const Color(0xFFFF647C)
        : const Color(0xFFCA66FF);

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDestructive
                ? const Color(0xFF2A151C)
                : const Color(0xFF281732),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 17,
          ),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
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
        side: const BorderSide(
          color: Color(0xFF39333F),
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
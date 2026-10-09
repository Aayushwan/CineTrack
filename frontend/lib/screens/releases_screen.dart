// frontend/lib/screens/releases_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';

class ReleasesScreen extends StatefulWidget {
  const ReleasesScreen({super.key});

  @override
  State<ReleasesScreen> createState() => _ReleasesScreenState();
}

class _ReleasesScreenState extends State<ReleasesScreen> {
  static const Color _background = Color(0xFF08080B);
  static const Color _surface = Color(0xFF141419);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

  bool _isLoading = true;
  String _errorMessage = '';

  // Key: "YYYY-MM-DD", Value: List of release items.
  Map<String, List<dynamic>> _dateReleaseMap = {};
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    _loadReleasesData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WatchlistProvider>(context, listen: false).fetchCustomLists();
    });
  }

  Future<void> _loadReleasesData() async {
    try {
      final fallback = <String, dynamic>{'results': <dynamic>[]};

      final results = await Future.wait([
        ApiService.getUpcomingMedia().catchError((_) => fallback),
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
        ApiService.getTrendingMovies(type: 'all').catchError((_) => fallback),
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
        ApiService.getDiscoverMedia(
          category: 'anticipated',
          page: 1,
          type: 'movie',
        ).catchError((_) => fallback),
        ApiService.getDiscoverMedia(
          category: 'anticipated',
          page: 1,
          type: 'tv',
        ).catchError((_) => fallback),
      ]);

      final Map<String, List<dynamic>> tempMap = {};

      for (final res in results) {
        final list = (res['results'] as List<dynamic>?) ?? [];

        for (final item in list) {
          final dateStr =
              item['calendar_date'] ??
              item['release_date'] ??
              item['first_air_date'];

          if (dateStr != null && dateStr.toString().trim().isNotEmpty) {
            try {
              final dt = DateTime.parse(dateStr.toString());
              final key = _formatDateKey(dt);

              tempMap.putIfAbsent(key, () => []);

              if (!tempMap[key]!.any(
                (existing) => existing['id'] == item['id'],
              )) {
                tempMap[key]!.add(item);
              }
            } catch (_) {}
          }
        }
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (mounted) {
        setState(() {
          _dateReleaseMap = tempMap;
          _selectedDate = today;
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

  void _shiftWeek(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();

    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  String _formatDateKey(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _getFormattedHeaderDate(DateTime dt) {
    final List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final monthStr = months[dt.month - 1];

    final int day = dt.day;
    String suffix = 'th';

    if (day < 11 || day > 13) {
      switch (day % 10) {
        case 1:
          suffix = 'st';
          break;
        case 2:
          suffix = 'nd';
          break;
        case 3:
          suffix = 'rd';
          break;
      }
    }

    return '$monthStr $day$suffix, ${dt.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _shortMonth(int month) {
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

    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = List.generate(
      7,
      (index) => _selectedDate.add(Duration(days: index - 3)),
    );

    final bool hasAnyItems = weekDays.any(
      (date) => (_dateReleaseMap[_formatDateKey(date)] ?? []).isNotEmpty,
    );

    final int releaseCount = weekDays.fold<int>(0, (count, date) {
      return count + (_dateReleaseMap[_formatDateKey(date)] ?? []).length;
    });

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const Positioned.fill(child: _ReleasesBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(releaseCount),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildBody(
                      weekDays: weekDays,
                      hasAnyItems: hasAnyItems,
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

  Widget _buildHeader(int releaseCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 18, 16),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.86),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => context.go('/'),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 3),
          Container(
            width: 46,
            height: 46,
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
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.new_releases_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Releases',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.65,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _lightPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '$releaseCount '
                        '${releaseCount == 1 ? 'release' : 'releases'} '
                        'in this window',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.46),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _jumpToToday,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                height: 39,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _purple.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.today_rounded, color: _lightPurple, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Today',
                      style: TextStyle(
                        color: _lightPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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

  Widget _buildBody({
    required List<DateTime> weekDays,
    required bool hasAnyItems,
  }) {
    if (_isLoading) {
      return const _ReleasesLoadingState(key: ValueKey('loading'));
    }

    if (_errorMessage.isNotEmpty) {
      return _ReleasesErrorState(
        key: const ValueKey('error'),
        message: _errorMessage,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _errorMessage = '';
          });

          _loadReleasesData();
        },
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('releases'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 18, bottom: 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeekSelector(weekDays),
          const SizedBox(height: 28),
          if (!hasAnyItems)
            _buildEmptyWeekState()
          else
            ...weekDays.map((date) {
              final key = _formatDateKey(date);
              final items = _dateReleaseMap[key] ?? [];

              if (items.isEmpty) {
                return const SizedBox.shrink();
              }

              return _buildDateSection(date: date, items: items);
            }),
        ],
      ),
    );
  }

  Widget _buildWeekSelector(List<DateTime> weekDays) {
    final rangeStart = weekDays.first;
    final rangeEnd = weekDays.last;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 0, 3, 12),
            child: Row(
              children: [
                Container(
                  width: 33,
                  height: 33,
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(
                    Icons.date_range_rounded,
                    color: _lightPurple,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_shortMonth(rangeStart.month)} ${rangeStart.day}'
                    ' – '
                    '${_shortMonth(rangeEnd.month)} ${rangeEnd.day}, '
                    '${rangeEnd.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildWeekNavigationButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous week',
                  onTap: () => _shiftWeek(-7),
                ),
                const SizedBox(width: 6),
                _buildWeekNavigationButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next week',
                  onTap: () => _shiftWeek(7),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.055)),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;

              final availableWidth = constraints.maxWidth - (spacing * 6);

              final itemWidth = availableWidth / 7;

              return Row(
                children: [
                  for (int index = 0; index < weekDays.length; index++) ...[
                    SizedBox(
                      width: itemWidth,
                      child: _buildDayTile(weekDays[index]),
                    ),
                    if (index < weekDays.length - 1)
                      const SizedBox(width: spacing),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigationButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.72),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayTile(DateTime date) {
    final isSelected = _isSameDay(date, _selectedDate);

    final now = DateTime.now();

    final isToday = _isSameDay(date, DateTime(now.year, now.month, now.day));

    final key = _formatDateKey(date);
    final itemsOnDate = _dateReleaseMap[key] ?? [];
    final count = itemsOnDate.length;

    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${_getFormattedHeaderDate(date)}, $count releases',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
          },
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [_purple, _darkPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected
                  ? null
                  : isToday
                  ? _purple.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isSelected
                    ? _lightPurple.withValues(alpha: 0.46)
                    : isToday
                    ? _purple.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.035),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _darkPurple.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  days[date.weekday - 1],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.35),
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isToday
                        ? _lightPurple
                        : Colors.white.withValues(alpha: 0.82),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                if (count > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 21),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.18)
                          : _purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : _lightPurple,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection({
    required DateTime date,
    required List<dynamic> items,
  }) {
    final isSelected = _isSameDay(date, _selectedDate);

    final now = DateTime.now();

    final isToday = _isSameDay(date, DateTime(now.year, now.month, now.day));

    return Padding(
      padding: const EdgeInsets.only(bottom: 29),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [_lightPurple, _darkPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : _purple.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _lightPurple.withValues(alpha: 0.36)
                          : _purple.withValues(alpha: 0.15),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _darkPurple.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _getFormattedHeaderDate(date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  color: _lightPurple,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${items.length} '
                        '${items.length == 1 ? 'release' : 'releases'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              double maxExtent = 310;
              double aspectRatio = 1.28;

              if (constraints.maxWidth >= 1100) {
                maxExtent = 340;
                aspectRatio = 1.35;
              } else if (constraints.maxWidth < 600) {
                maxExtent = 270;
                aspectRatio = 1.2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  childAspectRatio: aspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 19,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildReleaseCard(item: items[index], index: index);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseCard({required dynamic item, required int index}) {
    final rawId = item['id'] ?? item['movie_id'] ?? item['media_id'];

    final int id = rawId != null ? int.tryParse(rawId.toString()) ?? 0 : 0;

    final title = item['title'] ?? item['name'] ?? 'Untitled';

    final String rawType = (item['media_type'] ?? '').toString().toLowerCase();

    final bool isTv =
        rawType == 'tv' ||
        rawType == 'show' ||
        item['first_air_date'] != null ||
        (item['name'] != null && item['title'] == null);

    final mediaType = isTv ? 'tv' : 'movie';

    final imagePath = item['backdrop_path'] ?? item['poster_path'];

    final imageUrl = imagePath != null && imagePath.toString().trim().isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500$imagePath'
        : '';

    String subtitleText;
    String overlayBadge;

    if (isTv) {
      final season = item['season_number'] ?? 1;

      final episode = item['episode_number'] ?? (index % 12) + 1;

      final epName = item['episode_name'] ?? 'Episode $episode';

      subtitleText = 'S$season • E$episode - $epName';

      overlayBadge = item['air_time'] ?? '9:30 AM • New';
    } else {
      subtitleText = 'Movie Release';

      overlayBadge = item['air_time'] ?? '5:30 PM • New';
    }

    final voteAverage =
        double.tryParse((item['vote_average'] ?? 0.0).toString()) ?? 0.0;

    return MovieCard(
      id: id,
      title: title,
      imageUrl: imageUrl,
      mediaType: mediaType,
      isLandscape: true,
      rating: voteAverage,
      subtitle: subtitleText,
      overlayLeftText: overlayBadge,
    );
  }

  Widget _buildEmptyWeekState() {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _lightPurple.withValues(alpha: 0.16),
                    _darkPurple.withValues(alpha: 0.07),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: _purple.withValues(alpha: 0.18)),
              ),
              child: const Icon(
                Icons.event_busy_outlined,
                color: _lightPurple,
                size: 29,
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'No releases this week',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Try moving to another week to explore more release dates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _jumpToToday,
              style: OutlinedButton.styleFrom(
                foregroundColor: _lightPurple,
                side: BorderSide(color: _purple.withValues(alpha: 0.28)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.today_rounded, size: 16),
              label: const Text(
                'Back to today',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleasesBackground extends StatelessWidget {
  const _ReleasesBackground();

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

class _ReleasesLoadingState extends StatelessWidget {
  const _ReleasesLoadingState({super.key});

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

class _ReleasesErrorState extends StatelessWidget {
  const _ReleasesErrorState({
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
                  Icons.new_releases_outlined,
                  color: Color(0xFFFF647C),
                  size: 29,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load releases',
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

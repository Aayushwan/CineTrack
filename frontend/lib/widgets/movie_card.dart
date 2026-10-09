import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';

class MovieCard extends StatefulWidget {
  final int id;
  final String title;
  final String imageUrl;
  final String mediaType;
  final bool isLandscape;
  final String? year;
  final double? rating;
  final String? subtitle;
  final String? overlayLeftText;
  final String? overlayRightText;
  final double? progress;
  final bool hideActionMenu;

  const MovieCard({
    super.key,
    required this.id,
    required this.title,
    required this.imageUrl,
    this.mediaType = 'movie',
    this.isLandscape = false,
    this.year,
    this.rating,
    this.subtitle,
    this.overlayLeftText,
    this.overlayRightText,
    this.progress,
    this.hideActionMenu = false,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isLogging = false;

  Future<void> _markAsWatched(
    String targetType,
    String option, {
    int? seasonNumber,
  }) async {
    Navigator.pop(context);

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_isLogging) return;

    setState(() {
      _isLogging = true;
    });

    try {
      final now = DateTime.now();

      if (targetType == 'movie') {
        await _markMovieAsWatched(
          option: option,
          now: now,
          scaffoldMessenger: scaffoldMessenger,
        );
        return;
      }

      if (seasonNumber == null) {
        throw Exception('Please select a season');
      }

      await _markSeasonAsWatched(
        seasonNumber: seasonNumber,
        option: option,
        now: now,
        scaffoldMessenger: scaffoldMessenger,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        _buildSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
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

  Future<void> _markMovieAsWatched({
    required String option,
    required DateTime now,
    required ScaffoldMessengerState scaffoldMessenger,
  }) async {
    String releaseDate = '';
    int runtime = 120;
    String? posterPath = widget.imageUrl;

    try {
      final details = await ApiService.getMovieDetails(widget.id);

      releaseDate = (details['release_date'] ?? '').toString();

      runtime = int.tryParse((details['runtime'] ?? 120).toString()) ?? 120;

      final rawPoster = details['poster_path']?.toString();

      if (rawPoster != null && rawPoster.isNotEmpty) {
        posterPath = rawPoster;
      }
    } catch (_) {
      releaseDate = widget.year ?? '';
    }

    final watchedAt = await _selectWatchedDate(
      option: option,
      releaseDate: releaseDate,
      now: now,
    );

    if (watchedAt == null) return;

    await ApiService.logWatchHistory(
      movieId: widget.id,
      mediaType: 'movie',
      title: widget.title,
      posterPath: posterPath,
      runtimeMinutes: runtime,
      userRating: 0.0,
      watchedAt: watchedAt.toIso8601String(),
    );

    scaffoldMessenger.showSnackBar(
      _buildSnackBar('Marked "${widget.title}" as watched'),
    );
  }

  Future<void> _markSeasonAsWatched({
    required int seasonNumber,
    required String option,
    required DateTime now,
    required ScaffoldMessengerState scaffoldMessenger,
  }) async {
    final details = await ApiService.getTvDetails(widget.id);

    final showTitle = (details['name'] ?? widget.title).toString();

    final posterPath = details['poster_path']?.toString();

    final backdropPath = details['backdrop_path']?.toString();

    final defaultRuntime = _getDefaultTvRuntime(details);

    final seasons =
        (details['seasons'] as List<dynamic>?)?.where((season) {
          final number = int.tryParse(
            (season['season_number'] ?? '').toString(),
          );

          return number != null && number > 0;
        }).toList() ??
        [];

    seasons.sort((a, b) {
      final aNumber = int.tryParse((a['season_number'] ?? 0).toString()) ?? 0;

      final bNumber = int.tryParse((b['season_number'] ?? 0).toString()) ?? 0;

      return aNumber.compareTo(bNumber);
    });

    final selectedSeason = seasons.firstWhere((season) {
      return int.tryParse((season['season_number'] ?? '').toString()) ==
          seasonNumber;
    }, orElse: () => null);

    final releaseDate =
        (selectedSeason?['air_date'] ?? details['first_air_date'] ?? '')
            .toString();

    final watchedAt = await _selectWatchedDate(
      option: option,
      releaseDate: releaseDate,
      now: now,
    );

    if (watchedAt == null) return;

    final totalEpisodes =
        int.tryParse((details['number_of_episodes'] ?? '').toString()) ??
        seasons.fold<int>(0, (total, season) {
          final episodeCount =
              int.tryParse((season['episode_count'] ?? 0).toString()) ?? 0;

          return total + episodeCount;
        });

    // Only request the selected season from TMDB.
    final episodes = await ApiService.getTvSeasonDetails(
      widget.id,
      seasonNumber,
    );

    final selectedEpisodes = <Map<String, dynamic>>[];

    for (final episode in episodes) {
      final episodeNumber = int.tryParse(
        (episode['episode_number'] ?? '').toString(),
      );

      if (episodeNumber == null) continue;

      final airDate = DateTime.tryParse((episode['air_date'] ?? '').toString());

      // Future episodes should not be marked as watched.
      if (airDate != null && airDate.isAfter(now)) {
        continue;
      }

      selectedEpisodes.add({
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        'runtime':
            int.tryParse((episode['runtime'] ?? defaultRuntime).toString()) ??
            defaultRuntime,
      });
    }

    if (selectedEpisodes.isEmpty) {
      throw Exception(
        'No released episodes were found in '
        'Season $seasonNumber',
      );
    }

    await ApiService.logShowWatchHistory(
      showId: widget.id,
      title: showTitle,
      posterPath: posterPath,
      backdropPath: backdropPath,
      episodes: selectedEpisodes,
      totalEpisodes: totalEpisodes > 0
          ? totalEpisodes
          : selectedEpisodes.length,
      watchedAt: watchedAt.toIso8601String(),
    );

    scaffoldMessenger.showSnackBar(
      _buildSnackBar(
        'Marked Season $seasonNumber of '
        '"$showTitle" as watched',
      ),
    );
  }

  int _getDefaultTvRuntime(Map<String, dynamic> details) {
    final runtimes = details['episode_run_time'] as List<dynamic>?;

    if (runtimes != null && runtimes.isNotEmpty) {
      return int.tryParse(runtimes.first.toString()) ?? 45;
    }

    return 45;
  }

  Future<DateTime?> _selectWatchedDate({
    required String option,
    required String releaseDate,
    required DateTime now,
  }) async {
    if (option == 'Just now') {
      return now.toUtc();
    }

    if (option == 'Release date') {
      if (releaseDate.isEmpty || releaseDate == 'null') {
        return now.toUtc();
      }

      try {
        if (releaseDate.length == 4) {
          return DateTime(int.parse(releaseDate), 1, 1).toUtc();
        }

        return DateTime.parse(releaseDate).toUtc();
      } catch (_) {
        return now.toUtc();
      }
    }

    if (option == 'Other date') {
      if (!mounted) return null;

      final pickedDate = await showDatePicker(
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
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF131316),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedDate == null) return null;

      return DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        now.hour,
        now.minute,
        now.second,
      ).toUtc();
    }

    return now.toUtc();
  }

  Future<void> _showSeasonPicker() async {
    if (_isLogging) return;

    setState(() {
      _isLogging = true;
    });

    try {
      final details = await ApiService.getTvDetails(widget.id);

      final seasons =
          (details['seasons'] as List<dynamic>?)?.where((season) {
            final seasonNumber = int.tryParse(
              (season['season_number'] ?? '').toString(),
            );

            return seasonNumber != null && seasonNumber > 0;
          }).toList() ??
          [];

      seasons.sort((a, b) {
        final aNumber = int.tryParse((a['season_number'] ?? 0).toString()) ?? 0;

        final bNumber = int.tryParse((b['season_number'] ?? 0).toString()) ?? 0;

        return aNumber.compareTo(bNumber);
      });

      if (!mounted) return;

      if (seasons.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar(
            'No seasons are available for this show',
            isError: true,
          ),
        );

        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF131316),
        barrierColor: Colors.black.withValues(alpha: 0.75),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF45404B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF281732),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.video_library_outlined,
                              color: Color(0xFFCA66FF),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select season',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Choose which season '
                                  'to mark as watched',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        itemCount: seasons.length,
                        itemBuilder: (context, index) {
                          final season = seasons[index];

                          final seasonNumber =
                              int.tryParse(
                                (season['season_number'] ?? 0).toString(),
                              ) ??
                              0;

                          final episodeCount =
                              int.tryParse(
                                (season['episode_count'] ?? 0).toString(),
                              ) ??
                              0;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(sheetContext);

                                Future<void>.delayed(Duration.zero, () {
                                  if (!mounted) return;

                                  _showMarkWatchedMenu(
                                    'tv',
                                    seasonNumber: seasonNumber,
                                  );
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF281732),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF4B2A59),
                                        ),
                                      ),
                                      child: Text(
                                        '$seasonNumber',
                                        style: const TextStyle(
                                          color: Color(0xFFCA66FF),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            season['name'] ??
                                                'Season '
                                                    '$seasonNumber',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$episodeCount '
                                            'episodes',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF817C87),
                                    ),
                                  ],
                                ),
                              ),
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
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
          'Unable to load seasons: '
          '${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
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

  void _showMarkWatchedMenu(String targetType, {int? seasonNumber}) {
    final isTv = targetType == 'tv';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF131316),
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF45404B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF281732),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFFCA66FF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTv
                                  ? 'Track Season '
                                        '$seasonNumber'
                                  : 'Mark as watched',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                _buildMenuOption(
                  Icons.bolt_rounded,
                  'Just now',
                  () => _markAsWatched(
                    targetType,
                    'Just now',
                    seasonNumber: seasonNumber,
                  ),
                ),
                _buildMenuOption(
                  Icons.calendar_today_rounded,
                  'Release date',
                  () => _markAsWatched(
                    targetType,
                    'Release date',
                    seasonNumber: seasonNumber,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                  ),
                ),
                _buildMenuOption(
                  Icons.edit_calendar_rounded,
                  'Other date',
                  () => _markAsWatched(
                    targetType,
                    'Other date',
                    seasonNumber: seasonNumber,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreOptions(WatchlistProvider provider, String targetType) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add to Custom List',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                if (provider.customLists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No custom lists found. '
                      'Create one in the Lists tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  ...provider.customLists.map((listData) {
                    final listId =
                        int.tryParse((listData['id'] ?? 0).toString()) ?? 0;

                    final listTitle =
                        (listData['title'] ?? listData['name'] ?? 'Untitled')
                            .toString();

                    return _buildMenuOption(
                      Icons.playlist_add_rounded,
                      listTitle,
                      () {
                        provider.addMediaToList(
                          listId,
                          widget.id,
                          widget.imageUrl,
                          title: widget.title,
                          mediaType: targetType,
                        );

                        Navigator.pop(sheetContext);

                        ScaffoldMessenger.of(context).showSnackBar(
                          _buildSnackBar(
                            'Added "${widget.title}" '
                            'to "$listTitle"',
                          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFCA66FF), size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SnackBar _buildSnackBar(String message, {bool isError = false}) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? const Color(0xFFFF647C) : const Color(0xFFCA66FF),
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
      backgroundColor: isError
          ? const Color(0xFF2A151C)
          : const Color(0xFF131316),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isError ? const Color(0xFF57303D) : const Color(0xFF39333F),
        ),
      ),
    );
  }

  Future<void> _toggleWatchlist(
    WatchlistProvider watchlistProvider,
    String targetType,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final isWatchlist =
        watchlistProvider.getMediaStatus(widget.id, mediaType: targetType) ==
        'watchlist';

    if (isWatchlist) {
      await watchlistProvider.removeFromWatchlist(
        widget.id,
        mediaType: targetType,
      );

      scaffoldMessenger.showSnackBar(_buildSnackBar('Removed from Watchlist'));

      return;
    }

    String releaseDate = '';
    int runtime = targetType == 'tv' ? 45 : 120;
    int? totalEpisodes;

    try {
      if (targetType == 'movie') {
        final details = await ApiService.getMovieDetails(widget.id);

        releaseDate = (details['release_date'] ?? '').toString();

        runtime = int.tryParse((details['runtime'] ?? 120).toString()) ?? 120;
      } else {
        final details = await ApiService.getTvDetails(widget.id);

        releaseDate = (details['first_air_date'] ?? '').toString();

        runtime = _getDefaultTvRuntime(details);

        totalEpisodes = int.tryParse(
          (details['number_of_episodes'] ?? '').toString(),
        );
      }
    } catch (_) {}

    await watchlistProvider.addToWatchlist(
      movieId: widget.id,
      movieTitle: widget.title,
      posterPath: widget.imageUrl,
      status: 'watchlist',
      mediaType: targetType,
      releaseYear: releaseDate,
      runtime: runtime,
      totalEpisodes: totalEpisodes,
      voteAverage: widget.rating ?? 0.0,
    );

    scaffoldMessenger.showSnackBar(_buildSnackBar('Added to Watchlist'));
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1E293B),
      alignment: Alignment.center,
      child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedType = widget.mediaType.toLowerCase();

    final isTvShow = normalizedType == 'tv' || normalizedType == 'show';

    final targetType = isTvShow ? 'tv' : 'movie';

    final targetRoute = '/$targetType/${widget.id}';

    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.go(targetRoute),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF1E293B),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.imageUrl.trim().isNotEmpty
                        ? Image.network(
                            widget.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholder();
                            },
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                if (widget.isLandscape)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(10),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.88),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (widget.overlayLeftText != null ||
                    widget.overlayRightText != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        if (widget.overlayLeftText != null)
                          Text(
                            widget.overlayLeftText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const Spacer(),
                        if (widget.overlayRightText != null)
                          Text(
                            widget.overlayRightText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (widget.progress != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10),
                      ),
                      child: LinearProgressIndicator(
                        value: widget.progress!.clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        color: const Color(0xFFA855F7),
                        minHeight: 3,
                      ),
                    ),
                  ),
                if (!widget.hideActionMenu)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: _isLogging
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFCA66FF),
                              ),
                            )
                          : PopupMenuButton<String>(
                              tooltip: 'Media options',
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              color: const Color(0xFF131316),
                              surfaceTintColor: const Color(0xFF131316),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Colors.white12),
                              ),
                              onSelected: (value) async {
                                if (value == 'watchlist') {
                                  await _toggleWatchlist(
                                    watchlistProvider,
                                    targetType,
                                  );
                                } else if (value == 'track') {
                                  if (targetType == 'tv') {
                                    await _showSeasonPicker();
                                  } else {
                                    _showMarkWatchedMenu('movie');
                                  }
                                } else if (value == 'manage') {
                                  _showMoreOptions(
                                    watchlistProvider,
                                    targetType,
                                  );
                                }
                              },
                              itemBuilder: (context) {
                                final isWatchlist =
                                    watchlistProvider.getMediaStatus(
                                      widget.id,
                                      mediaType: targetType,
                                    ) ==
                                    'watchlist';

                                return [
                                  PopupMenuItem<String>(
                                    value: 'watchlist',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isWatchlist
                                              ? Icons.bookmark_added_rounded
                                              : Icons.bookmark_add_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isWatchlist
                                              ? 'Remove from Watchlist'
                                              : 'Watchlist',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'track',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isTvShow ? 'Track Season' : 'Track',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'manage',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.list_alt_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Manage List',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
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
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.go(targetRoute),
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
        if (widget.year != null ||
            (widget.rating != null && widget.rating! > 0)) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.year ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              if (widget.rating != null && widget.rating! > 0)
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB800),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      widget.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

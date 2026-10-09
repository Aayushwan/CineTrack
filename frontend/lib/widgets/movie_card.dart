// frontend/lib/widgets/movie_card.dart

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
  static const Color _surfaceColor = Color(0xFF17151B);
  static const Color _sheetColor = Color(0xFF131316);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

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
        'No released episodes were found in Season $seasonNumber',
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
      _buildSnackBar('Marked Season $seasonNumber of "$showTitle" as watched'),
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
                primary: _purple,
                onPrimary: Colors.white,
                surface: _sheetColor,
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(backgroundColor: _sheetColor),
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
        backgroundColor: _sheetColor,
        barrierColor: Colors.black.withValues(alpha: 0.78),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSheetHandle(),
                    _buildSheetHeader(
                      context: sheetContext,
                      icon: Icons.video_library_outlined,
                      title: 'Select season',
                      description: 'Choose which season to mark as watched',
                    ),
                    _buildSheetDivider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
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

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
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
                                borderRadius: BorderRadius.circular(14),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.025,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.055,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _lightPurple.withValues(
                                                alpha: 0.18,
                                              ),
                                              _darkPurple.withValues(
                                                alpha: 0.1,
                                              ),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _lightPurple.withValues(
                                              alpha: 0.22,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '$seasonNumber',
                                          style: const TextStyle(
                                            color: _lightPurple,
                                            fontSize: 14,
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
                                                  'Season $seasonNumber',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$episodeCount episodes',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.42,
                                                ),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.34,
                                        ),
                                      ),
                                    ],
                                  ),
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
      backgroundColor: _sheetColor,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSheetHandle(),
                _buildSheetHeader(
                  context: sheetContext,
                  icon: Icons.check_circle_outline_rounded,
                  title: isTv
                      ? 'Track Season $seasonNumber'
                      : 'Mark as watched',
                  description: widget.title,
                ),
                _buildSheetDivider(),
                const SizedBox(height: 8),
                _buildMenuOption(
                  Icons.bolt_rounded,
                  'Just now',
                  () => _markAsWatched(
                    targetType,
                    'Just now',
                    seasonNumber: seasonNumber,
                  ),
                  description: 'Add this title with the current date and time',
                ),
                _buildMenuOption(
                  Icons.calendar_today_rounded,
                  'Release date',
                  () => _markAsWatched(
                    targetType,
                    'Release date',
                    seasonNumber: seasonNumber,
                  ),
                  description: 'Use the original release or air date',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.07),
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
                  description: 'Choose a custom date from the calendar',
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
      backgroundColor: _sheetColor,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSheetHandle(),
                _buildSheetHeader(
                  context: sheetContext,
                  icon: Icons.playlist_add_rounded,
                  title: 'Add to custom list',
                  description: widget.title,
                ),
                _buildSheetDivider(),
                if (provider.customLists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.09),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _purple.withValues(alpha: 0.16),
                            ),
                          ),
                          child: const Icon(
                            Icons.playlist_add_rounded,
                            color: _lightPurple,
                            size: 27,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No custom lists yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create your first collection from the Lists tab.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 8),
                      children: provider.customLists.map((listData) {
                        final listId =
                            int.tryParse((listData['id'] ?? 0).toString()) ?? 0;

                        final listTitle =
                            (listData['title'] ??
                                    listData['name'] ??
                                    'Untitled')
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
                                'Added "${widget.title}" to "$listTitle"',
                              ),
                            );
                          },
                          description: 'Add this title to $listTitle',
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetHandle() {
    return Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildSheetHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 10, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _lightPurple.withValues(alpha: 0.18),
                  _darkPurple.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _lightPurple.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: _lightPurple, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.65),
              size: 21,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSheetDivider() {
    return Container(height: 1, color: Colors.white.withValues(alpha: 0.07));
  }

  Widget _buildMenuOption(
    IconData icon,
    String label,
    VoidCallback onTap, {
    String? description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _purple.withValues(alpha: 0.14)),
                  ),
                  child: Icon(icon, color: _lightPurple, size: 19),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.36),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.28),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SnackBar _buildSnackBar(String message, {bool isError = false}) {
    return SnackBar(
      content: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isError
                  ? const Color(0xFFFF647C).withValues(alpha: 0.12)
                  : _purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? const Color(0xFFFF647C) : _lightPurple,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
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
      backgroundColor: isError ? const Color(0xFF241418) : _sheetColor,
      behavior: SnackBarBehavior.floating,
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isError
              ? const Color(0xFF57303D)
              : Colors.white.withValues(alpha: 0.1),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF211828), Color(0xFF121217)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _lightPurple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _lightPurple.withValues(alpha: 0.14)),
            ),
            child: Icon(
              Icons.movie_filter_outlined,
              color: Colors.white.withValues(alpha: 0.28),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No artwork',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaBadge(bool isTvShow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0B0F).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTvShow ? Icons.live_tv_rounded : Icons.local_movies_outlined,
            color: _lightPurple,
            size: 11,
          ),
          const SizedBox(width: 5),
          Text(
            isTvShow ? 'SERIES' : 'MOVIE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.75,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageScrim() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.48, 1],
            colors: [
              Colors.black.withValues(alpha: 0.16),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.72),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayInformation() {
    if (widget.overlayLeftText == null && widget.overlayRightText == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 10,
      right: 10,
      bottom: widget.progress != null ? 11 : 9,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.overlayLeftText != null)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  widget.overlayLeftText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (widget.overlayLeftText != null && widget.overlayRightText != null)
            const SizedBox(width: 8),
          if (widget.overlayRightText != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.overlayRightText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (widget.progress == null) {
      return const SizedBox.shrink();
    }

    final progress = widget.progress!.clamp(0.0, 1.0);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 5,
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_lightPurple, _purple, _darkPurple],
              ),
              boxShadow: [BoxShadow(color: Color(0x99B143EB), blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenuRow({
    required IconData icon,
    required String label,
    bool highlighted = false,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: highlighted
                ? _purple.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: highlighted
                ? _lightPurple
                : Colors.white.withValues(alpha: 0.78),
            size: 16,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: highlighted ? _lightPurple : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionMenu({
    required WatchlistProvider watchlistProvider,
    required String targetType,
    required bool isTvShow,
  }) {
    if (widget.hideActionMenu) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0A0E).withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _isLogging
            ? const Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _lightPurple,
                ),
              )
            : PopupMenuButton<String>(
                tooltip: 'Media options',
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                color: _surfaceColor,
                surfaceTintColor: _surfaceColor,
                elevation: 18,
                offset: const Offset(0, 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                onSelected: (value) async {
                  if (value == 'watchlist') {
                    await _toggleWatchlist(watchlistProvider, targetType);
                  } else if (value == 'track') {
                    if (targetType == 'tv') {
                      await _showSeasonPicker();
                    } else {
                      _showMarkWatchedMenu('movie');
                    }
                  } else if (value == 'manage') {
                    _showMoreOptions(watchlistProvider, targetType);
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
                      height: 46,
                      child: _buildPopupMenuRow(
                        icon: isWatchlist
                            ? Icons.bookmark_added_rounded
                            : Icons.bookmark_add_outlined,
                        label: isWatchlist
                            ? 'Remove from Watchlist'
                            : 'Add to Watchlist',
                        highlighted: isWatchlist,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'track',
                      height: 46,
                      child: _buildPopupMenuRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: isTvShow ? 'Track Season' : 'Mark as Watched',
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'manage',
                      height: 46,
                      child: _buildPopupMenuRow(
                        icon: Icons.playlist_add_rounded,
                        label: 'Add to Custom List',
                      ),
                    ),
                  ];
                },
              ),
      ),
    );
  }

  Widget _buildMetadata(bool isTvShow) {
    final hasYear = widget.year != null && widget.year!.trim().isNotEmpty;
    final hasRating = widget.rating != null && widget.rating! > 0;

    if (!hasYear && !hasRating) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          if (hasYear) ...[
            Icon(
              isTvShow ? Icons.live_tv_outlined : Icons.local_movies_outlined,
              color: Colors.white.withValues(alpha: 0.34),
              size: 12,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                widget.year!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (hasRating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                      color: Color(0xFFFFD76A),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedType = widget.mediaType.toLowerCase();

    final isTvShow = normalizedType == 'tv' || normalizedType == 'show';

    final targetType = isTvShow ? 'tv' : 'movie';
    final targetRoute = '/$targetType/${widget.id}';

    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    final currentStatus = watchlistProvider.getMediaStatus(
      widget.id,
      mediaType: targetType,
    );

    final isInWatchlist = currentStatus == 'watchlist';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Open ${widget.title}',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.go(targetRoute),
                child: Ink(
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.075),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
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
                      _buildImageScrim(),
                      Positioned(
                        top: 9,
                        left: 9,
                        child: _buildMediaBadge(isTvShow),
                      ),
                      if (isInWatchlist)
                        Positioned(
                          left: 9,
                          bottom: widget.progress != null ? 13 : 9,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_lightPurple, _darkPurple],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: _darkPurple.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.bookmark_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      _buildOverlayInformation(),
                      _buildProgressBar(),
                      _buildActionMenu(
                        watchlistProvider: watchlistProvider,
                        targetType: targetType,
                        isTvShow: isTvShow,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go(targetRoute),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: widget.isLandscape ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_outward_rounded,
                color: Colors.white.withValues(alpha: 0.24),
                size: 14,
              ),
            ],
          ),
        ),
        if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _lightPurple.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        _buildMetadata(isTvShow),
      ],
    );
  }
}

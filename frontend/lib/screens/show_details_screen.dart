// frontend/lib/screens/show_details_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/review.dart';
import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';

class ShowDetailsScreen extends StatefulWidget {
  final int showId;

  const ShowDetailsScreen({
    super.key,
    required this.showId,
  });

  @override
  State<ShowDetailsScreen> createState() =>
      _ShowDetailsScreenState();
}

class _ShowDetailsScreenState extends State<ShowDetailsScreen> {
  bool _isLoading = true;
  bool _isLogging = false;

  String _errorMessage = '';
  Map<String, dynamic>? _showDetails;
  List<Review> _reviews = [];

  List<dynamic> _episodes = [];
  int _currentSeason = 1;
  
  // 👇 Added state variable to hold the user's specific progress
  List<dynamic> _watchedEpisodes = [];

  @override
  void initState() {
    super.initState();

    _fetchShowDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WatchlistProvider>(
        context,
        listen: false,
      ).fetchCustomLists();
    });
  }

  Future<void> _fetchShowDetails() async {
    try {
      final details =
          await ApiService.getTvDetails(widget.showId);

      List<Review> fetchedReviews = [];

      try {
        fetchedReviews =
            await ApiService.getMovieReviews(widget.showId);
      } catch (_) {}

      List<dynamic> fetchedEpisodes = [];

      try {
        fetchedEpisodes =
            await ApiService.getTvSeasonDetails(
          widget.showId,
          _currentSeason,
        );
      } catch (_) {}

      // 👇 Fetch exact episode progress
      List<dynamic> fetchedProgress = [];
      try {
        fetchedProgress = await ApiService.getSpecificShowProgress(widget.showId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _showDetails = details;
          _reviews = fetchedReviews;
          _episodes = fetchedEpisodes;
          _watchedEpisodes = fetchedProgress;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _buildEpisodePayload({
    int? selectedSeason,
  }) {
    final details = _showDetails;

    if (details == null) {
      return <Map<String, dynamic>>[];
    }

    final runtimes =
        details['episode_run_time'] as List<dynamic>?;

    final defaultRuntime =
        runtimes != null && runtimes.isNotEmpty
            ? int.tryParse(runtimes.first.toString()) ?? 45
            : 45;

    final nextEpisode =
        details['next_episode_to_air'];

    final nextSeasonNumber = int.tryParse(
      (nextEpisode?['season_number'] ?? '').toString(),
    );

    final nextEpisodeNumber = int.tryParse(
      (nextEpisode?['episode_number'] ?? '').toString(),
    );

    final seasons =
        (details['seasons'] as List<dynamic>?)
                ?.where((season) {
              final number = int.tryParse(
                (season['season_number'] ?? '').toString(),
              );

              if (number == null || number <= 0) {
                return false;
              }

              return selectedSeason == null ||
                  number == selectedSeason;
            })
                .toList() ??
            <dynamic>[];

    final episodes = <Map<String, dynamic>>[];

    for (final season in seasons) {
      final seasonNumber = int.tryParse(
            (season['season_number'] ?? '').toString(),
          ) ??
          0;

      var episodeCount = int.tryParse(
            (season['episode_count'] ?? 0).toString(),
          ) ??
          0;

      final seasonAirDate = DateTime.tryParse(
        (season['air_date'] ?? '').toString(),
      );

      if (seasonAirDate != null &&
          seasonAirDate.isAfter(DateTime.now())) {
        continue;
      }

      if (nextSeasonNumber == seasonNumber &&
          nextEpisodeNumber != null) {
        episodeCount = (nextEpisodeNumber - 1).clamp(
          0,
          episodeCount,
        );
      }

      for (
        var episodeNumber = 1;
        episodeNumber <= episodeCount;
        episodeNumber++
      ) {
        episodes.add({
          'season_number': seasonNumber,
          'episode_number': episodeNumber,
          'runtime': defaultRuntime,
        });
      }
    }

    return episodes;
  }

  Future<void> _markAsWatched(
    String title,
    String? poster,
    String? backdrop,
    String option, {
    String? releaseDateStr,
    int? seasonNumber,
  }) async {
    Navigator.pop(context);

    if (_isLogging) return;

    setState(() {
      _isLogging = true;
    });

    DateTime? watchedAtDate;

    if (option == 'Just now') {
      watchedAtDate = DateTime.now().toUtc();
    } else if (option == 'Release date' &&
        releaseDateStr != null &&
        releaseDateStr.isNotEmpty) {
      watchedAtDate =
          DateTime.tryParse(releaseDateStr)?.toUtc() ??
              DateTime.now().toUtc();
    } else if (option == 'Other date') {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
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

      watchedAtDate = pickedDate.toUtc();
    }

    try {
      final allEpisodes = _buildEpisodePayload(
        selectedSeason: seasonNumber,
      );

      if (allEpisodes.isEmpty) {
        throw Exception(
          seasonNumber == null
              ? 'No released episodes were found for this show'
              : 'No released episodes were found in Season $seasonNumber',
        );
      }

      final totalShowEpisodes = int.tryParse(
            (_showDetails?['number_of_episodes'] ?? '')
                .toString(),
          ) ??
          allEpisodes.length;

      await ApiService.logShowWatchHistory(
        showId: widget.showId,
        title: title,
        posterPath: poster,
        backdropPath: backdrop,
        episodes: allEpisodes,
        totalEpisodes: totalShowEpisodes > 0
            ? totalShowEpisodes
            : allEpisodes.length,
        watchedAt: watchedAtDate?.toIso8601String(),
      );

      if (mounted) {
        setState(() {
          final newItems = allEpisodes.map(
            (episode) => {
              'season_number': episode['season_number'],
              'episode_number': episode['episode_number'],
            },
          );

          for (final newItem in newItems) {
            final alreadyExists = _watchedEpisodes.any(
              (item) =>
                  item['season_number'] ==
                      newItem['season_number'] &&
                  item['episode_number'] ==
                      newItem['episode_number'],
            );

            if (!alreadyExists) {
              _watchedEpisodes.add(newItem);
            }
          }
        });
      }

      _showSnackBar(
        seasonNumber == null
            ? 'Marked all episodes of "$title" as watched'
            : 'Marked Season $seasonNumber of "$title" as watched',
      );
    } catch (e) {
      _showSnackBar(
        'Failed to mark show as watched: '
        '${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }

  // 👇 New function specifically for checking off individual episodes
  Future<bool> _markEpisodeWatched({
    required String showTitle,
    required String? posterPath,
    required String? backdropPath,
    required int seasonNumber,
    required int episodeNumber,
    required int runtime,
    required int totalEpisodes,
  }) async {
    final alreadyWatched = _watchedEpisodes.any(
      (item) =>
          item['season_number'] == seasonNumber &&
          item['episode_number'] == episodeNumber,
    );

    if (alreadyWatched) return true;

    try {
      await ApiService.logWatchHistory(
        movieId: widget.showId,
        mediaType: 'tv',
        title: showTitle,
        posterPath: posterPath,
        backdropPath: backdropPath,
        runtimeMinutes: runtime,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        totalEpisodes: totalEpisodes,
        watchedAt: DateTime.now().toUtc().toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _watchedEpisodes.add({
            'season_number': seasonNumber,
            'episode_number': episodeNumber,
          });
        });
      }

      _showSnackBar(
        'Marked S$seasonNumber • E$episodeNumber as watched',
      );

      return true;
    } catch (e) {
      _showSnackBar(
        'Failed to log episode: '
        '${e.toString().replaceAll('Exception: ', '')}',
      );
      return false;
    }
  }

  void _showTrackPicker(
    String title,
    String? poster,
    String? backdrop,
    String? firstAirDate,
  ) {
    final seasons =
        (_showDetails?['seasons'] as List<dynamic>?)
                ?.where((season) {
              final number = int.tryParse(
                (season['season_number'] ?? '').toString(),
              );

              return number != null && number > 0;
            })
                .toList() ??
            <dynamic>[];

    seasons.sort((a, b) {
      final aNumber = int.tryParse(
            (a['season_number'] ?? 0).toString(),
          ) ??
          0;

      final bNumber = int.tryParse(
            (b['season_number'] ?? 0).toString(),
          ) ??
          0;

      return aNumber.compareTo(bNumber);
    });

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15151B),
      barrierColor:
          Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.sizeOf(sheetContext).height *
                      0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                10,
                12,
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSheetHandle(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        _buildSheetIcon(
                          Icons.checklist_rounded,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Track episodes',
                                style: TextStyle(
                                  color: Color(0xFFF5F3F8),
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Choose the entire show or a season',
                                style: TextStyle(
                                  color: Color(0xFF817C87),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildCloseButton(sheetContext),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(
                    color: Color(0xFF2D2933),
                    height: 1,
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.only(top: 8),
                      children: [
                        _buildMenuOption(
                          Icons.done_all_rounded,
                          'Entire show',
                          () {
                            Navigator.pop(sheetContext);

                            Future<void>.delayed(
                              Duration.zero,
                              () {
                                if (!mounted) return;

                                _showMarkWatchedMenu(
                                  title,
                                  poster,
                                  backdrop,
                                  firstAirDate,
                                );
                              },
                            );
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Divider(
                            color: Color(0xFF2D2933),
                            height: 1,
                          ),
                        ),
                        ...seasons.map((season) {
                          final seasonNumber =
                              int.tryParse(
                                (season[
                                            'season_number'] ??
                                        0)
                                    .toString(),
                              ) ??
                              0;

                          final episodeCount =
                              int.tryParse(
                                (season[
                                            'episode_count'] ??
                                        0)
                                    .toString(),
                              ) ??
                              0;

                          return _buildMenuOption(
                            Icons
                                .video_library_outlined,
                            'Season $seasonNumber'
                            '  •  $episodeCount episodes',
                            () {
                              Navigator.pop(
                                sheetContext,
                              );

                              Future<void>.delayed(
                                Duration.zero,
                                () {
                                  if (!mounted) return;

                                  _showMarkWatchedMenu(
                                    title,
                                    poster,
                                    backdrop,
                                    season['air_date']
                                        ?.toString(),
                                    seasonNumber:
                                        seasonNumber,
                                  );
                                },
                              );
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMarkWatchedMenu(
    String title,
    String? poster,
    String? backdrop,
    String? releaseDate, {
    int? seasonNumber,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151B),
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSheetHandle(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      _buildSheetIcon(Icons.check_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              seasonNumber == null
                                  ? 'Mark entire show watched'
                                  : 'Track Season $seasonNumber',
                              style: const TextStyle(
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
                      _buildCloseButton(context),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(
                  color: Color(0xFF2D2933),
                  height: 1,
                ),
                const SizedBox(height: 8),
                _buildMenuOption(
                  Icons.bolt_rounded,
                  'Just now',
                  () => _markAsWatched(
                    title,
                    poster,
                    backdrop,
                    'Just now',
                    seasonNumber: seasonNumber,
                  ),
                ),
                _buildMenuOption(
                  Icons.calendar_today_outlined,
                  'Release date',
                  () => _markAsWatched(
                    title,
                    poster,
                    backdrop,
                    'Release date',
                    releaseDateStr: releaseDate,
                    seasonNumber: seasonNumber,
                  ),
                ),
                _buildMenuOption(
                  Icons.edit_calendar_outlined,
                  'Other date',
                  () => _markAsWatched(
                    title,
                    poster,
                    backdrop,
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

  void _showMoreOptions(
    WatchlistProvider provider,
    String? posterPath,
    String title,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151B),
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSheetHandle(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      _buildSheetIcon(
                        Icons.playlist_add_rounded,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add to custom list',
                              style: TextStyle(
                                color: Color(0xFFF5F3F8),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Choose where to save this show',
                              style: TextStyle(
                                color: Color(0xFF817C87),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildCloseButton(context),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(
                  color: Color(0xFF2D2933),
                  height: 1,
                ),
                const SizedBox(height: 8),
                if (provider.customLists.isEmpty)
                  _buildSheetEmptyState(
                    icon: Icons.playlist_add_rounded,
                    message:
                        'No custom lists found.\nCreate one in the Lists tab.',
                  )
                else
                  ...provider.customLists.map((listData) {
                    final int listId = listData['id'];

                    final String listTitle =
                        listData['name'] ??
                            listData['title'] ??
                            'Untitled';

                    return _buildMenuOption(
                      Icons.playlist_add_rounded,
                      listTitle,
                      () {
                        provider.addMediaToList(
                          listId,
                          widget.showId,
                          posterPath,
                          title: title,
                          mediaType: 'tv',
                        );

                        Navigator.pop(context);

                        _showSnackBar(
                          'Added to "$listTitle"',
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

  Widget _buildSheetHandle() {
    return Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF45404B),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildSheetIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFCA53FF),
            Color(0xFF7C2BE8),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x447C2BE8),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 21,
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.pop(context),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF202026),
      ),
      icon: const Icon(
        Icons.close_rounded,
        color: Color(0xFFC1BBC6),
        size: 20,
      ),
    );
  }

  Widget _buildSheetEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 28,
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
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF817C87),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF271630),
                    borderRadius: BorderRadius.circular(10),
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

  void _showWhereToWatchModal(String showTitle) {
    final results =
        _showDetails!['watch/providers']?['results']
                as Map<String, dynamic>? ??
            {};

    final providers =
        results['IN'] ?? results['US'] ?? {};

    final flatrate =
        providers['flatrate'] as List<dynamic>? ?? [];

    final rent =
        providers['rent'] as List<dynamic>? ?? [];

    final buy =
        providers['buy'] as List<dynamic>? ?? [];

    if (flatrate.isEmpty &&
        rent.isEmpty &&
        buy.isEmpty) {
      _showSnackBar(
        'No streaming providers available',
      );

      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151B),
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                10,
                12,
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSheetHandle(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        _buildSheetIcon(
                          Icons.live_tv_rounded,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Where to watch',
                                style: TextStyle(
                                  color: Color(0xFFF5F3F8),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                showTitle,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF817C87),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildCloseButton(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(
                    color: Color(0xFF2D2933),
                    height: 1,
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (flatrate.isNotEmpty) ...[
                          _buildProviderHeading(
                            'Subscription',
                          ),
                          ...flatrate.map(
                            (provider) =>
                                _buildProviderTile(
                              provider,
                              showTitle,
                            ),
                          ),
                        ],
                        if (rent.isNotEmpty) ...[
                          _buildProviderHeading('Rent'),
                          ...rent.map(
                            (provider) =>
                                _buildProviderTile(
                              provider,
                              showTitle,
                            ),
                          ),
                        ],
                        if (buy.isNotEmpty) ...[
                          _buildProviderHeading('Buy'),
                          ...buy.map(
                            (provider) =>
                                _buildProviderTile(
                              provider,
                              showTitle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProviderHeading(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        20,
        12,
        8,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF9B5ABB),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildProviderTile(
    dynamic provider,
    String showTitle,
  ) {
    final logoPath = provider['logo_path'];
    final name =
        provider['provider_name'] ?? 'Unknown';

    final logoUrl = logoPath != null
        ? 'https://image.tmdb.org/t/p/w92$logoPath'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final query = Uri.encodeComponent(
              'Watch $showTitle on $name',
            );

            final url = Uri.parse(
              'https://www.google.com/search?q=$query',
            );

            if (await canLaunchUrl(url)) {
              await launchUrl(
                url,
                mode: LaunchMode.externalApplication,
              );
            } else if (mounted) {
              _showSnackBar(
                'Could not launch provider link',
              );
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A191F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF302C35),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return _buildProviderPlaceholder();
                          },
                        )
                      : _buildProviderPlaceholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFFF2EFF4),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'India',
                        style: TextStyle(
                          color: Color(0xFF77717D),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF281732),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    color: Color(0xFFCA66FF),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFF242129),
      child: const Icon(
        Icons.live_tv_rounded,
        color: Color(0xFF77717D),
        size: 20,
      ),
    );
  }

  String _getTopProviderLogoUrl() {
    if (_showDetails == null) return '';

    final results =
        _showDetails!['watch/providers']?['results']
                as Map<String, dynamic>? ??
            {};

    final providers =
        results['IN'] ?? results['US'] ?? {};

    final flatrate =
        providers['flatrate'] as List<dynamic>? ?? [];

    if (flatrate.isNotEmpty &&
        flatrate.first['logo_path'] != null) {
      return 'https://image.tmdb.org/t/p/w92'
          '${flatrate.first['logo_path']}';
    }

    final rent =
        providers['rent'] as List<dynamic>? ?? [];

    if (rent.isNotEmpty &&
        rent.first['logo_path'] != null) {
      return 'https://image.tmdb.org/t/p/w92'
          '${rent.first['logo_path']}';
    }

    return '';
  }

  void _showSeasonEpisodesModal(
    String fallbackBackdrop,
  ) {
    final seasons =
        (_showDetails!['seasons'] as List<dynamic>?)
                ?.where(
                  (season) =>
                      season['season_number'] != null,
                )
                .toList() ??
            [];

    bool isFetchingSeason = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151B),
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(
                          top: 10,
                          bottom: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF45404B),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          _buildSheetIcon(
                            Icons.video_library_outlined,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Episodes',
                                  style: TextStyle(
                                    color:
                                        Color(0xFFF5F3F8),
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Browse seasons and episodes',
                                  style: TextStyle(
                                    color:
                                        Color(0xFF817C87),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildCloseButton(context),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          PopupMenuButton<int>(
                            color: const Color(0xFF1E1E24),
                            surfaceTintColor:
                                const Color(0xFF1E1E24),
                            initialValue: _currentSeason,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0xFF39343F),
                              ),
                            ),
                            onSelected:
                                (int selectedSeason) async {
                              if (selectedSeason ==
                                  _currentSeason) {
                                return;
                              }

                              setModalState(() {
                                isFetchingSeason = true;
                              });

                              List<dynamic> newEpisodes = [];

                              try {
                                newEpisodes = await ApiService
                                    .getTvSeasonDetails(
                                  widget.showId,
                                  selectedSeason,
                                );
                              } catch (_) {}

                              setState(() {
                                _currentSeason =
                                    selectedSeason;
                                _episodes = newEpisodes;
                              });

                              setModalState(() {
                                isFetchingSeason = false;
                              });
                            },
                            itemBuilder: (context) {
                              return seasons.map((season) {
                                final seasonNumber =
                                    season['season_number'];

                                return PopupMenuItem<int>(
                                  value: seasonNumber,
                                  child: Text(
                                    season['name'] ??
                                        'Season $seasonNumber',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF1E1E24),
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      const Color(0xFF39343F),
                                ),
                              ),
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Text(
                                    'Season $_currentSeason',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons
                                        .keyboard_arrow_down_rounded,
                                    color:
                                        Color(0xFF918B99),
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_episodes.length} episodes',
                            style: const TextStyle(
                              color: Color(0xFFCA66FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(
                      color: Color(0xFF2D2933),
                      height: 1,
                    ),
                    Expanded(
                      child: isFetchingSeason
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFB84AF5),
                                strokeWidth: 3,
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding:
                                  const EdgeInsets.all(20),
                              itemCount: _episodes.length,
                              separatorBuilder:
                                  (context, index) {
                                return const SizedBox(
                                  height: 12,
                                );
                              },
                              itemBuilder:
                                  (context, index) {
                                final episode =
                                    _episodes[index];

                                final episodeStill =
                                    episode['still_path'];

                                final imageUrl =
                                    episodeStill != null
                                        ? 'https://image.tmdb.org/t/p/w300'
                                            '$episodeStill'
                                        : fallbackBackdrop
                                                .isNotEmpty
                                            ? fallbackBackdrop
                                            : 'https://via.placeholder.com/300x170?text=No+Image';

                                final episodeNumber =
                                    episode[
                                            'episode_number'] ??
                                        index + 1;
                                        
                                // 👇 Determine if THIS exact episode has been watched
                                final bool isWatched = _watchedEpisodes.any((item) => 
                                  item['season_number'] == _currentSeason && 
                                  item['episode_number'] == episodeNumber
                                );

                                return _buildEpisodeListTile(
                                  episode: episode,
                                  imageUrl: imageUrl,
                                  episodeNumber:
                                      episodeNumber,
                                  isWatched: isWatched,
                                  onMarkWatched: () async {
                                    final success =
                                        await _markEpisodeWatched(
                                      showTitle:
                                          _showDetails?['name'] ??
                                              'Untitled Show',
                                      posterPath:
                                          _showDetails?['poster_path']
                                              ?.toString(),
                                      backdropPath:
                                          _showDetails?['backdrop_path']
                                              ?.toString(),
                                      seasonNumber:
                                          _currentSeason,
                                      episodeNumber:
                                          episodeNumber,
                                      runtime:
                                          episode['runtime'] ?? 45,
                                      totalEpisodes:
                                          _showDetails?[
                                                  'number_of_episodes'] ??
                                              1,
                                    );

                                    if (success) {
                                      setModalState(() {});
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // 👇 Updated to accept isWatched boolean and interaction callback
  Widget _buildEpisodeListTile({
    required dynamic episode,
    required String imageUrl,
    required dynamic episodeNumber,
    required bool isWatched,
    required VoidCallback onMarkWatched,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A191F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF302C35),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              width: 140,
              height: 79,
              fit: BoxFit.cover,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return Container(
                  width: 140,
                  height: 79,
                  color: const Color(0xFF242129),
                  child: const Icon(
                    Icons.tv_rounded,
                    color: Color(0xFF77717D),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  episode['name'] ??
                      'Episode $episodeNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF2EFF4),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'S$_currentSeason • E$episodeNumber',
                  style: const TextStyle(
                    color: Color(0xFF817C87),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF281732),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${episode['runtime'] ?? 45}m',
                    style: const TextStyle(
                      color: Color(0xFFCA66FF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // 👇 Interactive Checkmark for marking individual episodes!
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isWatched ? null : onMarkWatched,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isWatched 
                      ? const Color(0xFF7D398F).withValues(alpha: 0.2) 
                      : Colors.transparent,
                  border: Border.all(
                    color: isWatched 
                        ? const Color(0xFF7D398F) 
                        : const Color(0xFF302C35),
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: isWatched ? const Color(0xFFCA66FF) : const Color(0xFF514C59),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReviewDialog() {
    final reviewController =
        TextEditingController();

    double currentRating = 5.0;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF17151B),
              surfaceTintColor: const Color(0xFF17151B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Color(0xFF39333F),
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                0,
              ),
              contentPadding: const EdgeInsets.fromLTRB(
                24,
                20,
                24,
                12,
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                24,
                0,
                24,
                20,
              ),
              title: const Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF281732),
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(
                        Icons.rate_review_outlined,
                        color: Color(0xFFCA66FF),
                        size: 19,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Add review',
                    style: TextStyle(
                      color: Color(0xFFF5F3F8),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E0E12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF34313A),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFCA66FF),
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          const Text(
                            'Your rating',
                            style: TextStyle(
                              color: Color(0xFFDAD6DF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${currentRating.toInt()}/10',
                            style: const TextStyle(
                              color: Color(0xFFCA66FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor:
                            const Color(0xFFB143EB),
                        inactiveTrackColor:
                            const Color(0xFF34303A),
                        thumbColor:
                            const Color(0xFFCA66FF),
                        overlayColor:
                            const Color(0x337C2BE8),
                      ),
                      child: Slider(
                        value: currentRating,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (value) {
                          setDialogState(() {
                            currentRating = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reviewController,
                      maxLines: 4,
                      style: const TextStyle(
                        color: Color(0xFFF5F3F8),
                        fontSize: 13,
                      ),
                      cursorColor: const Color(0xFFBD4DFF),
                      decoration: InputDecoration(
                        hintText: 'Write your thoughts...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF625D67),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0E0E12),
                        contentPadding:
                            const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF34313A),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFA943E9),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        const Color(0xFF918B99),
                  ),
                  child: const Text('Cancel'),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFB143EB),
                        Color(0xFF8431D9),
                      ],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() {
                              isSubmitting = true;
                            });

                            try {
                              await ApiService.postReview(
                                movieId: widget.showId,
                                rating: currentRating,
                                comment:
                                    reviewController.text,
                              );

                              if (!context.mounted) return;

                              Navigator.pop(context);
                              _fetchShowDetails();

                              _showSnackBar(
                                'Review added successfully',
                              );
                            } catch (e) {
                              if (!context.mounted) return;

                              _showSnackBar(
                                'Failed to post review',
                              );

                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor:
                          Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _launchTrailer() async {
    final videos =
        _showDetails!['videos']?['results']
            as List<dynamic>?;

    if (videos != null && videos.isNotEmpty) {
      final trailer = videos.firstWhere(
        (video) =>
            video['site'] == 'YouTube' &&
            video['type'] == 'Trailer',
        orElse: () => videos.first,
      );

      final url = Uri.parse(
        'https://www.youtube.com/watch?v='
        '${trailer['key']}',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );

        return;
      }
    }

    _showSnackBar('No trailer available');
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
                text,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF08080B),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Color(0xFFB84AF5),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Loading show details...',
                style: TextStyle(
                  color: Color(0xFF817C87),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty ||
        _showDetails == null) {
      return _buildErrorScreen();
    }

    final name =
        _showDetails!['name'] ?? 'Untitled Show';

    final backdropPath =
        _showDetails!['backdrop_path'];

    final posterPath =
        _showDetails!['poster_path'];

    final overview =
        _showDetails!['overview'] ??
            'No overview available.';

    final firstAirDate =
        _showDetails!['first_air_date'] ?? '';

    final releaseYear = firstAirDate.length >= 4
        ? firstAirDate.substring(0, 4)
        : '';

    final voteAverage =
        (_showDetails!['vote_average'] ?? 0.0)
            .toStringAsFixed(1);

    final status =
        _showDetails!['status'] ?? 'Unknown';

    final numberOfEpisodes =
        _showDetails!['number_of_episodes'] ?? 0;

    final genres =
        (_showDetails!['genres'] as List<dynamic>?)
                ?.map(
                  (genre) => genre['name'].toString(),
                )
                .toList() ??
            [];

    final cast =
        (_showDetails!['credits']?['cast']
                as List<dynamic>?) ??
            [];

    final creator =
        (_showDetails!['created_by']
                        as List<dynamic>?)
                    ?.isNotEmpty ==
                true
            ? _showDetails!['created_by'][0]['name']
            : 'Unknown Creator';

    final backdropUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w1280'
            '$backdropPath'
        : '';

    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500'
            '$posterPath'
        : '';

    final watchlistProvider =
        Provider.of<WatchlistProvider>(context);

    final currentStatus =
        watchlistProvider.getMediaStatus(
      widget.showId,
      mediaType: 'tv',
    );

    final isWatchlist =
        currentStatus == 'watchlist';

    final isFavorite =
        currentStatus == 'favorite';

    final bool isWide =
        MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      body: Stack(
        children: [
          if (backdropUrl.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              left: 0,
              height: isWide ? 610 : 480,
              child: Image.network(
                backdropUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            height: isWide ? 640 : 510,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x4D08080B),
                    Color(0xB308080B),
                    Color(0xF208080B),
                    Color(0xFF08080B),
                  ],
                  stops: [0, 0.44, 0.82, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 2,
                sigmaY: 2,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
          Positioned(
            top: 40,
            right: -120,
            child: _buildBackgroundGlow(
              size: 360,
              color: const Color(0xFF9E3DDA),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor:
                      const Color(0xCC08080B),
                  surfaceTintColor:
                      Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  toolbarHeight: 64,
                  leadingWidth: 72,
                  leading: Padding(
                    padding: const EdgeInsets.only(
                      left: 18,
                    ),
                    child: _buildTopButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () {
                        context.canPop()
                            ? context.pop()
                            : context.go('/');
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 1400,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 36 : 20,
                          isWide ? 30 : 18,
                          isWide ? 36 : 20,
                          48,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (isWide)
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _buildPoster(posterUrl),
                                  const SizedBox(width: 42),
                                  Expanded(
                                    child:
                                        _buildDetailsColumn(
                                      name,
                                      creator,
                                      releaseYear,
                                      numberOfEpisodes,
                                      genres,
                                      status,
                                      overview,
                                      posterPath,
                                      voteAverage,
                                      firstAirDate,
                                      isWatchlist,
                                      isFavorite,
                                      watchlistProvider,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child:
                                        _buildPoster(posterUrl),
                                  ),
                                  const SizedBox(height: 26),
                                  _buildDetailsColumn(
                                    name,
                                    creator,
                                    releaseYear,
                                    numberOfEpisodes,
                                    genres,
                                    status,
                                    overview,
                                    posterPath,
                                    voteAverage,
                                    firstAirDate,
                                    isWatchlist,
                                    isFavorite,
                                    watchlistProvider,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 48),
                            if (_episodes.isNotEmpty) ...[
                              _buildEpisodesSection(
                                backdropUrl,
                              ),
                              const SizedBox(height: 38),
                            ],
                            if (cast.isNotEmpty) ...[
                              _buildSectionHeader(
                                icon:
                                    Icons.groups_2_outlined,
                                title: 'Cast',
                                subtitle:
                                    'Meet the people behind the show',
                              ),
                              const SizedBox(height: 16),
                              _buildCastList(cast),
                              const SizedBox(height: 38),
                            ],
                            _buildReviewsHeader(),
                            const SizedBox(height: 16),
                            _buildReviewsList(),
                          ],
                        ),
                      ),
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

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            context.canPop()
                ? context.pop()
                : context.go('/');
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 34,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF15151B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF382832),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2A151C),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFFF647C),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Unable to load show',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF5F3F8),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage.isNotEmpty
                        ? _errorMessage
                        : 'Failed to load show details',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF918B99),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton({
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xCC17151B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF39343F),
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster(String posterUrl) {
    final screenWidth =
        MediaQuery.sizeOf(context).width;

    final width = screenWidth < 420
        ? screenWidth - 64
        : screenWidth < 760
            ? 260.0
            : 300.0;

    final height = width * 1.5;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF15151B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF3A3540),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8A000000),
            blurRadius: 40,
            offset: Offset(0, 22),
          ),
          BoxShadow(
            color: Color(0x337C2BE8),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: posterUrl.isNotEmpty
            ? Image.network(
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
            : _buildPosterPlaceholder(),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: const Color(0xFF15151B),
      alignment: Alignment.center,
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          color: Color(0xFF211528),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.tv_rounded,
          color: Color(0xFF694078),
          size: 38,
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(
    String title,
    String creator,
    String releaseYear,
    int episodes,
    List<String> genres,
    String status,
    String overview,
    String? posterPath,
    String voteAverage,
    String firstAirDate,
    bool isWatchlist,
    bool isFavorite,
    WatchlistProvider watchlistProvider,
  ) {
    final providerLogoUrl =
        _getTopProviderLogoUrl();

    return Column(
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
            Text(
              'TV SERIES',
              style: TextStyle(
                color: Color(0xFFCA66FF),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFFFAF9FC),
            fontSize:
                MediaQuery.sizeOf(context).width < 760
                    ? 34
                    : 48,
            height: 1.02,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Created by $creator',
          style: const TextStyle(
            color: Color(0xFFA29CA8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            if (releaseYear.isNotEmpty)
              _buildMetadataChip(
                icon: Icons.calendar_today_outlined,
                label: releaseYear,
              ),
            _buildMetadataChip(
              icon: Icons.video_library_outlined,
              label: '$episodes episodes',
            ),
            _buildMetadataChip(
              icon: Icons.star_rounded,
              label: voteAverage,
              highlighted: true,
            ),
            _buildMetadataChip(
              icon: Icons.circle,
              label: status,
              highlighted: true,
            ),
          ],
        ),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genres.map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xB315151B),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF34303A),
                  ),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(
                    color: Color(0xFFB9B3BF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          overview,
          style: const TextStyle(
            color: Color(0xFFB1ABB7),
            height: 1.75,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 28),
        if (providerLogoUrl.isNotEmpty)
          _buildTopProvider(
            title,
            providerLogoUrl,
          )
        else
          _buildUnavailableProvider(title),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildPrimaryActionButton(
              label: _isLogging
                  ? 'Adding...'
                  : 'Mark watched',
              icon: Icons.check_rounded,
              isLoading: _isLogging,
              onTap: () => _showTrackPicker(
                title,
                posterPath,
                _showDetails?['backdrop_path']?.toString(),
                firstAirDate,
              ),
            ),
            _buildActionButton(
              tooltip: 'Add to custom list',
              icon: Icons.list_alt_rounded,
              isActive: false,
              onTap: () => _showMoreOptions(
                watchlistProvider,
                posterPath,
                title,
              ),
            ),
            _buildActionButton(
              tooltip: isWatchlist
                  ? 'Remove from Watchlist'
                  : 'Add to Watchlist',
              icon: isWatchlist
                  ? Icons.bookmark_added_rounded
                  : Icons.bookmark_add_outlined,
              isActive: isWatchlist,
              onTap: () async {
                if (isWatchlist) {
                  await watchlistProvider
                      .removeFromWatchlist(
                    widget.showId,
                    mediaType: 'tv',
                  );

                  if (mounted) {
                    _showSnackBar(
                      'Removed from Watchlist',
                    );
                  }
                } else {
                  await watchlistProvider.addToWatchlist(
                    movieId: widget.showId,
                    movieTitle: title,
                    posterPath: posterPath,
                    status: 'watchlist',
                    mediaType: 'tv',
                    releaseYear: releaseYear,
                    totalEpisodes: episodes,
                    voteAverage:
                        double.tryParse(voteAverage) ??
                            0.0,
                  );

                  if (mounted) {
                    _showSnackBar(
                      'Added to Watchlist',
                    );
                  }
                }
              },
            ),
            _buildActionButton(
              tooltip: 'Watch trailer',
              icon: Icons.play_arrow_rounded,
              isActive: false,
              onTap: _launchTrailer,
            ),
            _buildActionButton(
              tooltip: isFavorite
                  ? 'Remove from Favorites'
                  : 'Add to Favorites',
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              isActive: isFavorite,
              activeColor:
                  const Color(0xFFFF647C),
              onTap: () async {
                if (isFavorite) {
                  await watchlistProvider
                      .removeFromWatchlist(
                    widget.showId,
                    mediaType: 'tv',
                  );

                  if (mounted) {
                    _showSnackBar(
                      'Removed from Favorite',
                    );
                  }
                } else {
                  await watchlistProvider.addToWatchlist(
                    movieId: widget.showId,
                    movieTitle: title,
                    posterPath: posterPath,
                    status: 'favorite',
                    mediaType: 'tv',
                    releaseYear: releaseYear,
                    totalEpisodes: episodes,
                    voteAverage:
                        double.tryParse(voteAverage) ??
                            0.0,
                  );

                  if (mounted) {
                    _showSnackBar(
                      'Added to Favorite',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataChip({
    required IconData icon,
    required String label,
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFF281732)
            : const Color(0xB315151B),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF5A3268)
              : const Color(0xFF34303A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: highlighted
                ? const Color(0xFFCA66FF)
                : const Color(0xFF918B99),
            size: icon == Icons.circle ? 7 : 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: highlighted
                  ? const Color(0xFFF0D9FF)
                  : const Color(0xFFB9B3BF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProvider(
    String title,
    String providerLogoUrl,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showWhereToWatchModal(title),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xB315151B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF34303A),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.network(
                  providerLogoUrl,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHERE TO WATCH',
                    style: TextStyle(
                      color: Color(0xFF817C87),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View streaming options',
                    style: TextStyle(
                      color: Color(0xFFF2EFF4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFFCA66FF),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailableProvider(String title) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showWhereToWatchModal(title),
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.live_tv_rounded,
                color: Color(0xFF6F6975),
                size: 18,
              ),
              SizedBox(width: 9),
              Text(
                'No streaming services listed',
                style: TextStyle(
                  color: Color(0xFF77717D),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActionButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFB143EB),
            Color(0xFF8431D9),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x557C2BE8),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 19,
                  ),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String tooltip,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    Color activeColor = const Color(0xFFCA66FF),
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.13)
                  : const Color(0xD915151B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? activeColor.withValues(alpha: 0.5)
                    : const Color(0xFF34303A),
              ),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? activeColor
                  : const Color(0xFFE1DDE5),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodesSection(
    String backdropUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                _showSeasonEpisodesModal(backdropUrl),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSectionHeader(
                      icon: Icons.video_library_outlined,
                      title:
                          'Season $_currentSeason',
                      subtitle:
                          '${_episodes.length} available episodes',
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181D),
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            const Color(0xFF2D2933),
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
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 196,
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _episodes.length,
              itemBuilder: (context, index) {
                final episode = _episodes[index];
                final episodeStill =
                    episode['still_path'];

                final imageUrl = episodeStill != null
                    ? 'https://image.tmdb.org/t/p/w300'
                        '$episodeStill'
                    : backdropUrl.isNotEmpty
                        ? backdropUrl
                        : 'https://via.placeholder.com/300x170?text=No+Image';

                final episodeName =
                    episode['name'] ??
                        'Episode ${index + 1}';

                final episodeRuntime =
                    episode['runtime'] ?? 45;

                final episodeNumber =
                    episode['episode_number'] ??
                        index + 1;

                final isWatched = _watchedEpisodes.any(
                  (item) =>
                      item['season_number'] == _currentSeason &&
                      item['episode_number'] == episodeNumber,
                );

                return Container(
                  width: 250,
                  margin:
                      const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15151B),
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF2D2933),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(11),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Container(
                                    color: const Color(
                                      0xFF242129,
                                    ),
                                    child: const Icon(
                                      Icons.tv_rounded,
                                      color: Color(
                                        0xFF77717D,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient:
                                      LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment
                                        .bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(0xB3000000),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets
                                      .symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        const Color(0xD90C0B0F),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${episodeRuntime}m',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                episodeName,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color:
                                      Color(0xFFF2EFF4),
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              isWatched
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isWatched
                                  ? const Color(0xFFCA66FF)
                                  : const Color(0xFF514C59),
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        child: Text(
                          'S$_currentSeason • E$episodeNumber',
                          style: const TextStyle(
                            color: Color(0xFF77717D),
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
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
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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

  Widget _buildCastList(List<dynamic> cast) {
    return SizedBox(
      height: 210,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          },
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: cast.length,
          itemBuilder: (context, index) {
            final person = cast[index];
            final personId = person['id'];
            final personName = person['name'] ?? '';
            final character =
                person['character'] ?? '';
            final profilePath =
                person['profile_path'];

            final profileUrl = profilePath != null
                ? 'https://image.tmdb.org/t/p/w185'
                    '$profilePath'
                : '';

            return GestureDetector(
              onTap: () {
                context.go('/person/$personId');
              },
              child: Container(
                width: 124,
                margin:
                    const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2D2933),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(11),
                        child: profileUrl.isNotEmpty
                            ? Image.network(
                                profileUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return _buildPersonPlaceholder();
                                },
                              )
                            : _buildPersonPlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      child: Text(
                        personName,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF2EFF4),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      child: Text(
                        character,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF77717D),
                          fontSize: 9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPersonPlaceholder() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1C1921),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFF625A68),
        size: 38,
      ),
    );
  }

  Widget _buildReviewsHeader() {
    return Row(
      children: [
        Expanded(
          child: _buildSectionHeader(
            icon: Icons.rate_review_outlined,
            title: 'Reviews',
            subtitle: 'What the community is saying',
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF281732),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: const Color(0xFF4B2A59),
            ),
          ),
          child: TextButton.icon(
            onPressed: _showAddReviewDialog,
            icon: const Icon(
              Icons.add_rounded,
              size: 17,
            ),
            label: const Text('Add review'),
            style: TextButton.styleFrom(
              foregroundColor:
                  const Color(0xFFCA66FF),
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 11,
              ),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 30,
        ),
        decoration: BoxDecoration(
          color: const Color(0x9915151B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF28242E),
          ),
        ),
        child: const Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF211528),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFFBD4DFF),
                  size: 25,
                ),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'No reviews yet',
              style: TextStyle(
                color: Color(0xFFF5F3F8),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Be the first to share your thoughts.',
              style: TextStyle(
                color: Color(0xFF817C87),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 170,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          },
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _reviews.length,
          itemBuilder: (context, index) {
            final review = _reviews[index];

            final authorLetter =
                review.username.isNotEmpty
                    ? review.username[0].toUpperCase()
                    : '?';

            return Container(
              width: 300,
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: const Color(0xCC15151B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2D2933),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFB143EB),
                              Color(0xFF7130BA),
                            ],
                          ),
                        ),
                        child: Text(
                          authorLetter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          review.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF2EFF4),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF281732),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFCA66FF),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${review.rating}/10',
                              style: const TextStyle(
                                color:
                                    Color(0xFFF0D9FF),
                                fontSize: 9,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Expanded(
                    child: Text(
                      review.comment ?? '',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB1ABB7),
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
// frontend/lib/screens/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _progressItems = [];
  
  final Set<int> _markingShows = {};
  final Set<int> _removingShows = {};

  @override
  void initState() {
    super.initState();
    _fetchProgressData();
  }

  Future<void> _fetchProgressData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await ApiService.getShowProgress();

      if (mounted) {
        setState(() {
          _progressItems = results;
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

  Future<void> _markNextEpisodeWatched(dynamic show) async {
    final showId = int.tryParse(
          (show['show_id'] ?? 0).toString(),
        ) ??
        0;

    if (showId <= 0 || _markingShows.contains(showId)) return;

    setState(() {
      _markingShows.add(showId);
    });

    try {
      final details = await ApiService.getTvDetails(showId);
      final watched =
          await ApiService.getSpecificShowProgress(showId);

      final watchedKeys = watched
          .map(
            (item) =>
                '${item['season_number']}:${item['episode_number']}',
          )
          .toSet();

      final seasons =
          (details['seasons'] as List<dynamic>?)
                  ?.where((season) {
                final number = season['season_number'];
                return number is int && number > 0;
              })
                  .toList() ??
              [];

      seasons.sort(
        (a, b) => (a['season_number'] as int)
            .compareTo(b['season_number'] as int),
      );

      Map<String, dynamic>? nextEpisode;
      int? nextSeasonNumber;
      var releasedEpisodeCount = 0;

      for (final season in seasons) {
        final seasonNumber = season['season_number'] as int;
        final episodes = await ApiService.getTvSeasonDetails(
          showId,
          seasonNumber,
        );

        releasedEpisodeCount += episodes.length;

        if (nextEpisode != null) continue;

        for (final rawEpisode in episodes) {
          final episode =
              Map<String, dynamic>.from(rawEpisode as Map);
          final episodeNumber = int.tryParse(
            (episode['episode_number'] ?? '').toString(),
          );

          if (episodeNumber == null) continue;

          final airDate =
              DateTime.tryParse('${episode['air_date'] ?? ''}');

          if (airDate != null && airDate.isAfter(DateTime.now())) {
            continue;
          }

          if (!watchedKeys.contains(
            '$seasonNumber:$episodeNumber',
          )) {
            nextEpisode = episode;
            nextSeasonNumber = seasonNumber;
            break;
          }
        }
      }

      if (nextEpisode == null || nextSeasonNumber == null) {
        await _fetchProgressData();
        return;
      }

      final episodeNumber = int.parse(
        nextEpisode['episode_number'].toString(),
      );

      final title = (details['name'] ??
              show['title'] ??
              'Unknown Show')
          .toString();

      await ApiService.logWatchHistory(
        movieId: showId,
        mediaType: 'tv',
        title: title,
        seasonNumber: nextSeasonNumber,
        episodeNumber: episodeNumber,
        runtimeMinutes: int.tryParse(
              (nextEpisode['runtime'] ?? 45).toString(),
            ) ??
            45,
        posterPath: details['poster_path']?.toString(),
        backdropPath: details['backdrop_path']?.toString(),
        totalEpisodes: releasedEpisodeCount > 0
            ? releasedEpisodeCount
            : int.tryParse(
                  (details['number_of_episodes'] ?? 1)
                      .toString(),
                ) ??
                1,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Marked $title S$nextSeasonNumber • '
            'E$episodeNumber as watched',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF17151B),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _fetchProgressData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed: ${e.toString().replaceAll('Exception: ', '')}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFE34D67),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _markingShows.remove(showId);
        });
      }
    }
  }

  Future<void> _removeShowFromHistory(
    dynamic show,
  ) async {
    final showId = int.tryParse(
          (show['show_id'] ?? 0).toString(),
        ) ??
        0;

    if (showId <= 0 ||
        _removingShows.contains(showId)) {
      return;
    }

    final title =
        (show['title'] ?? 'this show').toString();

    final shouldRemove = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(
        alpha: 0.78,
      ),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17151B),
          surfaceTintColor: const Color(0xFF17151B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: Color(0xFF39333F),
            ),
          ),
          title: Row(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF2A151C),
                  borderRadius: BorderRadius.all(
                    Radius.circular(10),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFFF647C),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: const Text(
                  'Remove from history?',
                  style: TextStyle(
                    color: Color(0xFFF5F3F8),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'This will remove every watched episode of '
            '"$title" from Watch History and delete its '
            'progress. This action cannot be undone.',
            style: const TextStyle(
              color: Color(0xFFB1ABB7),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    const Color(0xFF918B99),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFE34D67),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
              ),
              label: const Text(
                'Remove all',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true || !mounted) {
      return;
    }

    setState(() {
      _removingShows.add(showId);
    });

    try {
      await ApiService.removeShowHistory(showId);

      if (!mounted) return;

      setState(() {
        _progressItems.removeWhere((item) {
          final itemId = int.tryParse(
                (item['show_id'] ?? 0).toString(),
              ) ??
              0;

          return itemId == showId;
        });
      });

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
                  'Removed "$title" and all its '
                  'episodes from history',
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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
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
    } finally {
      if (mounted) {
        setState(() {
          _removingShows.remove(showId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08080B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'In Progress',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFCA66FF)),
              )
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Color(0xFFFF647C)),
                    ),
                  )
                : _progressItems.isEmpty
                    ? const Center(
                        child: Text(
                          'No media currently in progress',
                          style: TextStyle(color: Color(0xFF817C87), fontSize: 14),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchProgressData,
                        color: const Color(0xFFCA66FF),
                        backgroundColor: const Color(0xFF17151B),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16.0),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 450,
                            mainAxisExtent: 154, 
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _progressItems.length,
                          itemBuilder: (context, index) {
                            final item = _progressItems[index];
                            
                            final int showIdInt = item['show_id'] ?? 0;
                            final String id = showIdInt.toString();
                            final String title = item['title'] ?? 'Untitled';
                            final String seasonStr = item['season'] ?? '';
                            final int watchedEps = item['watchedEpisodes'] ?? 0;
                            final int totalEps = item['totalEpisodes'] ?? 1;
                            
                            final double progressVal = (watchedEps / totalEps).clamp(0.0, 1.0);
                            final bool isFinished = watchedEps >= totalEps;
                            
                            final int seasonNum = int.tryParse(
                                  (item['nextSeasonNumber'] ??
                                          seasonStr.replaceAll(RegExp(r'[^0-9]'), ''))
                                      .toString(),
                                ) ??
                                1;

                            final int nextEp = int.tryParse(
                                  (item['nextEpisodeNumber'] ?? watchedEps + 1)
                                      .toString(),
                                ) ??
                                watchedEps + 1;

                            final String subtitle = isFinished
                                ? 'Completed'
                                : 'Next: S$seasonNum • E$nextEp';

                            final String rawPoster = (item['backdrop_path'] ?? '').toString();
                            final String imageUrl = rawPoster.isNotEmpty && rawPoster != 'null'
                                ? 'https://image.tmdb.org/t/p/w500$rawPoster'
                                : '';

                            return GestureDetector(
                              onTap: () {
                                context.go('/tv/$id');
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF15151B),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2D2933)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 18,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(15),
                                      ),
                                      child: SizedBox(
                                        width: 105,
                                        height: double.infinity,
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => _buildPlaceholder(),
                                              )
                                            : _buildPlaceholder(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xFFF5F3F8),
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 15,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (_removingShows
                                                    .contains(
                                                  showIdInt,
                                                ))
                                                  const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(
                                                        0xFFFF647C,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  PopupMenuButton<
                                                      String>(
                                                    tooltip:
                                                        'Show options',
                                                    padding:
                                                        EdgeInsets.zero,
                                                    color: const Color(
                                                      0xFF17151B,
                                                    ),
                                                    surfaceTintColor:
                                                        const Color(
                                                      0xFF17151B,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                        12,
                                                      ),
                                                      side:
                                                          const BorderSide(
                                                        color: Color(
                                                          0xFF39333F,
                                                        ),
                                                      ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons
                                                          .more_vert_rounded,
                                                      color: Color(
                                                        0xFF817C87,
                                                      ),
                                                      size: 19,
                                                    ),
                                                    onSelected:
                                                        (value) {
                                                      if (value ==
                                                          'remove') {
                                                        _removeShowFromHistory(
                                                          item,
                                                        );
                                                      }
                                                    },
                                                    itemBuilder:
                                                        (context) {
                                                      return [
                                                        const PopupMenuItem<
                                                            String>(
                                                          value:
                                                              'remove',
                                                          child: Row(
                                                            children: [
                                                              DecoratedBox(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color:
                                                                      Color(
                                                                    0xFF2A151C,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius.all(
                                                                    Radius.circular(
                                                                      8,
                                                                    ),
                                                                  ),
                                                                ),
                                                                child:
                                                                    Padding(
                                                                  padding:
                                                                      EdgeInsets.all(
                                                                    7,
                                                                  ),
                                                                  child:
                                                                      Icon(
                                                                    Icons
                                                                        .delete_outline_rounded,
                                                                    color:
                                                                        Color(
                                                                      0xFFFF647C,
                                                                    ),
                                                                    size:
                                                                        17,
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width:
                                                                    10,
                                                              ),
                                                              Text(
                                                                'Remove from History',
                                                                style:
                                                                    TextStyle(
                                                                  color:
                                                                      Color(
                                                                    0xFFFF647C,
                                                                  ),
                                                                  fontSize:
                                                                      12,
                                                                  fontWeight:
                                                                      FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ];
                                                    },
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF817C87),
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Spacer(),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                value: progressVal,
                                                minHeight: 6,
                                                backgroundColor: const Color(0xFF2A2730),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  isFinished
                                                      ? const Color(0xFFCA66FF)
                                                      : const Color(0xFFE8E4EB),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    isFinished ? 'All caught up' : '${totalEps - watchedEps} left',
                                                    style: const TextStyle(
                                                      color: Color(0xFFF5F3F8),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                if (!isFinished)
                                                  GestureDetector(
                                                    onTap: () => _markNextEpisodeWatched(item),
                                                    child: Container(
                                                      color: Colors.transparent,
                                                      child: _markingShows.contains(showIdInt)
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Color(0xFFCA66FF),
                                                              ),
                                                            )
                                                          : const Icon(
                                                              Icons.done_all_rounded,
                                                              color: Color(0xFFCA66FF),
                                                              size: 20,
                                                            ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF201824),
      child: const Center(
        child: Icon(
          Icons.tv_rounded,
          color: Color(0xFF694078),
          size: 32,
        ),
      ),
    );
  }
}
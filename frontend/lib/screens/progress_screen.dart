import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const Color _background = Color(0xFF08080B);
  static const Color _surface = Color(0xFF141318);
  static const Color _surfaceElevated = Color(0xFF1A181F);
  static const Color _border = Color(0xFF302B36);
  static const Color _primary = Color(0xFFCA66FF);
  static const Color _primarySoft = Color(0xFF2C1936);
  static const Color _textPrimary = Color(0xFFF7F4F8);
  static const Color _textSecondary = Color(0xFFA39DA9);
  static const Color _textMuted = Color(0xFF77717D);
  static const Color _danger = Color(0xFFFF647C);

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
    final showId = int.tryParse((show['show_id'] ?? 0).toString()) ?? 0;

    if (showId <= 0 || _markingShows.contains(showId)) {
      return;
    }

    setState(() {
      _markingShows.add(showId);
    });

    try {
      final details = await ApiService.getTvDetails(showId);

      final watched = await ApiService.getSpecificShowProgress(showId);

      final watchedKeys = watched
          .map(
            (item) =>
                '${item['season_number']}:'
                '${item['episode_number']}',
          )
          .toSet();

      final seasons =
          (details['seasons'] as List<dynamic>?)?.where((season) {
            final number = season['season_number'];

            return number is int && number > 0;
          }).toList() ??
          [];

      seasons.sort(
        (a, b) =>
            (a['season_number'] as int).compareTo(b['season_number'] as int),
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

        if (nextEpisode != null) {
          continue;
        }

        for (final rawEpisode in episodes) {
          final episode = Map<String, dynamic>.from(rawEpisode as Map);

          final episodeNumber = int.tryParse(
            (episode['episode_number'] ?? '').toString(),
          );

          if (episodeNumber == null) {
            continue;
          }

          final airDate = DateTime.tryParse('${episode['air_date'] ?? ''}');

          if (airDate != null && airDate.isAfter(DateTime.now())) {
            continue;
          }

          if (!watchedKeys.contains('$seasonNumber:$episodeNumber')) {
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

      final episodeNumber = int.parse(nextEpisode['episode_number'].toString());

      final title = (details['name'] ?? show['title'] ?? 'Unknown Show')
          .toString();

      await ApiService.logWatchHistory(
        movieId: showId,
        mediaType: 'tv',
        title: title,
        seasonNumber: nextSeasonNumber,
        episodeNumber: episodeNumber,
        runtimeMinutes:
            int.tryParse((nextEpisode['runtime'] ?? 45).toString()) ?? 45,
        posterPath: details['poster_path']?.toString(),
        backdropPath: details['backdrop_path']?.toString(),
        totalEpisodes: releasedEpisodeCount > 0
            ? releasedEpisodeCount
            : int.tryParse((details['number_of_episodes'] ?? 1).toString()) ??
                  1,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
          message:
              'Marked $title S$nextSeasonNumber '
              '• E$episodeNumber as watched',
        ),
      );

      await _fetchProgressData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar(
            message: 'Failed: ${e.toString().replaceAll('Exception: ', '')}',
            isError: true,
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

  Future<void> _removeShowFromHistory(dynamic show) async {
    final showId = int.tryParse((show['show_id'] ?? 0).toString()) ?? 0;

    if (showId <= 0 || _removingShows.contains(showId)) {
      return;
    }

    final title = (show['title'] ?? 'this show').toString();

    final shouldRemove = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surfaceElevated,
          surfaceTintColor: _surfaceElevated,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF321A22),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFF5D2D3B)),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: _danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remove from history?',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'This action cannot be undone',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Every watched episode of "$title" '
            'will be removed from Watch History, '
            'and its progress will be reset.',
            style: const TextStyle(
              color: _textSecondary,
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
                foregroundColor: _textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Keep progress',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text(
                'Remove all',
                style: TextStyle(fontWeight: FontWeight.w800),
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
          final itemId = int.tryParse((item['show_id'] ?? 0).toString()) ?? 0;

          return itemId == showId;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
          message:
              'Removed "$title" and all its '
              'episodes from history',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
          message: e.toString().replaceAll('Exception: ', ''),
          isError: true,
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
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: _background,
        elevation: 0,
        toolbarHeight: 68,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: _surface,
              foregroundColor: Colors.white,
              side: const BorderSide(color: _border),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            onPressed: () => context.pop(),
          ),
        ),
        titleSpacing: 12,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'In Progress',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Pick up where you left off',
              style: TextStyle(
                color: _textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (_progressItems.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchProgressData,
      color: _primary,
      backgroundColor: _surfaceElevated,
      displacement: 18,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildOverview()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 540,
                mainAxisExtent: 226,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                return _buildProgressCard(_progressItems[index]);
              }, childCount: _progressItems.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    var watchedEpisodes = 0;
    var totalEpisodes = 0;
    var completedShows = 0;

    for (final item in _progressItems) {
      final watched =
          int.tryParse((item['watchedEpisodes'] ?? 0).toString()) ?? 0;

      final total = int.tryParse((item['totalEpisodes'] ?? 0).toString()) ?? 0;

      watchedEpisodes += watched;
      totalEpisodes += total;

      if (total > 0 && watched >= total) {
        completedShows++;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF24172B), Color(0xFF16131A)],
          ),
          border: Border.all(color: const Color(0xFF493153)),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF563064)),
              ),
              child: const Icon(
                Icons.play_circle_outline_rounded,
                color: _primary,
                size: 27,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_progressItems.length} '
                    '${_progressItems.length == 1 ? 'show' : 'shows'}',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$watchedEpisodes of '
                    '$totalEpisodes episodes watched',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (completedShows > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completedShows done',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(dynamic item) {
    final showId = int.tryParse((item['show_id'] ?? 0).toString()) ?? 0;

    final title = (item['title'] ?? 'Untitled').toString();

    final seasonStr = (item['season'] ?? '').toString();

    final watchedEpisodes =
        int.tryParse((item['watchedEpisodes'] ?? 0).toString()) ?? 0;

    final totalEpisodes =
        int.tryParse((item['totalEpisodes'] ?? 1).toString()) ?? 1;

    final safeTotalEpisodes = totalEpisodes > 0 ? totalEpisodes : 1;

    final progress = (watchedEpisodes / safeTotalEpisodes).clamp(0.0, 1.0);

    final isFinished = watchedEpisodes >= safeTotalEpisodes;

    final seasonNumber =
        int.tryParse(
          (item['nextSeasonNumber'] ??
                  seasonStr.replaceAll(RegExp(r'[^0-9]'), ''))
              .toString(),
        ) ??
        1;

    final nextEpisode =
        int.tryParse(
          (item['nextEpisodeNumber'] ?? watchedEpisodes + 1).toString(),
        ) ??
        watchedEpisodes + 1;

    final episodesLeft = safeTotalEpisodes - watchedEpisodes;

    final subtitle = isFinished
        ? 'All episodes completed'
        : 'Next up  •  S$seasonNumber E$nextEpisode';

    final rawBackdrop = (item['backdrop_path'] ?? '').toString();

    final imageUrl = rawBackdrop.isNotEmpty && rawBackdrop != 'null'
        ? rawBackdrop.startsWith('http')
              ? rawBackdrop
              : 'https://image.tmdb.org'
                    '/t/p/w780$rawBackdrop'
        : '';

    final percentage = (progress * 100).round();

    final isMarking = _markingShows.contains(showId);

    final isRemoving = _removingShows.contains(showId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isRemoving
            ? null
            : () {
                context.go('/tv/$showId');
              },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D000000),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        )
                      : _buildPlaceholder(),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.38, 0.72, 1],
                        colors: [
                          Color(0x1A08080B),
                          Color(0x6608080B),
                          Color(0xED0B0A0E),
                          Color(0xFF0B0A0E),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFinished
                              ? Icons.check_circle_rounded
                              : Icons.play_arrow_rounded,
                          color: _primary,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isFinished ? 'COMPLETED' : '$percentage%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: isRemoving
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _danger,
                            ),
                          ),
                        )
                      : _buildOptionsMenu(item),
                ),
                Positioned(
                  left: 15,
                  right: 15,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isFinished ? _primary : _textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.13,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isFinished
                                      ? _primary
                                      : const Color(0xFFE8E4EB),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$watchedEpisodes/'
                            '$safeTotalEpisodes',
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isFinished
                                  ? 'All caught up'
                                  : '$episodesLeft '
                                        '${episodesLeft == 1 ? 'episode' : 'episodes'} left',
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!isFinished)
                            _buildMarkWatchedButton(
                              item: item,
                              isLoading: isMarking,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkWatchedButton({
    required dynamic item,
    required bool isLoading,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading
            ? null
            : () {
                _markNextEpisodeWatched(item);
              },
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF563064)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primary,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_rounded, color: _primary, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Mark watched',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOptionsMenu(dynamic item) {
    return PopupMenuButton<String>(
      tooltip: 'Show options',
      padding: EdgeInsets.zero,
      color: _surfaceElevated,
      surfaceTintColor: _surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
      onSelected: (value) {
        if (value == 'remove') {
          _removeShowFromHistory(item);
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem<String>(
            value: 'remove',
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF321A22),
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: _danger,
                      size: 17,
                    ),
                  ),
                ),
                SizedBox(width: 11),
                Text(
                  'Remove from History',
                  style: TextStyle(
                    color: _danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(color: _primary, strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Loading your progress',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFF321A22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF5D2D3B)),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load progress',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _fetchProgressData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: const Color(0xFF180B1F),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _fetchProgressData,
      color: _primary,
      backgroundColor: _surfaceElevated,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF35203F), Color(0xFF1B151F)],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFF553160)),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.1),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_circle_outline_rounded,
                color: _primary,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nothing in progress',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Start watching a show and your '
            'episode progress will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.55),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_down_alt_rounded, color: _textMuted, size: 15),
              SizedBox(width: 6),
              Text(
                'Pull down to refresh',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF211724),
      alignment: Alignment.center,
      child: const Icon(Icons.tv_rounded, color: Color(0xFF754A82), size: 38),
    );
  }

  SnackBar _buildSnackBar({required String message, bool isError = false}) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? _danger : _primary,
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
      backgroundColor: isError ? const Color(0xFF2A151C) : _surfaceElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: isError ? const Color(0xFF5D2D3B) : _border),
      ),
    );
  }
}

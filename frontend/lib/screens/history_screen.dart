// frontend/lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../widgets/trakt_filter_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _backgroundColor = Color(0xFF08080B);
  static const Color _surfaceColor = Color(0xFF141419);
  static const Color _elevatedSurfaceColor = Color(0xFF1A191F);
  static const Color _primaryPurple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);
  static const Color _favoriteColor = Color(0xFFFF647C);

  String _selectedFilter = 'media';

  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _historyLog = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  String? get _apiMediaType {
    if (_selectedFilter == 'shows') return 'tv';
    if (_selectedFilter == 'movies') return 'movie';
    return null;
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await ApiService.getWatchHistory(_apiMediaType);

      if (mounted) {
        setState(() {
          _historyLog = data;
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

  Future<void> _removeFromHistory(dynamic item) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final int index = _historyLog.indexOf(item);

    setState(() => _historyLog.remove(item));

    try {
      final historyId = item['history_id'] ?? item['id'] ?? 0;
      await ApiService.removeWatchHistory(historyId);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Removed from history',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _surfaceColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _historyLog.insert(index, item));
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to remove: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<dynamic> get _filteredHistory {
    return _historyLog.where((item) {
      final String rawType = (item['type'] ?? item['media_type'] ?? '')
          .toString()
          .toLowerCase();

      final bool isTv =
          rawType == 'show' || rawType == 'tv' || item['subtitle'] != null;

      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'movies' && isTv) return false;

      return true;
    }).toList();
  }

  Map<String, List<dynamic>> get _groupedHistory {
    final Map<String, List<dynamic>> grouped = {};

    for (var item in _filteredHistory) {
      final String rawDate =
          (item['watched_at'] ??
                  item['watchedAt'] ??
                  item['watchedDate'] ??
                  item['watched_date'] ??
                  '')
              .toString();

      String dateLabel = 'Unknown Date';

      if (rawDate.isNotEmpty) {
        try {
          final date = DateTime.parse(rawDate).toLocal();
          dateLabel = DateFormat('MMM dd, yyyy').format(date);
        } catch (_) {
          dateLabel = rawDate;
        }
      }

      if (!grouped.containsKey(dateLabel)) {
        grouped[dateLabel] = [];
      }

      grouped[dateLabel]!.add(item);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupedHistory;
    final groupKeys = groupedData.keys.toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: _HistoryBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildContent(
                      groupedData: groupedData,
                      groupKeys: groupKeys,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: _backgroundColor.withValues(alpha: 0.82),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 650;

          final title = Row(
            children: [
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
                      color: _primaryPurple.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Watch History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
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
                      Text(
                        '${_filteredHistory.length} '
                        '${_filteredHistory.length == 1 ? 'item' : 'items'} watched',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          final filter = TraktFilterBar(
            selectedFilter: _selectedFilter,
            showPeople: false,
            onFilterChanged: (filter) {
              if (_selectedFilter != filter) {
                setState(() => _selectedFilter = filter);
                _fetchHistory();
              }
            },
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filter,
                ),
              ],
            );
          }

          return Row(children: [title, const Spacer(), filter]);
        },
      ),
    );
  }

  Widget _buildContent({
    required Map<String, List<dynamic>> groupedData,
    required List<String> groupKeys,
  }) {
    if (_isLoading) {
      return const _LoadingState(key: ValueKey('loading'));
    }

    if (_errorMessage.isNotEmpty) {
      return _ErrorState(
        key: const ValueKey('error'),
        message: _errorMessage,
        onRetry: _fetchHistory,
      );
    }

    if (_filteredHistory.isEmpty) {
      return _EmptyState(
        key: const ValueKey('empty'),
        selectedFilter: _selectedFilter,
        onRefresh: _fetchHistory,
      );
    }

    return RefreshIndicator(
      key: const ValueKey('history'),
      onRefresh: _fetchHistory,
      color: _lightPurple,
      backgroundColor: _surfaceColor,
      displacement: 24,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        itemCount: groupKeys.length,
        itemBuilder: (context, index) {
          final dateLabel = groupKeys[index];
          final items = groupedData[dateLabel]!;

          return _buildHistoryGroup(
            dateLabel: dateLabel,
            items: items,
            isLast: index == groupKeys.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildHistoryGroup({
    required String dateLabel,
    required List<dynamic> items,
    required bool isLast,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 18, bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateHeader(dateLabel, items.length),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              int columnCount = 1;

              if (constraints.maxWidth >= 1050) {
                columnCount = 3;
              } else if (constraints.maxWidth >= 680) {
                columnCount = 2;
              }

              const double spacing = 16;
              final double cardWidth =
                  (constraints.maxWidth - ((columnCount - 1) * spacing)) /
                  columnCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: items
                    .map(
                      (item) => _buildHistoryCard(item, dateLabel, cardWidth),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String dateLabel, int itemCount) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _primaryPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _primaryPurple.withValues(alpha: 0.22)),
          ),
          child: const Icon(
            Icons.calendar_today_rounded,
            color: _lightPurple,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          dateLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$itemCount',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(dynamic item, String dateLabel, double width) {
    return Consumer<WatchlistProvider>(
      builder: (context, watchlistProvider, child) {
        final rawId = item['movie_id'] ?? item['id'] ?? 0;
        final int id = int.tryParse(rawId.toString()) ?? 0;
        final String title = item['movie_title'] ?? item['title'] ?? 'Untitled';
        final String subtitle = (item['subtitle'] ?? '').toString();

        final String rawType = (item['type'] ?? item['media_type'] ?? '')
            .toString()
            .toLowerCase();

        final bool isShow =
            rawType == 'show' || rawType == 'tv' || item['subtitle'] != null;

        final String parsedMediaType = isShow ? 'tv' : 'movie';

        final String imagePath =
            (item['poster'] ??
                    item['poster_path'] ??
                    item['backdrop'] ??
                    item['backdrop_path'] ??
                    '')
                .toString();

        final String imageUrl = imagePath.isNotEmpty
            ? (imagePath.startsWith('http')
                  ? imagePath
                  : 'https://image.tmdb.org/t/p/w500$imagePath')
            : '';

        final String watchedTime = (item['watchedTime'] ?? '12:00 AM')
            .toString();

        final String? currentStatus = watchlistProvider.getMediaStatus(
          id,
          mediaType: parsedMediaType,
        );

        final bool isFavorite = currentStatus == 'favorite';

        return SizedBox(
          width: width,
          height: 178,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isShow) {
                  context.go('/tv/$id');
                } else {
                  context.go('/movie/$id');
                }
              },
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                decoration: BoxDecoration(
                  color: _elevatedSurfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.075),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildCardBackdrop(imageUrl)),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _elevatedSurfaceColor.withValues(alpha: 0.04),
                                _elevatedSurfaceColor.withValues(alpha: 0.76),
                                _elevatedSurfaceColor,
                              ],
                              stops: const [0.05, 0.49, 0.72],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 118,
                        child: _buildPoster(imageUrl),
                      ),
                      Positioned(
                        left: 104,
                        top: 0,
                        bottom: 0,
                        width: 30,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _elevatedSurfaceColor,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 132,
                        right: 42,
                        top: 18,
                        bottom: 16,
                        child: _buildCardContent(
                          title: title,
                          subtitle: subtitle,
                          isShow: isShow,
                          dateLabel: dateLabel,
                          watchedTime: watchedTime,
                        ),
                      ),
                      Positioned(right: 4, top: 4, child: _buildMoreMenu(item)),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _buildFavoriteButton(
                          id: id,
                          title: title,
                          imagePath: imagePath,
                          parsedMediaType: parsedMediaType,
                          isFavorite: isFavorite,
                          watchlistProvider: watchlistProvider,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardBackdrop(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const ColoredBox(color: _surfaceColor);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      color: Colors.black.withValues(alpha: 0.46),
      colorBlendMode: BlendMode.darken,
      errorBuilder: (_, _, _) {
        return const ColoredBox(color: _surfaceColor);
      },
    );
  }

  Widget _buildPoster(String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildPosterPlaceholder(),
          )
        else
          _buildPosterPlaceholder(),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: _surfaceColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_filter_outlined,
        color: Colors.white.withValues(alpha: 0.18),
        size: 38,
      ),
    );
  }

  Widget _buildCardContent({
    required String title,
    required String subtitle,
    required bool isShow,
    required String dateLabel,
    required String watchedTime,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _primaryPurple.withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                isShow ? 'TV SHOW' : 'MOVIE',
                style: const TextStyle(
                  color: _lightPurple,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _lightPurple,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const Spacer(),
        Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: _lightPurple.withValues(alpha: 0.85),
              size: 13,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '$dateLabel · $watchedTime',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.43),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoreMenu(dynamic item) {
    return PopupMenuButton<String>(
      tooltip: 'History options',
      icon: Icon(
        Icons.more_horiz_rounded,
        color: Colors.white.withValues(alpha: 0.78),
        size: 20,
      ),
      color: _surfaceColor,
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      onSelected: (value) {
        if (value == 'remove') {
          _removeFromHistory(item);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF6B7E),
                size: 19,
              ),
              SizedBox(width: 10),
              Text(
                'Remove from history',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton({
    required int id,
    required String title,
    required String imagePath,
    required String parsedMediaType,
    required bool isFavorite,
    required WatchlistProvider watchlistProvider,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          if (isFavorite) {
            await watchlistProvider.removeFromWatchlist(
              id,
              mediaType: parsedMediaType,
            );

            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Removed from Favorites',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: _surfaceColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            await watchlistProvider.addToWatchlist(
              movieId: id,
              movieTitle: title,
              posterPath: imagePath.isNotEmpty ? imagePath : null,
              status: 'favorite',
              mediaType: parsedMediaType,
            );

            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Added to Favorites',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: _surfaceColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isFavorite
                ? _favoriteColor.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isFavorite
                  ? _favoriteColor.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite
                ? _favoriteColor
                : Colors.white.withValues(alpha: 0.7),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _HistoryBackground extends StatelessWidget {
  const _HistoryBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFF08080B), child: SizedBox.expand()),
          Positioned(
            top: -180,
            right: -160,
            child: Container(
              width: 420,
              height: 420,
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
            bottom: -220,
            left: -180,
            child: Container(
              width: 460,
              height: 460,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8431D9).withValues(alpha: 0.08),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 27,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load history',
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
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB143EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try again',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.selectedFilter,
    required this.onRefresh,
  });

  final String selectedFilter;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFFCA66FF),
      backgroundColor: const Color(0xFF141419),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB143EB).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFB143EB).withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.history_toggle_off_rounded,
                      color: Color(0xFFCA66FF),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nothing watched yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No $selectedFilter recorded in your history. '
                    'Titles you watch will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

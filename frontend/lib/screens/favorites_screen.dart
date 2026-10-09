import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/watchlist_item.dart';
import '../providers/watchlist_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const Color _background = Color(0xFF08080B);

  static const Color _surface = Color(0xFF141318);

  static const Color _surfaceElevated = Color(0xFF1B1820);

  static const Color _border = Color(0xFF302B36);

  static const Color _primary = Color(0xFFCA66FF);

  static const Color _primarySoft = Color(0xFF2D1937);

  static const Color _textPrimary = Color(0xFFF7F4F8);

  static const Color _textSecondary = Color(0xFFA39DA9);

  static const Color _textMuted = Color(0xFF77717D);

  static const Color _danger = Color(0xFFFF647C);

  String _activeFilter = 'media';

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    List<WatchlistItem> favorites = watchlistProvider.favoriteItems;

    // Apply the selected filter.
    if (_activeFilter == 'movies') {
      favorites = favorites
          .where((item) => item.mediaType.toLowerCase() == 'movie')
          .toList();
    } else if (_activeFilter == 'shows') {
      favorites = favorites
          .where(
            (item) =>
                item.mediaType.toLowerCase() == 'tv' ||
                item.mediaType.toLowerCase() == 'show',
          )
          .toList();
    }

    // Group favorites by the year they were added.
    final Map<String, List<WatchlistItem>> groupedFavorites = {};

    for (final item in favorites) {
      String year = 'Unknown Year';

      try {
        final dynamic dItem = item;

        final addedDate = dItem.addedAt ?? dItem.created_at;

        if (addedDate != null) {
          final parsedDate = DateTime.parse(addedDate.toString());

          year = parsedDate.year.toString();
        } else {
          year = DateTime.now().year.toString();
        }
      } catch (_) {
        year = DateTime.now().year.toString();
      }

      if (!groupedFavorites.containsKey(year)) {
        groupedFavorites[year] = [];
      }

      groupedFavorites[year]!.add(item);
    }

    // Sort years from newest to oldest.
    final sortedYears = groupedFavorites.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown Year') {
          return 1;
        }

        if (b == 'Unknown Year') {
          return -1;
        }

        return b.compareTo(a);
      });

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
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/profile');
              }
            },
          ),
        ),
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Favorites',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _getFilterSubtitle(favorites.length),
              style: const TextStyle(
                color: _textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child:
            watchlistProvider.isLoading &&
                watchlistProvider.favoriteItems.isEmpty
            ? _buildLoadingState()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(
                      totalFavorites: watchlistProvider.favoriteItems.length,
                      filteredCount: favorites.length,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildFilters()),
                  if (favorites.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    ..._buildYearSections(sortedYears, groupedFavorites),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }

  String _getFilterSubtitle(int count) {
    final itemLabel = count == 1 ? 'favorite' : 'favorites';

    if (_activeFilter == 'movies') {
      return '$count movie $itemLabel';
    }

    if (_activeFilter == 'shows') {
      return '$count show $itemLabel';
    }

    return '$count $itemLabel';
  }

  Widget _buildHeader({
    required int totalFavorites,
    required int filteredCount,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF291831), Color(0xFF171319)],
          ),
          border: Border.all(color: const Color(0xFF4B3056)),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFF583266)),
              ),
              child: const Icon(
                Icons.favorite_rounded,
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
                    '$totalFavorites '
                    '${totalFavorites == 1 ? 'favorite' : 'favorites'}',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The stories worth keeping close',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (_activeFilter != 'media')
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
                  '$filteredCount shown',
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildFilterPill('media', 'All', Icons.dashboard_rounded),
            ),
            Expanded(
              child: _buildFilterPill('shows', 'Shows', Icons.tv_rounded),
            ),
            Expanded(
              child: _buildFilterPill(
                'movies',
                'Movies',
                Icons.movie_creation_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String filterValue, String label, IconData icon) {
    final isActive = _activeFilter == filterValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _activeFilter = filterValue;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: const Color(0xFF563064))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isActive ? _primary : _textMuted),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? _textPrimary : _textSecondary,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildYearSections(
    List<String> sortedYears,
    Map<String, List<WatchlistItem>> groupedFavorites,
  ) {
    final slivers = <Widget>[];

    for (final year in sortedYears) {
      final yearItems = groupedFavorites[year] ?? [];

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 13),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  year,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    '${yearItems.length}',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Divider(color: _border, height: 1)),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 430,
              mainAxisExtent: 176,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return _buildFavoriteCard(context, yearItems[index]);
            }, childCount: yearItems.length),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildFavoriteCard(BuildContext context, WatchlistItem item) {
    final rawPoster = item.posterPath?.toString() ?? '';

    final posterUrl = rawPoster.isNotEmpty
        ? rawPoster.startsWith('http')
              ? rawPoster
              : 'https://image.tmdb.org'
                    '/t/p/w500$rawPoster'
        : '';

    final title = item.movieTitle;

    final mediaType = item.mediaType.isNotEmpty
        ? item.mediaType.toLowerCase()
        : 'movie';

    final id = item.movieId;
    final dynamic dItem = item;

    String releaseYearStr = '';

    try {
      final date =
          dItem.releaseDate ?? dItem.release_date ?? dItem.first_air_date;

      if (date != null && date.toString().length >= 4) {
        releaseYearStr = date.toString().substring(0, 4);
      }
    } catch (_) {}

    String detailStr = '';

    try {
      if (mediaType == 'movie' || mediaType == 'media') {
        if (dItem.runtime != null && dItem.runtime > 0) {
          final totalMinutes = dItem.runtime as int;

          final hours = totalMinutes ~/ 60;
          final minutes = totalMinutes % 60;

          detailStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
        }
      } else {
        final episodes =
            dItem.totalEpisodes ?? dItem.number_of_episodes ?? dItem.episodes;

        if (episodes != null && episodes > 0) {
          detailStr = '$episodes eps.';
        }
      }
    } catch (_) {}

    String ratingStr = '';

    try {
      final vote = dItem.voteAverage ?? dItem.vote_average;

      if (vote != null && vote > 0) {
        ratingStr = '${(vote * 10).toInt()}%';
      }
    } catch (_) {}

    String genre = '';

    try {
      if (dItem.genre != null) {
        genre = dItem.genre;
      }
    } catch (_) {}

    String certification = '';

    try {
      if (dItem.certification != null) {
        certification = dItem.certification;
      }
    } catch (_) {}

    final isTv = mediaType == 'tv' || mediaType == 'show';

    final typeLabel = isTv ? 'TV SHOW' : 'MOVIE';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.go('/$mediaType/$id');
          },
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3D000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Row(
                children: [
                  SizedBox(
                    width: 116,
                    height: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        posterUrl.isNotEmpty
                            ? Image.network(
                                posterUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildPosterPlaceholder();
                                },
                              )
                            : _buildPosterPlaceholder(),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xB308080B)],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 9,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              typeLabel,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 9,
                          bottom: 9,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 7, 13),
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
                                    color: _textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    letterSpacing: -0.15,
                                  ),
                                ),
                              ),
                              _buildOptionsMenu(context, item),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            genre.isNotEmpty
                                ? genre
                                : isTv
                                ? 'Television'
                                : 'Film',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: [
                              if (releaseYearStr.isNotEmpty)
                                _buildMetadataChip(
                                  Icons.calendar_today_rounded,
                                  releaseYearStr,
                                ),
                              if (detailStr.isNotEmpty)
                                _buildMetadataChip(
                                  isTv
                                      ? Icons.video_library_outlined
                                      : Icons.schedule_rounded,
                                  detailStr,
                                ),
                              if (certification.isNotEmpty)
                                _buildMetadataChip(
                                  Icons.verified_user_outlined,
                                  certification,
                                ),
                            ],
                          ),
                          if (ratingStr.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFB84D),
                                  size: 16,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  ratingStr,
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'audience score',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildMetadataChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _textMuted, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsMenu(BuildContext context, WatchlistItem item) {
    return PopupMenuButton<String>(
      tooltip: 'Favorite options',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 190),
      color: _surfaceElevated,
      surfaceTintColor: _surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      icon: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: _border),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: _textSecondary,
          size: 17,
        ),
      ),
      onSelected: (value) {
        if (value == 'remove') {
          Provider.of<WatchlistProvider>(
            context,
            listen: false,
          ).removeFromWatchlist(item.movieId, mediaType: item.mediaType);
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
                      Icons.heart_broken_rounded,
                      color: _danger,
                      size: 17,
                    ),
                  ),
                ),
                SizedBox(width: 11),
                Text(
                  'Remove Favorite',
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

  Widget _buildPosterPlaceholder() {
    return Container(
      color: const Color(0xFF211724),
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_filter_rounded,
        color: Color(0xFF754A82),
        size: 34,
      ),
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
            'Loading your favorites',
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

  Widget _buildEmptyState() {
    final isFiltered = _activeFilter != 'media';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
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
              child: Icon(
                isFiltered
                    ? Icons.filter_alt_off_rounded
                    : Icons.favorite_border_rounded,
                color: _primary,
                size: 37,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'No matching favorites' : 'No favorites yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              isFiltered
                  ? 'Try another filter to see '
                        'more of your collection.'
                  : 'Movies and shows you favorite '
                        'will be collected here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _activeFilter = 'media';
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  backgroundColor: _primarySoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF563064)),
                  ),
                ),
                icon: const Icon(Icons.dashboard_rounded, size: 16),
                label: const Text(
                  'Show all favorites',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

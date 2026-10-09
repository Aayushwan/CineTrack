import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../widgets/trakt_filter_bar.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() =>
      _WatchlistScreenState();
}

class _WatchlistScreenState
    extends State<WatchlistScreen> {
  bool _isLoading = true;
  bool _isLogging = false;

  List<dynamic> _allWatchlistItems = [];
  List<dynamic> _filteredItems = [];

  String _selectedFilter = 'media';

  @override
  void initState() {
    super.initState();

    _fetchWatchlist();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Provider.of<WatchlistProvider>(
        context,
        listen: false,
      ).fetchCustomLists();
    });
  }

  Future<void> _fetchWatchlist() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Request only records whose status is "watchlist".
      // Favorites must not appear on this screen.
      final items = await ApiService.getWatchlist(
        status: 'watchlist',
      );

      if (!mounted) return;

      setState(() {
        _allWatchlistItems = items;
        _applyFilter();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    _filteredItems =
        _allWatchlistItems.where((item) {
      final status = (
        item['status'] ?? 'watchlist'
      ).toString().trim().toLowerCase();

      // This is a defensive check in case the API ignores or
      // does not support the status query parameter.
      if (status != 'watchlist') {
        return false;
      }

      final mediaType = (
        item['media_type'] ??
            item['type'] ??
            'movie'
      ).toString().trim().toLowerCase();

      final isTv =
          mediaType == 'tv' ||
          mediaType == 'show';

      if (_selectedFilter == 'shows' && !isTv) {
        return false;
      }

      if (_selectedFilter == 'movies' && isTv) {
        return false;
      }

      return true;
    }).toList();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  void _removeLocalItem(
    int movieId,
    String mediaType,
  ) {
    if (!mounted) return;

    final normalizedTargetType =
        mediaType.trim().toLowerCase();

    final targetIsTv =
        normalizedTargetType == 'tv' ||
        normalizedTargetType == 'show';

    setState(() {
      _allWatchlistItems.removeWhere((item) {
        final itemId = int.tryParse(
              (item['movie_id'] ?? item['id'] ?? 0)
                  .toString(),
            ) ??
            0;

        final normalizedItemType = (
          item['media_type'] ??
              item['type'] ??
              'movie'
        ).toString().trim().toLowerCase();

        final itemIsTv =
            normalizedItemType == 'tv' ||
            normalizedItemType == 'show';

        return itemId == movieId &&
            itemIsTv == targetIsTv;
      });

      _applyFilter();
    });
  }

  Future<void> _markAsWatched(
    dynamic item,
    String mediaType,
    String option,
  ) async {
    Navigator.pop(context);

    final scaffoldMessenger =
        ScaffoldMessenger.of(context);

    if (_isLogging) return;

    setState(() {
      _isLogging = true;
    });

    final title = (
      item['title'] ??
          item['movie_title'] ??
          item['name'] ??
          'Untitled'
    ).toString();

    final poster = item['poster_path'];

    final releaseDateStr = (
      item['release_year'] ??
          item['release_date'] ??
          item['first_air_date'] ??
          ''
    ).toString();

    DateTime? watchedAtDate;
    final now = DateTime.now();

    if (option == 'Just now') {
      watchedAtDate = now.toUtc();
    } else if (option == 'Release date') {
      if (releaseDateStr.isNotEmpty &&
          releaseDateStr != 'null') {
        try {
          if (releaseDateStr.length == 4) {
            watchedAtDate = DateTime(
              int.parse(releaseDateStr),
              1,
              1,
            ).toUtc();
          } else {
            watchedAtDate =
                DateTime.parse(releaseDateStr)
                    .toUtc();
          }
        } catch (_) {
          watchedAtDate = now.toUtc();
        }
      } else {
        watchedAtDate = now.toUtc();
      }
    } else if (option == 'Other date') {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(1900),
        lastDate: now,
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme:
                  const ColorScheme.dark(
                primary: Color(0xFFA855F7),
                onPrimary: Colors.white,
                surface: Color(0xFF131316),
                onSurface: Colors.white,
              ),
              dialogTheme:
                  const DialogThemeData(
                backgroundColor:
                    Color(0xFF131316),
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

      watchedAtDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        now.hour,
        now.minute,
        now.second,
      ).toUtc();
    }

    try {
      final movieId = int.tryParse(
            (item['movie_id'] ??
                    item['id'] ??
                    0)
                .toString(),
          ) ??
          0;

      await ApiService.logWatchHistory(
        movieId: movieId,
        mediaType: mediaType,
        title: title,
        posterPath: poster,
        runtimeMinutes: 120,
        userRating: 0.0,
        watchedAt:
            watchedAtDate?.toIso8601String(),
      );

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Marked "$title" as Watched!',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor:
              const Color(0xFF131316),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to log watch history: $e',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
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

  void _showMarkWatchedMenu(
    dynamic item,
    String mediaType,
  ) {
    final title = (
      item['title'] ??
          item['movie_title'] ??
          item['name'] ??
          'Untitled'
    ).toString();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.only(
            bottom: 24,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ],
                ),
              ),
              Divider(
                color: Colors.white.withValues(
                  alpha: 0.1,
                ),
                height: 1,
              ),
              _buildMenuOption(
                Icons.check_rounded,
                'Just now',
                () => _markAsWatched(
                  item,
                  mediaType,
                  'Just now',
                ),
              ),
              _buildMenuOption(
                Icons.calendar_today_rounded,
                'Release date',
                () => _markAsWatched(
                  item,
                  mediaType,
                  'Release date',
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Divider(
                  color: Colors.white.withValues(
                    alpha: 0.1,
                  ),
                  height: 1,
                ),
              ),
              _buildMenuOption(
                Icons.edit_calendar_rounded,
                'Other date',
                () => _markAsWatched(
                  item,
                  mediaType,
                  'Other date',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptions(
    WatchlistProvider provider,
    dynamic item,
    String mediaType,
  ) {
    final title = (
      item['title'] ??
          item['movie_title'] ??
          item['name'] ??
          'Untitled'
    ).toString();

    final posterPath =
        item['poster_path']?.toString();

    final id = int.tryParse(
          (item['movie_id'] ??
                  item['id'] ??
                  0)
              .toString(),
        ) ??
        0;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.only(
            bottom: 24,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(
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
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ],
                ),
              ),
              Divider(
                color: Colors.white.withValues(
                  alpha: 0.1,
                ),
                height: 1,
              ),
              if (provider.customLists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No custom lists found. '
                    'Create one in the Lists tab!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                )
              else
                ...provider.customLists.map(
                  (listData) {
                    final listId = int.tryParse(
                          (listData['id'] ?? 0)
                              .toString(),
                        ) ??
                        0;

                    final listTitle = (
                      listData['title'] ??
                          listData['name'] ??
                          'Untitled'
                    ).toString();

                    return _buildMenuOption(
                      Icons.playlist_add_rounded,
                      listTitle,
                      () {
                        provider.addMediaToList(
                          listId,
                          id,
                          posterPath,
                          title: title,
                          mediaType: mediaType,
                        );

                        Navigator.pop(sheetContext);

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added "$title" to '
                              '"$listTitle"',
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor:
                                const Color(
                              0xFF131316,
                            ),
                            behavior:
                                SnackBarBehavior
                                    .floating,
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlistProvider =
        Provider.of<WatchlistProvider>(context);

    return Scaffold(
      backgroundColor:
          const Color(0xFF09090B),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Watchlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TraktFilterBar(
                    selectedFilter:
                        _selectedFilter,
                    showPeople: false,
                    onFilterChanged:
                        _onFilterChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            Color(0xFFA855F7),
                      ),
                    )
                  : _filteredItems.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(
                            0xFFA855F7,
                          ),
                          backgroundColor:
                              const Color(
                            0xFF131316,
                          ),
                          onRefresh:
                              _fetchWatchlist,
                          child:
                              GridView.builder(
                            padding:
                                const EdgeInsets
                                    .all(16),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent:
                                  180,
                              childAspectRatio:
                                  0.58,
                              crossAxisSpacing:
                                  14,
                              mainAxisSpacing:
                                  16,
                            ),
                            itemCount:
                                _filteredItems
                                    .length,
                            itemBuilder:
                                (context, index) {
                              final item =
                                  _filteredItems[
                                      index];

                              final mediaType =
                                  (
                                item[
                                        'media_type'] ??
                                    item['type'] ??
                                    'movie'
                              )
                                      .toString()
                                      .trim()
                                      .toLowerCase();

                              final normalizedType =
                                  mediaType ==
                                              'tv' ||
                                          mediaType ==
                                              'show'
                                      ? 'tv'
                                      : 'movie';

                              return _WatchlistGridCard(
                                item: Map<String,
                                        dynamic>.from(
                                    item),
                                provider:
                                    watchlistProvider,
                                mediaTypeStr:
                                    normalizedType,
                                onRemove: (id) {
                                  _removeLocalItem(
                                    id,
                                    normalizedType,
                                  );
                                },
                                onTrack: () {
                                  _showMarkWatchedMenu(
                                    item,
                                    normalizedType,
                                  );
                                },
                                onManage: () {
                                  _showMoreOptions(
                                    watchlistProvider,
                                    item,
                                    normalizedType,
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String filterText = 'items';

    if (_selectedFilter == 'shows') {
      filterText = 'shows';
    }

    if (_selectedFilter == 'movies') {
      filterText = 'movies';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bookmark_outline_rounded,
              color: Colors.white24,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Watchlist is Empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'media'
                  ? 'Items you bookmark from '
                      'Home or Discover will '
                      'show up here.'
                  : 'No $filterText found '
                      'matching your active '
                      'criteria.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistGridCard
    extends StatelessWidget {
  final Map<String, dynamic> item;
  final WatchlistProvider provider;
  final String mediaTypeStr;
  final ValueChanged<int> onRemove;
  final VoidCallback onTrack;
  final VoidCallback onManage;

  const _WatchlistGridCard({
    required this.item,
    required this.provider,
    required this.mediaTypeStr,
    required this.onRemove,
    required this.onTrack,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(
          (item['movie_id'] ??
                  item['id'] ??
                  0)
              .toString(),
        ) ??
        0;

    final title = (
      item['movie_title'] ??
          item['title'] ??
          item['name'] ??
          'Untitled'
    ).toString();

    final normalizedMediaType =
        mediaTypeStr.trim().toLowerCase();

    final isTv =
        normalizedMediaType == 'tv' ||
        normalizedMediaType == 'show';

    final imagePath =
        (item['poster_path'] ?? '').toString();

    final imageUrl = imagePath.isNotEmpty
        ? imagePath.startsWith('http')
            ? imagePath
            : 'https://image.tmdb.org'
                '/t/p/w500$imagePath'
        : '';

    final ratingVal = double.tryParse(
          (item['vote_average'] ??
                  item['rating'] ??
                  0.0)
              .toString(),
        ) ??
        0.0;

    final ratingStr = ratingVal > 0
        ? ratingVal.toStringAsFixed(1)
        : '0.0';

    return GestureDetector(
      onTap: () {
        if (isTv) {
          context.go('/tv/$id');
        } else {
          context.go('/movie/$id');
        }
      },
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: const Color(
                      0xFF1E1E24,
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const Center(
                                child: Icon(
                                  Icons.movie_rounded,
                                  color:
                                      Colors.white24,
                                  size: 40,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.movie_rounded,
                              color: Colors.white24,
                              size: 40,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black
                          .withValues(alpha: 0.7),
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
                    child: Text(
                      isTv ? 'TV' : 'MOVIE',
                      style: const TextStyle(
                        color:
                            Color(0xFFA855F7),
                        fontSize: 9,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black
                          .withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child:
                        PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      color:
                          const Color(0xFF131316),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          8,
                        ),
                        side: const BorderSide(
                          color: Colors.white10,
                        ),
                      ),
                      onSelected: (value) async {
                        if (value ==
                            'watchlist') {
                          final providerStatus =
                              provider
                                  .getMediaStatus(
                                    id,
                                    mediaType:
                                        normalizedMediaType,
                                  )
                                  ?.trim()
                                  .toLowerCase();

                          final itemStatus = (
                            item['status'] ??
                                'watchlist'
                          )
                              .toString()
                              .trim()
                              .toLowerCase();

                          final isWatchlist =
                              itemStatus ==
                                      'watchlist' ||
                                  providerStatus ==
                                      'watchlist';

                          final messenger =
                              ScaffoldMessenger.of(
                            context,
                          );

                          if (isWatchlist) {
                            final success =
                                await provider
                                    .removeFromWatchlist(
                              id,
                              mediaType:
                                  normalizedMediaType,
                            );

                            if (success) {
                              onRemove(id);

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Removed from '
                                    'Watchlist',
                                    style: TextStyle(
                                      color:
                                          Colors.white,
                                    ),
                                  ),
                                  backgroundColor:
                                      Color(
                                    0xFF131316,
                                  ),
                                  behavior:
                                      SnackBarBehavior
                                          .floating,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.errorMessage ??
                                        'Failed to '
                                            'remove item',
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                    ),
                                  ),
                                  backgroundColor:
                                      Colors.redAccent,
                                  behavior:
                                      SnackBarBehavior
                                          .floating,
                                ),
                              );
                            }
                          }
                        } else if (value ==
                            'track') {
                          onTrack();
                        } else if (value ==
                            'manage') {
                          onManage();
                        }
                      },
                      itemBuilder: (context) {
                        // Every card on this screen came from the
                        // status=watchlist endpoint and passed the
                        // local status check, so it is removable.
                        return const [
                          PopupMenuItem<String>(
                            value: 'watchlist',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .bookmark_added_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Remove from Watchlist',
                                  style: TextStyle(
                                    color:
                                        Colors.white,
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
                                Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Track',
                                  style: TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'manage',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .list_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Manage List',
                                  style: TextStyle(
                                    color:
                                        Colors.white,
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
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          if (ratingVal > 0)
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB800),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  ratingStr,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
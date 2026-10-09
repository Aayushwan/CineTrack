// frontend/lib/screens/watchlist_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../widgets/trakt_filter_bar.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  static const Color _background = Color(0xFF08080B);
  static const Color _surface = Color(0xFF141419);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

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

      Provider.of<WatchlistProvider>(context, listen: false).fetchCustomLists();
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
      final items = await ApiService.getWatchlist(status: 'watchlist');

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
    _filteredItems = _allWatchlistItems.where((item) {
      final status = (item['status'] ?? 'watchlist')
          .toString()
          .trim()
          .toLowerCase();

      // Defensive check in case the API ignores or does not support
      // the status query parameter.
      if (status != 'watchlist') {
        return false;
      }

      final mediaType = (item['media_type'] ?? item['type'] ?? 'movie')
          .toString()
          .trim()
          .toLowerCase();

      final isTv = mediaType == 'tv' || mediaType == 'show';

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

  void _removeLocalItem(int movieId, String mediaType) {
    if (!mounted) return;

    final normalizedTargetType = mediaType.trim().toLowerCase();

    final targetIsTv =
        normalizedTargetType == 'tv' || normalizedTargetType == 'show';

    setState(() {
      _allWatchlistItems.removeWhere((item) {
        final itemId =
            int.tryParse((item['movie_id'] ?? item['id'] ?? 0).toString()) ?? 0;

        final normalizedItemType =
            (item['media_type'] ?? item['type'] ?? 'movie')
                .toString()
                .trim()
                .toLowerCase();

        final itemIsTv =
            normalizedItemType == 'tv' || normalizedItemType == 'show';

        return itemId == movieId && itemIsTv == targetIsTv;
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

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_isLogging) return;

    setState(() {
      _isLogging = true;
    });

    final title =
        (item['title'] ?? item['movie_title'] ?? item['name'] ?? 'Untitled')
            .toString();

    final poster = item['poster_path'];

    final releaseDateStr =
        (item['release_year'] ??
                item['release_date'] ??
                item['first_air_date'] ??
                '')
            .toString();

    DateTime? watchedAtDate;
    final now = DateTime.now();

    if (option == 'Just now') {
      watchedAtDate = now.toUtc();
    } else if (option == 'Release date') {
      if (releaseDateStr.isNotEmpty && releaseDateStr != 'null') {
        try {
          if (releaseDateStr.length == 4) {
            watchedAtDate = DateTime(int.parse(releaseDateStr), 1, 1).toUtc();
          } else {
            watchedAtDate = DateTime.parse(releaseDateStr).toUtc();
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
              colorScheme: const ColorScheme.dark(
                primary: _purple,
                onPrimary: Colors.white,
                surface: _surface,
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(backgroundColor: _surface),
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
      final movieId =
          int.tryParse((item['movie_id'] ?? item['id'] ?? 0).toString()) ?? 0;

      await ApiService.logWatchHistory(
        movieId: movieId,
        mediaType: mediaType,
        title: title,
        posterPath: poster,
        runtimeMinutes: 120,
        userRating: 0.0,
        watchedAt: watchedAtDate?.toIso8601String(),
      );

      scaffoldMessenger.showSnackBar(
        _buildSnackBar('Marked "$title" as watched'),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        _buildSnackBar('Failed to log watch history: $e', isError: true),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }

  void _showMarkWatchedMenu(dynamic item, String mediaType) {
    final title =
        (item['title'] ?? item['movie_title'] ?? item['name'] ?? 'Untitled')
            .toString();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
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
                  title: 'Mark as watched',
                  subtitle: title,
                ),
                _buildSheetDivider(),
                const SizedBox(height: 8),
                _buildMenuOption(
                  icon: Icons.bolt_rounded,
                  label: 'Just now',
                  description: 'Use the current date and time',
                  onTap: () {
                    _markAsWatched(item, mediaType, 'Just now');
                  },
                ),
                _buildMenuOption(
                  icon: Icons.calendar_today_rounded,
                  label: 'Release date',
                  description: 'Use the original release or air date',
                  onTap: () {
                    _markAsWatched(item, mediaType, 'Release date');
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.07),
                    height: 1,
                  ),
                ),
                _buildMenuOption(
                  icon: Icons.edit_calendar_rounded,
                  label: 'Other date',
                  description: 'Choose a custom date',
                  onTap: () {
                    _markAsWatched(item, mediaType, 'Other date');
                  },
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
    dynamic item,
    String mediaType,
  ) {
    final title =
        (item['title'] ?? item['movie_title'] ?? item['name'] ?? 'Untitled')
            .toString();

    final posterPath = item['poster_path']?.toString();

    final id =
        int.tryParse((item['movie_id'] ?? item['id'] ?? 0).toString()) ?? 0;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
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
                  subtitle: title,
                ),
                _buildSheetDivider(),
                if (provider.customLists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                    child: Column(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _purple.withValues(alpha: 0.17),
                            ),
                          ),
                          child: const Icon(
                            Icons.playlist_add_rounded,
                            color: _lightPurple,
                            size: 28,
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
                        const SizedBox(height: 7),
                        Text(
                          'Create your first collection in the Lists tab.',
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
                          icon: Icons.playlist_add_rounded,
                          label: listTitle,
                          description: 'Add this title to $listTitle',
                          onTap: () {
                            provider.addMediaToList(
                              listId,
                              id,
                              posterPath,
                              title: title,
                              mediaType: mediaType,
                            );

                            Navigator.pop(sheetContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              _buildSnackBar('Added "$title" to "$listTitle"'),
                            );
                          },
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
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildSheetHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
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
                  subtitle,
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

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
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
                  width: 40,
                  height: 40,
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
      backgroundColor: isError ? const Color(0xFF241418) : _surface,
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

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const Positioned.fill(child: _WatchlistBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildContent(watchlistProvider),
                  ),
                ),
              ],
            ),
          ),
          if (_isLogging)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.06)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 20, 18),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.84),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          final titleSection = Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 2),
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
                      color: _purple.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bookmarks_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Watchlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.05,
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
                        '${_filteredItems.length} '
                        '${_filteredItems.length == 1 ? 'title' : 'titles'} saved',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          final filterBar = TraktFilterBar(
            selectedFilter: _selectedFilter,
            showPeople: false,
            onFilterChanged: _onFilterChanged,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: filterBar,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleSection),
              filterBar,
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(WatchlistProvider watchlistProvider) {
    if (_isLoading) {
      return const _WatchlistLoadingState(key: ValueKey('loading'));
    }

    if (_filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      key: const ValueKey('watchlist-grid'),
      color: _lightPurple,
      backgroundColor: _surface,
      displacement: 24,
      onRefresh: _fetchWatchlist,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxExtent = 190;
          double aspectRatio = 0.56;

          if (constraints.maxWidth >= 1100) {
            maxExtent = 220;
            aspectRatio = 0.61;
          } else if (constraints.maxWidth >= 700) {
            maxExtent = 205;
            aspectRatio = 0.59;
          }

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 42),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxExtent,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 20,
            ),
            itemCount: _filteredItems.length,
            itemBuilder: (context, index) {
              final item = _filteredItems[index];

              final mediaType = (item['media_type'] ?? item['type'] ?? 'movie')
                  .toString()
                  .trim()
                  .toLowerCase();

              final normalizedType = mediaType == 'tv' || mediaType == 'show'
                  ? 'tv'
                  : 'movie';

              return _WatchlistGridCard(
                item: Map<String, dynamic>.from(item),
                provider: watchlistProvider,
                mediaTypeStr: normalizedType,
                onRemove: (id) {
                  _removeLocalItem(id, normalizedType);
                },
                onTrack: () {
                  _showMarkWatchedMenu(item, normalizedType);
                },
                onManage: () {
                  _showMoreOptions(watchlistProvider, item, normalizedType);
                },
              );
            },
          );
        },
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

    return RefreshIndicator(
      key: const ValueKey('empty'),
      color: _lightPurple,
      backgroundColor: _surface,
      onRefresh: _fetchWatchlist,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
              decoration: BoxDecoration(
                color: _surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.065),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
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
                      border: Border.all(color: _purple.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.bookmark_add_outlined,
                      color: _lightPurple,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your watchlist is empty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _selectedFilter == 'media'
                        ? 'Titles you save from Home or Discover will appear here.'
                        : 'No $filterText match your active filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.44),
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swipe_down_alt_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 16,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _WatchlistBackground extends StatelessWidget {
  const _WatchlistBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFF08080B), child: SizedBox.expand()),
          Positioned(
            top: -190,
            right: -170,
            child: Container(
              width: 430,
              height: 430,
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
            bottom: -240,
            left: -190,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8431D9).withValues(alpha: 0.07),
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

class _WatchlistLoadingState extends StatelessWidget {
  const _WatchlistLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
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

class _WatchlistGridCard extends StatelessWidget {
  static const Color _surface = Color(0xFF17151B);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

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
    final id =
        int.tryParse((item['movie_id'] ?? item['id'] ?? 0).toString()) ?? 0;

    final title =
        (item['movie_title'] ?? item['title'] ?? item['name'] ?? 'Untitled')
            .toString();

    final normalizedMediaType = mediaTypeStr.trim().toLowerCase();

    final isTv = normalizedMediaType == 'tv' || normalizedMediaType == 'show';

    final imagePath = (item['poster_path'] ?? '').toString();

    final imageUrl = imagePath.isNotEmpty
        ? imagePath.startsWith('http')
              ? imagePath
              : 'https://image.tmdb.org/t/p/w500$imagePath'
        : '';

    final ratingVal =
        double.tryParse(
          (item['vote_average'] ?? item['rating'] ?? 0.0).toString(),
        ) ??
        0.0;

    final ratingStr = ratingVal > 0 ? ratingVal.toStringAsFixed(1) : '0.0';

    final releaseYear =
        (item['release_year'] ??
                item['release_date'] ??
                item['first_air_date'] ??
                '')
            .toString();

    final displayYear = releaseYear.length >= 4
        ? releaseYear.substring(0, 4)
        : releaseYear;

    final targetRoute = isTv ? '/tv/$id' : '/movie/$id';

    return Semantics(
      button: true,
      label: 'Open $title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.go(targetRoute),
                child: Ink(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.075),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 11),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPoster(imageUrl),
                      _buildPosterScrim(),
                      Positioned(
                        top: 9,
                        left: 9,
                        child: _buildMediaBadge(isTv),
                      ),
                      Positioned(left: 9, bottom: 9, child: _buildSavedBadge()),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: _buildActionMenu(
                          context: context,
                          id: id,
                          normalizedMediaType: normalizedMediaType,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go(targetRoute),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.15,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.arrow_outward_rounded,
                  color: Colors.white.withValues(alpha: 0.24),
                  size: 14,
                ),
              ],
            ),
          ),
          if (ratingVal > 0 || displayYear.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                if (displayYear.isNotEmpty) ...[
                  Icon(
                    isTv ? Icons.live_tv_outlined : Icons.local_movies_outlined,
                    color: Colors.white.withValues(alpha: 0.32),
                    size: 12,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      displayYear,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.44),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (ratingVal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
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
                          ratingStr,
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
          ],
        ],
      ),
    );
  }

  Widget _buildPoster(String imageUrl) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder();
      },
    );
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _lightPurple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _lightPurple.withValues(alpha: 0.14)),
            ),
            child: Icon(
              Icons.movie_filter_outlined,
              color: Colors.white.withValues(alpha: 0.28),
              size: 25,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'No artwork',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterScrim() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.5, 1],
            colors: [
              Colors.black.withValues(alpha: 0.12),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.68),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaBadge(bool isTv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0B0F).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTv ? Icons.live_tv_rounded : Icons.local_movies_outlined,
            color: _lightPurple,
            size: 11,
          ),
          const SizedBox(width: 5),
          Text(
            isTv ? 'SERIES' : 'MOVIE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedBadge() {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_lightPurple, _darkPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: _darkPurple.withValues(alpha: 0.38),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 16),
    );
  }

  Widget _buildActionMenu({
    required BuildContext context,
    required int id,
    required String normalizedMediaType,
  }) {
    return Container(
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
      child: PopupMenuButton<String>(
        tooltip: 'Watchlist options',
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: 18,
        ),
        color: _surface,
        surfaceTintColor: _surface,
        elevation: 18,
        offset: const Offset(0, 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        onSelected: (value) async {
          if (value == 'watchlist') {
            final providerStatus = provider
                .getMediaStatus(id, mediaType: normalizedMediaType)
                ?.trim()
                .toLowerCase();

            final itemStatus = (item['status'] ?? 'watchlist')
                .toString()
                .trim()
                .toLowerCase();

            final isWatchlist =
                itemStatus == 'watchlist' || providerStatus == 'watchlist';

            final messenger = ScaffoldMessenger.of(context);

            if (isWatchlist) {
              final success = await provider.removeFromWatchlist(
                id,
                mediaType: normalizedMediaType,
              );

              if (success) {
                onRemove(id);

                messenger.showSnackBar(
                  _buildCardSnackBar('Removed from Watchlist'),
                );
              } else {
                messenger.showSnackBar(
                  _buildCardSnackBar(
                    provider.errorMessage ?? 'Failed to remove item',
                    isError: true,
                  ),
                );
              }
            }
          } else if (value == 'track') {
            onTrack();
          } else if (value == 'manage') {
            onManage();
          }
        },
        itemBuilder: (context) {
          return [
            PopupMenuItem<String>(
              value: 'watchlist',
              height: 46,
              child: _buildPopupRow(
                icon: Icons.bookmark_remove_outlined,
                label: 'Remove from Watchlist',
                destructive: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'track',
              height: 46,
              child: _buildPopupRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Mark as Watched',
              ),
            ),
            PopupMenuItem<String>(
              value: 'manage',
              height: 46,
              child: _buildPopupRow(
                icon: Icons.playlist_add_rounded,
                label: 'Add to Custom List',
              ),
            ),
          ];
        },
      ),
    );
  }

  Widget _buildPopupRow({
    required IconData icon,
    required String label,
    bool destructive = false,
  }) {
    final color = destructive
        ? const Color(0xFFFF7185)
        : Colors.white.withValues(alpha: 0.8);

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: destructive
                ? const Color(0xFFFF647C).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: destructive ? const Color(0xFFFF8A9A) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  SnackBar _buildCardSnackBar(String message, {bool isError = false}) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? const Color(0xFFFF647C) : _lightPurple,
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
          ? const Color(0xFF241418)
          : const Color(0xFF141419),
      behavior: SnackBarBehavior.floating,
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
}
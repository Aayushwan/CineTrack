// frontend/lib/screens/discover_category_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/trakt_filter_bar.dart';

class DiscoverCategoryScreen extends StatefulWidget {
  final String category;

  const DiscoverCategoryScreen({super.key, required this.category});

  @override
  State<DiscoverCategoryScreen> createState() {
    return _DiscoverCategoryScreenState();
  }
}

class _DiscoverCategoryScreenState extends State<DiscoverCategoryScreen> {
  static const Color _background = Color(0xFF08080B);
  static const Color _surface = Color(0xFF141419);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

  final ScrollController _scrollController = ScrollController();

  List<dynamic> _items = [];

  int _currentPage = 5;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _errorMessage = '';

  String _selectedFilter = 'media';

  String get _apiMediaType {
    if (_selectedFilter == 'shows') return 'tv';
    return 'movie';
  }

  String get _title {
    switch (widget.category.toLowerCase()) {
      case 'anticipated':
        return 'Anticipated';
      case 'popular':
        return 'Popular';
      case 'trending':
      default:
        return 'Trending';
    }
  }

  String get _subtitle {
    switch (widget.category.toLowerCase()) {
      case 'anticipated':
        return 'The stories audiences cannot wait to see';
      case 'popular':
        return 'The most watched and talked-about titles';
      case 'trending':
      default:
        return 'What audiences are watching right now';
    }
  }

  IconData get _categoryIcon {
    switch (widget.category.toLowerCase()) {
      case 'anticipated':
        return Icons.auto_awesome_rounded;
      case 'popular':
        return Icons.trending_up_rounded;
      case 'trending':
      default:
        return Icons.local_fire_department_rounded;
    }
  }

  @override
  void initState() {
    super.initState();

    _fetchInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = '';
      _currentPage = 5;
      _hasMore = true;
    });

    try {
      final targetType = _apiMediaType;

      final results = await Future.wait([
        ApiService.getDiscoverMedia(
          category: widget.category,
          page: 1,
          type: targetType,
        ),
        ApiService.getDiscoverMedia(
          category: widget.category,
          page: 2,
          type: targetType,
        ),
        ApiService.getDiscoverMedia(
          category: widget.category,
          page: 3,
          type: targetType,
        ),
        ApiService.getDiscoverMedia(
          category: widget.category,
          page: 4,
          type: targetType,
        ),
        ApiService.getDiscoverMedia(
          category: widget.category,
          page: 5,
          type: targetType,
        ),
      ]);

      final List<dynamic> combined = [];

      for (final res in results) {
        final list = (res['results'] as List<dynamic>?) ?? [];

        combined.addAll(list);
      }

      if (mounted) {
        setState(() {
          _items = combined;
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');

          _isLoadingInitial = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoadingInitial) {
      _fetchMoreData();
    }
  }

  Future<void> _fetchMoreData() async {
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;

      final data = await ApiService.getDiscoverMedia(
        category: widget.category,
        page: nextPage,
        type: _apiMediaType,
      );

      final newItems = (data['results'] as List<dynamic>?) ?? [];

      if (mounted) {
        setState(() {
          if (newItems.isEmpty) {
            _hasMore = false;
          } else {
            _items.addAll(newItems);
            _currentPage = nextPage;
          }

          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  List<dynamic> get _filteredItems {
    return _items.where((item) {
      final String rawType = (item['media_type'] ?? '')
          .toString()
          .toLowerCase();

      final bool isTv =
          rawType == 'tv' ||
          rawType == 'show' ||
          item['first_air_date'] != null ||
          (item['name'] != null && item['title'] == null);

      if (_selectedFilter == 'shows') {
        return isTv;
      }

      if (_selectedFilter == 'movies') {
        return !isTv;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredItems;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const Positioned.fill(child: _CategoryBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(filteredList.length),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildBody(filteredList),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int itemCount) {
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
            tooltip: 'Back to Discover',
            onPressed: () => context.go('/discover'),
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
            child: Icon(_categoryIcon, color: Colors.white, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
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
                        '$itemCount '
                        '${itemCount == 1 ? 'title' : 'titles'}',
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
        ],
      ),
    );
  }

  Widget _buildBody(List<dynamic> filteredList) {
    if (_isLoadingInitial) {
      return const _CategoryLoadingState(key: ValueKey('loading'));
    }

    if (_errorMessage.isNotEmpty) {
      return _CategoryErrorState(
        key: const ValueKey('error'),
        message: _errorMessage,
        onRetry: _fetchInitialData,
      );
    }

    if (filteredList.isEmpty) {
      return Column(
        key: const ValueKey('empty'),
        children: [
          _buildFilterPanel(),
          Expanded(child: _buildEmptyState()),
        ],
      );
    }

    return Column(
      key: const ValueKey('content'),
      children: [
        _buildFilterPanel(),
        Expanded(
          child: RefreshIndicator(
            color: _lightPurple,
            backgroundColor: _surface,
            displacement: 24,
            onRefresh: _fetchInitialData,
            child: LayoutBuilder(
              builder: (context, constraints) {
                double maxExtent = 175;
                double aspectRatio = 0.56;

                if (constraints.maxWidth >= 1100) {
                  maxExtent = 220;
                  aspectRatio = 0.61;
                } else if (constraints.maxWidth >= 700) {
                  maxExtent = 200;
                  aspectRatio = 0.59;
                }

                return GridView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxExtent,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 21,
                  ),
                  itemCount: filteredList.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filteredList.length) {
                      return _buildLoadingMoreCard();
                    }

                    return _buildMovieCard(filteredList[index]);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF19131F), Color(0xFF121217)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purple.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          final description = Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _purple.withValues(alpha: 0.15)),
                ),
                child: Icon(_categoryIcon, color: _lightPurple, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Browse collection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final filter = TraktFilterBar(
            selectedFilter: _selectedFilter,
            showPeople: false,
            onFilterChanged: (filter) {
              if (_selectedFilter != filter) {
                setState(() {
                  _selectedFilter = filter;
                });

                _fetchInitialData();
              }
            },
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                description,
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filter,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: description),
              const SizedBox(width: 16),
              filter,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMovieCard(dynamic item) {
    final rawId = item['id'];

    final int id = rawId != null ? int.tryParse(rawId.toString()) ?? 0 : 0;

    final String title = (item['title'] ?? item['name'] ?? 'Untitled')
        .toString();

    final String rawType = (item['media_type'] ?? '').toString().toLowerCase();

    final String mediaType =
        rawType == 'tv' || rawType == 'show' || item['name'] != null
        ? 'tv'
        : 'movie';

    final posterPath = item['poster_path'];

    final String imageUrl =
        posterPath != null && posterPath.toString().trim().isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : '';

    final String releaseDate =
        (item['release_date'] ?? item['first_air_date'] ?? '').toString();

    final String? yearStr = releaseDate.length >= 4
        ? releaseDate.substring(0, 4)
        : null;

    final num voteAverage = (item['vote_average'] ?? 0.0) as num;

    return MovieCard(
      id: id,
      title: title,
      imageUrl: imageUrl,
      mediaType: mediaType,
      isLandscape: false,
      year: yearStr,
      rating: voteAverage.toDouble(),
    );
  }

  Widget _buildLoadingMoreCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            color: _lightPurple,
            strokeWidth: 2.4,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
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
                  Icons.search_off_rounded,
                  color: _lightPurple,
                  size: 31,
                ),
              ),
              const SizedBox(height: 19),
              Text(
                'No $_selectedFilter found',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'There are no $_selectedFilter available in $_title right now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 19),
              OutlinedButton.icon(
                onPressed: _fetchInitialData,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _lightPurple,
                  side: BorderSide(color: _purple.withValues(alpha: 0.28)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text(
                  'Refresh',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBackground extends StatelessWidget {
  const _CategoryBackground();

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

class _CategoryLoadingState extends StatelessWidget {
  const _CategoryLoadingState({super.key});

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

class _CategoryErrorState extends StatelessWidget {
  const _CategoryErrorState({
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
                  Icons.cloud_off_rounded,
                  color: Color(0xFFFF647C),
                  size: 29,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load this collection',
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

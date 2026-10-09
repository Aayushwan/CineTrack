// frontend/lib/screens/recommended_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/movie_card.dart';

class RecommendedScreen extends StatefulWidget {
  const RecommendedScreen({super.key});

  @override
  State<RecommendedScreen> createState() {
    return _RecommendedScreenState();
  }
}

class _RecommendedScreenState extends State<RecommendedScreen> {
  static const Color _background = Color(0xFF08080B);
  static const Color _surface = Color(0xFF141419);
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

  final ScrollController _scrollController = ScrollController();

  List<dynamic> _items = [];

  int _currentPage = 3;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _errorMessage = '';

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
    });

    try {
      final results = await Future.wait([
        ApiService.getDiscoverMedia(category: 'trending', page: 1, type: 'all'),
        ApiService.getDiscoverMedia(category: 'trending', page: 2, type: 'all'),
        ApiService.getDiscoverMedia(category: 'trending', page: 3, type: 'all'),
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
        category: 'trending',
        page: nextPage,
        type: 'all',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const Positioned.fill(child: _RecommendedBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildBody(),
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
            tooltip: 'Back',
            onPressed: () => context.go('/'),
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
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommended',
                  style: TextStyle(
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
                        '${_items.length} '
                        '${_items.length == 1 ? 'title' : 'titles'} '
                        'selected for you',
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

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const _RecommendedLoadingState(key: ValueKey('loading'));
    }

    if (_errorMessage.isNotEmpty) {
      return _RecommendedErrorState(
        key: const ValueKey('error'),
        message: _errorMessage,
        onRetry: _fetchInitialData,
      );
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      key: const ValueKey('content'),
      color: _lightPurple,
      backgroundColor: _surface,
      displacement: 24,
      onRefresh: _fetchInitialData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildOverviewPanel()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 42),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                double maxExtent = 175;
                double aspectRatio = 0.56;

                if (constraints.crossAxisExtent >= 1100) {
                  maxExtent = 220;
                  aspectRatio = 0.61;
                } else if (constraints.crossAxisExtent >= 700) {
                  maxExtent = 200;
                  aspectRatio = 0.59;
                }

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxExtent,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 21,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == _items.length) {
                      return _buildLoadingMoreCard();
                    }

                    return _buildMovieCard(_items[index]);
                  }, childCount: _items.length + (_isLoadingMore ? 1 : 0)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF21112A), Color(0xFF16121C), Color(0xFF101014)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _lightPurple.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.23),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -55,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _lightPurple.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: _lightPurple,
                          size: 14,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'CURATED FOR YOU',
                          style: TextStyle(
                            color: _lightPurple,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Stories worth\nyour time.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.75,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Explore trending movies and shows selected to help you find your next favorite.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 11,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 88,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RECOMMENDATIONS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 6,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(dynamic item) {
    final rawId = item['id'];

    final int id = rawId != null ? int.tryParse(rawId.toString()) ?? 0 : 0;

    final String title = (item['title'] ?? item['name'] ?? 'Untitled')
        .toString();

    final String rawType = (item['media_type'] ?? '').toString().toLowerCase();

    final bool isTv =
        rawType == 'tv' ||
        rawType == 'show' ||
        item['first_air_date'] != null ||
        (item['name'] != null && item['title'] == null);

    final String mediaType = isTv ? 'tv' : 'movie';

    final posterPath = item['poster_path'];

    final String posterUrl =
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
      imageUrl: posterUrl,
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
      key: const ValueKey('empty'),
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
                  Icons.auto_awesome_outlined,
                  color: _lightPurple,
                  size: 31,
                ),
              ),
              const SizedBox(height: 19),
              const Text(
                'No recommendations yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Refresh the page to look for more movies and shows.',
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

class _RecommendedBackground extends StatelessWidget {
  const _RecommendedBackground();

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

class _RecommendedLoadingState extends StatelessWidget {
  const _RecommendedLoadingState({super.key});

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

class _RecommendedErrorState extends StatelessWidget {
  const _RecommendedErrorState({
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
                'Unable to load recommendations',
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

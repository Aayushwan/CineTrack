// frontend/lib/screens/discover_category_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/trakt_filter_bar.dart';

class DiscoverCategoryScreen extends StatefulWidget {
  final String category; // 'trending', 'anticipated', 'popular'

  const DiscoverCategoryScreen({
    super.key,
    required this.category,
  });

  @override
  State<DiscoverCategoryScreen> createState() => _DiscoverCategoryScreenState();
}

class _DiscoverCategoryScreenState extends State<DiscoverCategoryScreen> {
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _items = [];
  int _currentPage = 5; // Pages 1 to 5 loaded upfront (100 cards)
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _errorMessage = '';

  // Active Trakt Filter: 'media', 'shows', 'movies'
  String _selectedFilter = 'media';

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

  // Fetch TMDB pages 1 through 5 simultaneously to yield 100 cards on load
  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        ApiService.getDiscoverMedia(category: widget.category, page: 1),
        ApiService.getDiscoverMedia(category: widget.category, page: 2),
        ApiService.getDiscoverMedia(category: widget.category, page: 3),
        ApiService.getDiscoverMedia(category: widget.category, page: 4),
        ApiService.getDiscoverMedia(category: widget.category, page: 5),
      ]);

      List<dynamic> combined = [];
      for (var res in results) {
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

  // Detect when user nears bottom to lazily fetch next TMDB pages
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // Filter items based on active Trakt filter
  List<dynamic> get _filteredItems {
    if (_selectedFilter == 'media') return _items;

    return _items.where((item) {
      final String rawType = (item['media_type'] ?? '').toString().toLowerCase();
      final bool isTv = rawType == 'tv' ||
          item['first_air_date'] != null ||
          (item['name'] != null && item['title'] == null);

      if (_selectedFilter == 'shows') return isTv;
      if (_selectedFilter == 'movies') return !isTv;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.go('/discover'),
        ),
        title: Row(
          children: [
            const Icon(Icons.arrow_circle_up_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              _title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Center-Aligned Trakt Filter Bar ──────────────────────────────
            TraktFilterBar(
              selectedFilter: _selectedFilter,
              showPeople: false,
              onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
            ),

            const SizedBox(height: 12),

            // ── Grid Content Section ─────────────────────────────────────────
            Expanded(
              child: _isLoadingInitial
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFA855F7)),
                    )
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        )
                      : filteredList.isEmpty
                          ? Center(
                              child: Text(
                                'No $_selectedFilter found in $_title.',
                                style: const TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            )
                          : RefreshIndicator(
                              color: const Color(0xFFA855F7),
                              backgroundColor: const Color(0xFF131316),
                              onRefresh: _fetchInitialData,
                              child: GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 160,
                                  childAspectRatio: 0.58,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: filteredList.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == filteredList.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFA855F7),
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    );
                                  }

                                  final item = filteredList[index];
                                  final id = item['id'];
                                  final title = item['title'] ?? item['name'] ?? 'Untitled';
                                  final mediaType = item['media_type'] ?? (item['name'] != null ? 'tv' : 'movie');

                                  final posterPath = item['poster_path'];
                                  final imageUrl = (posterPath != null && posterPath.toString().trim().isNotEmpty)
                                      ? 'https://image.tmdb.org/t/p/w500$posterPath'
                                      : '';

                                  final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
                                  final yearStr = (releaseDate.length >= 4) ? releaseDate.substring(0, 4) : null;
                                  final voteAverage = (item['vote_average'] ?? 0.0) as num;

                                  return MovieCard(
                                    id: id,
                                    title: title,
                                    imageUrl: imageUrl,
                                    mediaType: mediaType,
                                    isLandscape: false,
                                    year: yearStr,
                                    rating: voteAverage.toDouble(),
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
}
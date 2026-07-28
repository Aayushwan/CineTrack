// frontend/lib/screens/recommended_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';

class RecommendedScreen extends StatefulWidget {
  const RecommendedScreen({super.key});

  @override
  State<RecommendedScreen> createState() => _RecommendedScreenState();
}

class _RecommendedScreenState extends State<RecommendedScreen> {
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _items = [];
  int _currentPage = 3; // Pages 1, 2, and 3 loaded initially
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

  // Fetch pages 1, 2, and 3 upfront to ensure 60 cards (> 50) load right away
  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        ApiService.getDiscoverMedia(category: 'trending', page: 1),
        ApiService.getDiscoverMedia(category: 'trending', page: 2),
        ApiService.getDiscoverMedia(category: 'trending', page: 3),
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

  // Detect when user nears bottom of list and load next TMDB page
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Row(
          children: [
            Icon(Icons.arrow_circle_up_outlined, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Recommended',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoadingInitial
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE11D48)),
              )
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFFE11D48),
                    backgroundColor: const Color(0xFF1E293B),
                    onRefresh: _fetchInitialData,
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        childAspectRatio: 0.58, // Provides proper spacing for card + title + metadata
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFFE11D48),
                                strokeWidth: 2.5,
                              ),
                            ),
                          );
                        }

                        final item = _items[index];
                        final id = item['id'];
                        final title = item['title'] ?? item['name'] ?? 'Untitled';
                        final mediaType = item['media_type'] ?? (item['name'] != null ? 'tv' : 'movie');
                        
                        final posterPath = item['poster_path'];
                        final posterUrl = (posterPath != null && posterPath.toString().trim().isNotEmpty)
                            ? 'https://image.tmdb.org/t/p/w500$posterPath'
                            : '';

                        final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
                        final yearStr = (releaseDate.length >= 4) ? releaseDate.substring(0, 4) : null;
                        final voteAverage = (item['vote_average'] ?? 0.0) as num;

                        return MovieCard(
                          id: id,
                          title: title,
                          imageUrl: posterUrl,
                          mediaType: mediaType,
                          isLandscape: false,
                          year: yearStr,
                          rating: voteAverage.toDouble(),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
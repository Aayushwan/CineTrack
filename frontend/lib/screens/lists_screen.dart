// frontend/lib/screens/lists_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../models/movie.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _errorMessage = '';
  List<Movie> _watchlistMovies = [];

  // Mock data for "My Lists" section
  final List<Map<String, dynamic>> _customLists = [
    {
      'title': 'All Time Favorites',
      'itemCount': 14,
      'backdrop': 'https://image.tmdb.org/t/p/w780/8Y43POKjjKDGI9MH89NW0NAzzp8.jpg',
      'isPrivate': false,
    },
    {
      'title': 'Sci-Fi Mind Benders',
      'itemCount': 8,
      'backdrop': 'https://image.tmdb.org/t/p/w780/xg27NrFcsWGVR9Pqk37k34P033n.jpg',
      'isPrivate': true,
    },
    {
      'title': 'Weekend Rewatch',
      'itemCount': 5,
      'backdrop': 'https://image.tmdb.org/t/p/w780/9l172agA33yO9A3pA3ip3Lq18p.jpg',
      'isPrivate': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchWatchlist();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchWatchlist() async {
    try {
      final rawData = await ApiService.getWatchlist();
      final movies = rawData.map((item) {
        return Movie(
          id: item['movie_id'] ?? item['id'] ?? 0,
          title: item['movie_title'] ?? item['title'] ?? 'Untitled',
          posterPath: item['poster_path'] ?? '',
          voteAverage: (item['vote_average'] ?? 0.0).toDouble(),
          releaseDate: item['release_date'] ?? '',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _watchlistMovies = movies;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Tab Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lists',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Custom list creation coming soon!'),
                          backgroundColor: Color(0xFF1E293B),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFE11D48),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: const [
                  Tab(text: 'Watchlist'),
                  Tab(text: 'My Lists'),
                ],
              ),
              const SizedBox(height: 20),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWatchlistTab(),
                    _buildCustomListsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Watchlist View ---
  Widget _buildWatchlistTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
      );
    }

    if (_watchlistMovies.isEmpty) {
      return const Center(
        child: Text(
          'Your watchlist is empty.\nExplore Discover to save titles!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.5),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.62,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _watchlistMovies.length,
      itemBuilder: (context, index) {
        final movie = _watchlistMovies[index];
        return GestureDetector(
          onTap: () => context.go('/movie/${movie.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF1E293B),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      movie.fullPosterUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.movie_rounded, color: Colors.white24, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Custom Lists View ---
  Widget _buildCustomListsTab() {
    return ListView.separated(
      itemCount: _customLists.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final list = _customLists[index];
        return Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1E293B),
            image: DecorationImage(
              image: NetworkImage(list['backdrop']),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.55),
                BlendMode.darken,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          list['title'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (list['isPrivate']) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${list['itemCount']} items',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 28),
            ],
          ),
        );
      },
    );
  }
}
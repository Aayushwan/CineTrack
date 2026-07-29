// frontend/lib/screens/discover_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import '../widgets/trakt_filter_bar.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String _errorMessage = '';

  String _selectedFilter = 'media';
  String _selectedGenre = 'All';
  String _selectedStatus = 'All';
  String _selectedDecade = 'All';

  List<dynamic> _trending = [];
  List<dynamic> _releases = [];
  List<dynamic> _anticipated = [];
  List<dynamic> _popular = [];

  @override
  void initState() {
    super.initState();
    _loadDiscoverData();
  }

  Future<void> _loadDiscoverData() async {
    try {
      final results = await Future.wait([
        ApiService.getDiscoverMedia(category: 'trending'),
        ApiService.getDiscoverMedia(category: 'releases'),
        ApiService.getDiscoverMedia(category: 'anticipated'),
        ApiService.getDiscoverMedia(category: 'popular'),
      ]);

      if (mounted) {
        setState(() {
          _trending = (results[0]['results'] as List<dynamic>?) ?? [];
          _releases = (results[1]['results'] as List<dynamic>?) ?? [];
          _anticipated = (results[2]['results'] as List<dynamic>?) ?? [];
          _popular = (results[3]['results'] as List<dynamic>?) ?? [];
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

  List<dynamic> _filterList(List<dynamic> list) {
    return list.where((item) {
      final String rawType = (item['media_type'] ?? '').toString().toLowerCase();
      final bool isTv = rawType == 'tv' || item['first_air_date'] != null || item['name'] != null;

      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'movies' && isTv) return false;

      if (_selectedGenre != 'All') {
        final List<dynamic> genreIds = item['genre_ids'] ?? [];
        final targetGenreId = FilterDrawer.genreMap[_selectedGenre];
        if (targetGenreId != null && !genreIds.contains(targetGenreId)) return false;
      }

      return true;
    }).toList();
  }

  bool get _hasActiveSidebarFilters =>
      _selectedGenre != 'All' || _selectedStatus != 'All' || _selectedDecade != 'All';

  @override
  Widget build(BuildContext context) {
    final filteredTrending = _filterList(_trending);
    final filteredReleases = _filterList(_releases);
    final filteredAnticipated = _filterList(_anticipated);
    final filteredPopular = _filterList(_popular);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF09090B),
      endDrawer: FilterDrawer(
        selectedGenre: _selectedGenre,
        selectedStatus: _selectedStatus,
        selectedDecade: _selectedDecade,
        onApply: (genre, status, decade) {
          setState(() {
            _selectedGenre = genre;
            _selectedStatus = status;
            _selectedDecade = decade;
          });
        },
        onReset: () {
          setState(() {
            _selectedGenre = 'All';
            _selectedStatus = 'All';
            _selectedDecade = 'All';
          });
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── STICKY TOP HEADER ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  const Text(
                    'Discover',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    icon: Stack(
                      children: [
                        const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                        if (_hasActiveSidebarFilters)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFA855F7),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF131316),
                      padding: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE BODY CONTENT ─────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFA855F7)))
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionHeader(
                                title: 'Trending',
                                onTap: () => context.go('/discover/trending'),
                              ),
                              const SizedBox(height: 12),
                              _buildHorizontalMediaList(items: filteredTrending, isLandscape: false),

                              const SizedBox(height: 28),

                              SectionHeader(
                                title: 'Releases',
                                onTap: () => context.go('/releases'),
                              ),
                              const SizedBox(height: 12),
                              _buildHorizontalMediaList(items: filteredReleases, isLandscape: true, isReleases: true),

                              const SizedBox(height: 28),

                              SectionHeader(
                                title: 'Anticipated',
                                onTap: () => context.go('/discover/anticipated'),
                              ),
                              const SizedBox(height: 12),
                              _buildHorizontalMediaList(items: filteredAnticipated, isLandscape: false),

                              const SizedBox(height: 28),

                              SectionHeader(
                                title: 'Popular',
                                onTap: () => context.go('/discover/popular'),
                              ),
                              const SizedBox(height: 12),
                              _buildHorizontalMediaList(items: filteredPopular, isLandscape: false),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalMediaList({
    required List<dynamic> items,
    required bool isLandscape,
    bool isReleases = false,
  }) {
    if (items.isEmpty) {
      return Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF131316),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: Text('No titles found matching criteria', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    final displayItems = items.take(20).toList();
    final double listHeight = isLandscape ? 170 : 230;
    final double cardWidth = isLandscape ? 240 : 115;

    return SizedBox(
      height: listHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          final id = item['id'];
          final title = item['title'] ?? item['name'] ?? 'Untitled';
          final mediaType = item['media_type'] ?? (item['name'] != null ? 'tv' : 'movie');

          final imagePath = isLandscape
              ? (item['backdrop_path'] ?? item['poster_path'])
              : item['poster_path'];

          final imageUrl = (imagePath != null && imagePath.toString().trim().isNotEmpty)
              ? 'https://image.tmdb.org/t/p/w500$imagePath'
              : '';

          final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
          final yearStr = (releaseDate.length >= 4) ? releaseDate.substring(0, 4) : null;
          final voteAverage = (item['vote_average'] ?? 0.0) as num;

          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 14),
            child: MovieCard(
              id: id,
              title: title,
              imageUrl: imageUrl,
              mediaType: mediaType,
              isLandscape: isLandscape,
              year: yearStr,
              rating: voteAverage.toDouble(),
            ),
          );
        },
      ),
    );
  }
}
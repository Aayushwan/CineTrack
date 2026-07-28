// frontend/lib/screens/discover_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  List<dynamic> _trending = [];
  List<dynamic> _releases = [];
  List<dynamic> _anticipated = [];
  List<dynamic> _popular = [];

  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDiscoverData();
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: _isLoading
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
                : SingleChildScrollView(
                    controller: _mainScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Title
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            'Discover',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 1. Trending
                        SectionHeader(
                          title: 'Trending',
                          onTap: () => context.go('/discover/trending'),
                        ),
                        const SizedBox(height: 12),
                        _buildHorizontalMediaList(
                          items: _trending,
                          emptyMessage: 'No trending titles found',
                          isLandscape: false,
                        ),
                        const SizedBox(height: 28),

                        // 2. Releases
                        SectionHeader(
                          title: 'Releases',
                          onTap: () => context.go('/releases'),
                        ),
                        const SizedBox(height: 12),
                        _buildHorizontalMediaList(
                          items: _releases,
                          emptyMessage: 'No release titles found',
                          isLandscape: true,
                          isReleases: true,
                        ),
                        const SizedBox(height: 28),

                        // 3. Anticipated
                        SectionHeader(
                          title: 'Anticipated',
                          onTap: () => context.go('/discover/anticipated'),
                        ),
                        const SizedBox(height: 12),
                        _buildHorizontalMediaList(
                          items: _anticipated,
                          emptyMessage: 'No anticipated titles found',
                          isLandscape: false,
                        ),
                        const SizedBox(height: 28),

                        // 4. Popular
                        SectionHeader(
                          title: 'Popular',
                          onTap: () => context.go('/discover/popular'),
                        ),
                        const SizedBox(height: 12),
                        _buildHorizontalMediaList(
                          items: _popular,
                          emptyMessage: 'No popular titles found',
                          isLandscape: false,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHorizontalMediaList({
    required List<dynamic> items,
    required String emptyMessage,
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
        child: Center(
          child: Text(
            emptyMessage,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    final displayItems = items.take(20).toList();
    final double listHeight = isLandscape ? 170 : 230;
    final double cardWidth = isLandscape ? 240 : 115;

    return SizedBox(
      height: listHeight,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
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
            String? leftMetadataText;

            if (isReleases && releaseDate.isNotEmpty) {
              try {
                final DateTime dt = DateTime.parse(releaseDate);
                final List<String> months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                ];
                leftMetadataText = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
              } catch (e) {
                leftMetadataText = releaseDate;
              }
            } else {
              leftMetadataText = (releaseDate.length >= 4) ? releaseDate.substring(0, 4) : null;
            }

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
                year: leftMetadataText,
                rating: voteAverage.toDouble(),
              ),
            );
          },
        ),
      ),
    );
  }
}
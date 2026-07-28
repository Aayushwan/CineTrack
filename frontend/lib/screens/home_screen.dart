// frontend/lib/screens/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  List<dynamic> _continueWatching = [];
  List<dynamic> _startWatching = [];
  List<dynamic> _upcomingReleases = [];
  List<dynamic> _recommended = [];
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final trendingData = await ApiService.getTrendingMovies();
      final upcomingData = await ApiService.getUpcomingMedia();

      final trendingList = (trendingData['results'] as List<dynamic>?) ?? [];
      final upcomingList = (upcomingData['results'] as List<dynamic>?) ?? [];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final upcomingFromToday = upcomingList.where((item) {
        final dateStr = item['release_date'] ?? item['first_air_date'];
        if (dateStr == null || dateStr.toString().trim().isEmpty) return false;
        try {
          final releaseDate = DateTime.parse(dateStr.toString());
          final releaseDay = DateTime(releaseDate.year, releaseDate.month, releaseDate.day);
          return !releaseDay.isBefore(today);
        } catch (e) {
          return false;
        }
      }).toList();

      upcomingFromToday.sort((a, b) {
        final dateA = DateTime.tryParse(a['release_date'] ?? a['first_air_date'] ?? '') ?? DateTime(2099);
        final dateB = DateTime.tryParse(b['release_date'] ?? b['first_air_date'] ?? '') ?? DateTime(2099);
        return dateA.compareTo(dateB);
      });

      if (mounted) {
        setState(() {
          _startWatching = trendingList;
          _recommended = trendingList.reversed.toList();
          _upcomingReleases = upcomingFromToday;
          
          _continueWatching = []; 
          _history = []; 
          
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
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
            : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            'CineTrack',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 1. Continue Watching
                        SectionHeader(
                          title: 'Continue Watching',
                          onTap: () => context.go('/progress'),
                        ),
                        const SizedBox(height: 12),
                        _buildMediaList(
                          items: _continueWatching,
                          emptyMessage: 'Start watching shows',
                          isLandscape: true,
                          isContinueWatching: true,
                        ),
                        const SizedBox(height: 28),

                        // 2. Start Watching
                        SectionHeader(
                          title: 'Start Watching',
                          onTap: () => context.go('/watchlist'),
                        ),
                        const SizedBox(height: 12),
                        _buildMediaList(
                          items: _startWatching,
                          emptyMessage: 'No recommendations available',
                          isLandscape: false,
                        ),
                        const SizedBox(height: 28),

                        // 3. Calendar
                        SectionHeader(
                          title: 'Calendar',
                          onTap: () => context.go('/calendar'),
                        ),
                        const SizedBox(height: 12),
                        _buildMediaList(
                          items: _upcomingReleases,
                          emptyMessage: 'No upcoming releases found',
                          isLandscape: true,
                          isCalendar: true,
                        ),
                        const SizedBox(height: 28),

                        // 4. Recommended (Now White by default, turns Red on click!)
                        SectionHeader(
                          title: 'Recommended',
                          onTap: () => context.go('/recommended'),
                        ),
                        const SizedBox(height: 12),
                        _buildMediaList(
                          items: _recommended,
                          emptyMessage: 'No recommendations found',
                          isLandscape: false,
                        ),
                        const SizedBox(height: 28),

                        // 5. History
                        SectionHeader(
                          title: 'History',
                          onTap: () => context.go('/history'),
                        ),
                        const SizedBox(height: 12),
                        _buildMediaList(
                          items: _history,
                          emptyMessage: 'Watch movies, shows to view history',
                          isLandscape: true,
                          isHistory: true,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildMediaList({
    required List<dynamic> items,
    required String emptyMessage,
    required bool isLandscape,
    bool isContinueWatching = false,
    bool isHistory = false,
    bool isCalendar = false,
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
          child: Text(emptyMessage, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    final int itemLimit = (isHistory || isCalendar) ? 7 : 20;
    final displayItems = items.take(itemLimit).toList();

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
            String? metadataLeftText;

            if (isCalendar && releaseDate.isNotEmpty) {
              try {
                final DateTime dt = DateTime.parse(releaseDate);
                final List<String> months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                ];
                metadataLeftText = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
              } catch (e) {
                metadataLeftText = releaseDate;
              }
            } else {
              metadataLeftText = (releaseDate.length >= 4) ? releaseDate.substring(0, 4) : null;
            }

            final voteAverage = (item['vote_average'] ?? 0.0) as num;

            String? subtitle;
            String? overlayLeft;
            String? overlayRight;
            double? progress;

            if (isContinueWatching) {
              subtitle = 'S1 • E${(index % 10) + 1} - Next Episode';
              overlayLeft = '45m';
              overlayRight = '${(index % 5) + 2} left';
              progress = 0.3 + (index * 0.1).clamp(0.0, 1.0);
            } else if (isHistory) {
              final watchedDate = item['watched_date'] ?? 'Jul 28, 2026';
              overlayLeft = watchedDate; 
            }

            return Container(
              width: cardWidth,
              margin: const EdgeInsets.only(right: 14),
              child: MovieCard(
                id: id,
                title: title,
                imageUrl: imageUrl,
                mediaType: mediaType,
                isLandscape: isLandscape,
                year: metadataLeftText,
                rating: voteAverage.toDouble(),
                subtitle: subtitle,
                overlayLeftText: overlayLeft,
                overlayRightText: overlayRight,
                progress: progress,
              ),
            );
          },
        ),
      ),
    );
  }
}
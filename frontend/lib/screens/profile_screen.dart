// frontend/lib/screens/profile_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../providers/watchlist_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedAnalyticsPeriod = 0; // 0 = Current Month, 1 = All Time
  bool _isLoadingStats = true;
  bool _isLoadingHistory = true;
  Map<String, dynamic>? _statsData;
  List<dynamic> _historyItems = [];
  
  String _username = 'User'; 

  // Empty list ready to be connected to your actual Continue Watching backend data
  final List<Map<String, dynamic>> _continueWatching = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString('username');
      if (storedName != null && storedName.isNotEmpty && mounted) {
        setState(() => _username = storedName);
      }
      
      // Fetch stats and history simultaneously
      final results = await Future.wait([
        ApiService.getProfileStats(),
        ApiService.getWatchHistory(),
      ]);
      
      if (mounted) {
        setState(() {
          _statsData = results[0] as Map<String, dynamic>;
          _isLoadingStats = false;

          // Store up to 10 recent items for the carousel
          final historyData = results[1] as List<dynamic>;
          _historyItems = historyData.take(10).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _isLoadingHistory = false;
        });
      }
    }
  }

  // Quick helper to format ISO dates to "Oct 09, 2026"
  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty || isoString == 'null') return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. User Header
              _buildUserHeader(context),

              const SizedBox(height: 28),

              // 2. Monthly vs All Time Analytics Toggle
              _buildAnalyticsHeader(),

              const SizedBox(height: 16),

              // 3. Compact Analytics Dashboard
              _buildAnalyticsCard(),

              const SizedBox(height: 28),

              // 4. Continue Watching Section
              _buildSectionTitle('Continue Watching'),
              const SizedBox(height: 12),
              _buildContinueWatchingList(),

              const SizedBox(height: 28),

              // 5. Favorites Carousel Section
              _buildDynamicFavoritesSection(context),

              const SizedBox(height: 28),

              // 6. History Carousel Section
              _buildDynamicHistorySection(context),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildUserHeader(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 36,
          backgroundColor: Color(0xFF1E293B),
          child: Icon(Icons.person_rounded, size: 40, color: Colors.white54),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            _username,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          onPressed: () async {
            await ApiService.clearToken();
            if (!context.mounted) return;
            context.go('/login');
          },
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
          tooltip: 'Log Out',
        ),
      ],
    );
  }

  Widget _buildAnalyticsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Analytics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131316),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              _buildPeriodTab('This Month', 0),
              _buildPeriodTab('All Time', 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodTab(String title, int index) {
    final isSelected = _selectedAnalyticsPeriod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedAnalyticsPeriod = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE11D48) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    if (_isLoadingStats) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF131316),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE11D48)),
        ),
      );
    }

    final periodKey = _selectedAnalyticsPeriod == 0 ? 'thisMonth' : 'allTime';
    final currentStats = _statsData?[periodKey] ?? {};

    final totalTime = currentStats['totalScreenTime'] ?? currentStats['total_screen_time'] ?? currentStats['screenTime'] ?? '0h 0m';
    final moviesCount = currentStats['moviesCount'] ?? currentStats['movies_count'] ?? '0';
    final seriesCount = currentStats['seriesCount'] ?? currentStats['series_count'] ?? currentStats['episodesCount'] ?? '0';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: _buildStatMetric('Total Watch Time', totalTime.toString())),
          Container(height: 40, width: 1, color: Colors.white10),
          Expanded(child: _buildStatMetric('Movies Watched', moviesCount.toString())),
          Container(height: 40, width: 1, color: Colors.white10),
          Expanded(child: _buildStatMetric('Series Watched', seriesCount.toString())),
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildContinueWatchingList() {
    if (_continueWatching.isEmpty) {
      return const Text(
        'Nothing in progress. Start watching something!',
        style: TextStyle(color: Colors.white54, fontSize: 14),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _continueWatching.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final show = _continueWatching[index];
        final double factor = show['watchedEpisodes'] / show['totalEpisodes'];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131316),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    show['title'],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    '${show['watchedEpisodes']}/${show['totalEpisodes']} eps',
                    style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                show['season'],
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: factor,
                  backgroundColor: Colors.white10,
                  color: const Color(0xFFE11D48),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicFavoritesSection(BuildContext context) {
    return Consumer<WatchlistProvider>(
      builder: (context, watchlistProvider, child) {
        final favorites = watchlistProvider.favoriteItems; 

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.go('/favorites'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Favorites',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            if (favorites.isEmpty)
              const Text('No favorites yet. Go heart some movies!', style: TextStyle(color: Colors.white54))
            else
              SizedBox(
                height: 170, 
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: favorites.length > 10 ? 10 : favorites.length,
                    itemBuilder: (context, index) {
                      final item = favorites[index];
                      
                      final rawPoster = (item.posterPath ?? '').toString();
                      final posterUrl = (rawPoster.isNotEmpty && rawPoster != 'null')
                          ? (rawPoster.startsWith('http') ? rawPoster : 'https://image.tmdb.org/t/p/w300$rawPoster') 
                          : '';
                          
                      final mediaType = item.mediaType.isNotEmpty ? item.mediaType : 'movie';
                      final id = item.movieId;

                      return GestureDetector(
                        onTap: () => context.go('/$mediaType/$id'),
                        child: Container(
                          width: 115,
                          margin: const EdgeInsets.only(right: 14),
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: posterUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          posterUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Center(child: Icon(Icons.movie_rounded, color: Colors.white24, size: 40)),
                                        ),
                                      )
                                    : const Center(child: Icon(Icons.movie_rounded, color: Colors.white24, size: 40)),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  height: 26,
                                  width: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                                    color: const Color(0xFF131316),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: Colors.white10),
                                    ),
                                    onSelected: (value) async {
                                      if (value == 'remove') {
                                        final success = await watchlistProvider.removeFromWatchlist(id, mediaType: mediaType);
                                        if (!context.mounted) return; 
                                        if (success) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Removed from Favorites', style: TextStyle(color: Colors.white)),
                                              backgroundColor: Color(0xFF131316),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Row(
                                          children: [
                                            Icon(Icons.heart_broken_rounded, color: Colors.redAccent, size: 18),
                                            SizedBox(width: 8),
                                            Text('Remove from Favorites', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDynamicHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.go('/history'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.history_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        if (_isLoadingHistory)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFE11D48))),
          )
        else if (_historyItems.isEmpty)
          const Text('Your history is empty.', style: TextStyle(color: Colors.white54))
        else
          SizedBox(
            height: 210, 
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _historyItems.length,
                itemBuilder: (context, index) {
                  final item = _historyItems[index];
                  
                  final int historyId = int.tryParse((item['id'] ?? item['history_id'] ?? item['historyId'] ?? '0').toString()) ?? 0;
                  final String mediaId = (item['media_id'] ?? item['mediaId'] ?? item['movie_id'] ?? item['movieId'] ?? '0').toString();
                  final String mediaType = (item['media_type'] ?? item['mediaType'] ?? item['type'] ?? 'movie').toString().toLowerCase();
                  final String title = (item['title'] ?? item['movie_title'] ?? item['movieTitle'] ?? item['name'] ?? 'Unknown').toString();
                  
                  final String rawDate = (item['watched_at'] ?? item['watchedAt'] ?? '').toString();
                  final String displayDate = _formatDate(rawDate);
                  
                  final String rawPoster = (item['poster_path'] ?? item['posterPath'] ?? item['poster'] ?? item['image_url'] ?? '').toString();
                  final String posterUrl = (rawPoster.isNotEmpty && rawPoster != 'null') 
                      ? (rawPoster.startsWith('http') ? rawPoster : 'https://image.tmdb.org/t/p/w300$rawPoster') 
                      : '';

                  return GestureDetector(
                    onTap: () => context.go('/$mediaType/$mediaId'),
                    child: Container(
                      width: 115, 
                      margin: const EdgeInsets.only(right: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 170, 
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (posterUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      posterUrl,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      errorBuilder: (_, _, _) => const Center(child: Icon(Icons.movie_rounded, color: Colors.white24, size: 40)),
                                    ),
                                  )
                                else
                                  const Center(child: Icon(Icons.movie_rounded, color: Colors.white24, size: 40)),
                                
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                Positioned(
                                  bottom: 6,
                                  left: 8,
                                  child: Text(
                                    displayDate,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    height: 26,
                                    width: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                                      color: const Color(0xFF131316),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: const BorderSide(color: Colors.white10),
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'remove') {
                                          try {
                                            await ApiService.removeWatchHistory(historyId);
                                            if (!context.mounted) return; 
                                            setState(() {
                                              _historyItems.removeWhere((element) => element['id'] == item['id']);
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from history', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316)));
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove: $e', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 18),
                                              SizedBox(width: 8),
                                              Text('Remove from History', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }
}
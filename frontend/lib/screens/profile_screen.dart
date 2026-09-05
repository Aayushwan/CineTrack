// frontend/lib/screens/profile_screen.dart
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
  Map<String, dynamic>? _statsData;
  
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
      
      final stats = await ApiService.getProfileStats();
      
      if (mounted) {
        setState(() {
          if (storedName != null && storedName.isNotEmpty) {
            _username = storedName;
          }
          _statsData = stats;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
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

              // 3. Analytics Dashboard
              _buildAnalyticsCard(),

              const SizedBox(height: 28),

              // 4. Continue Watching Section
              _buildSectionTitle('Continue Watching'),
              const SizedBox(height: 12),
              _buildContinueWatchingList(),

              const SizedBox(height: 28),

              // 5. Favorites Section (Dynamic connected to WatchlistProvider)
              _buildDynamicFavoritesSection(context),

              const SizedBox(height: 28),

              // 6. Settings & Quick Actions
              _buildActionTile(
                icon: Icons.history_toggle_off_rounded,
                title: 'Full Watch History',
                onTap: () => context.go('/history'),
              ),
              const SizedBox(height: 8),
              _buildActionTile(
                icon: Icons.settings_outlined,
                title: 'Account Settings',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings coming soon!'),
                      backgroundColor: Color(0xFF1E293B),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildActionTile(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                color: const Color(0xFFE11D48),
                onTap: () async {
                  await ApiService.clearToken();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
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
        height: 140,
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
    final currentStats = _statsData?[periodKey] ?? {
      'screenTime': '0h 0m',
      'moviesCount': '0',
      'episodesCount': '0',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: Color(0xFFE11D48), size: 22),
              const SizedBox(width: 8),
              Text(
                currentStats['screenTime']?.toString() ?? '0h 0m',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Total Screen Time', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const Divider(height: 32, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatMetric('Movies Watched', currentStats['moviesCount']?.toString() ?? '0'),
              Container(height: 30, width: 1, color: Colors.white10),
              _buildStatMetric('Episodes Watched', currentStats['episodesCount']?.toString() ?? '0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
        // 👇 Use the built-in getter from your provider
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
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: favorites.length > 10 ? 10 : favorites.length,
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    // 👇 Use dot notation because 'item' is a WatchlistItem object
                    final posterUrl = item.posterPath != null 
                        ? 'https://image.tmdb.org/t/p/w300${item.posterPath}' 
                        : '';
                    final mediaType = item.mediaType.isNotEmpty ? item.mediaType : 'movie';
                    final id = item.movieId;

                    return GestureDetector(
                      onTap: () => context.go('/$mediaType/$id'),
                      child: Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          image: posterUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(posterUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: const Color(0xFF131316),
    );
  }
}
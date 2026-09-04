// frontend/lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedAnalyticsPeriod = 0; // 0 = Current Month, 1 = All Time
  bool _isLoadingStats = true;
  Map<String, dynamic>? _statsData;
  
  // 👇 Added dynamic username state with a personalized default fallback
  String _username = 'User'; 

  // Mock Favorites
  final List<Map<String, String>> _favorites = [
    {
      'title': 'Interstellar',
      'poster': 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
    },
    {
      'title': 'Spider-Man: Across the Spider-Verse',
      'poster': 'https://image.tmdb.org/t/p/w500/8Vt6m294P31C3fa63891xS35B4.jpg',
    },
    {
      'title': 'Panchayat',
      'poster': 'https://image.tmdb.org/t/p/w500/xg27NrFcsWGVR9Pqk37k34P033n.jpg',
    },
  ];

  // Mock Ongoing Show Progress
  final List<Map<String, dynamic>> _showProgress = [
    {
      'title': 'Panchayat',
      'season': 'Season 4',
      'watchedEpisodes': 2,
      'totalEpisodes': 8,
      'backdrop': 'https://image.tmdb.org/t/p/w780/xg27NrFcsWGVR9Pqk37k34P033n.jpg',
    },
    {
      'title': 'Sapne vs Everyone',
      'season': 'Season 1',
      'watchedEpisodes': 4,
      'totalEpisodes': 5,
      'backdrop': 'https://image.tmdb.org/t/p/w780/8Y43POKjjKDGI9MH89NW0NAzzp8.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      // 👇 Fetch the authenticated username dynamically from local storage
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

              // 3. Analytics Dashboard (Dynamic)
              _buildAnalyticsCard(),

              const SizedBox(height: 28),

              // 4. Show Progress Section
              _buildSectionTitle('Show Progress'),
              const SizedBox(height: 12),
              _buildShowProgressList(),

              const SizedBox(height: 28),

              // 5. Favorites Section
              _buildSectionTitle('Favorites'),
              const SizedBox(height: 12),
              _buildFavoritesList(),

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
            _username, // 👈 Bound to dynamic state instead of hardcoded text
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

  Widget _buildShowProgressList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _showProgress.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final show = _showProgress[index];
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

  Widget _buildFavoritesList() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          return Container(
            width: 110,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF1E293B),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                favorite['poster']!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.favorite_rounded, color: Colors.white24)),
              ),
            ),
          );
        },
      ),
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
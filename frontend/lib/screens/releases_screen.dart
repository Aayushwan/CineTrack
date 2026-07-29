// frontend/lib/screens/releases_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';

class ReleasesScreen extends StatefulWidget {
  const ReleasesScreen({super.key});

  @override
  State<ReleasesScreen> createState() => _ReleasesScreenState();
}

class _ReleasesScreenState extends State<ReleasesScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  // Key: "YYYY-MM-DD", Value: List of release items
  Map<String, List<dynamic>> _dateReleaseMap = {};
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReleasesData();
  }

  Future<void> _loadReleasesData() async {
    try {
      final results = await Future.wait([
        ApiService.getDiscoverMedia(category: 'releases', page: 1),
        ApiService.getDiscoverMedia(category: 'releases', page: 2),
        ApiService.getDiscoverMedia(category: 'releases', page: 3),
        ApiService.getUpcomingMedia(),
      ]);

      Map<String, List<dynamic>> tempMap = {};

      for (var res in results) {
        final list = (res['results'] as List<dynamic>?) ?? [];
        for (var item in list) {
          final dateStr = item['release_date'] ?? item['first_air_date'];
          if (dateStr != null && dateStr.toString().trim().isNotEmpty) {
            final key = dateStr.toString().substring(0, 10);
            tempMap.putIfAbsent(key, () => []);

            if (!tempMap[key]!.any((existing) => existing['id'] == item['id'])) {
              tempMap[key]!.add(item);
            }
          }
        }
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (mounted) {
        setState(() {
          _dateReleaseMap = tempMap;
          _selectedDate = today;
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

  // Shift selected week backward or forward by 7 days
  void _shiftWeek(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  String _formatDateKey(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _getFormattedHeaderDate(DateTime dt) {
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthStr = months[dt.month - 1];

    int day = dt.day;
    String suffix = 'th';
    if (day < 11 || day > 13) {
      switch (day % 10) {
        case 1: suffix = 'st'; break;
        case 2: suffix = 'nd'; break;
        case 3: suffix = 'rd'; break;
      }
    }
    return '$monthStr $day$suffix, ${dt.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    // Generate a 7-day week view around the selected date
    final weekDays = List.generate(7, (index) => _selectedDate.add(Duration(days: index - 2)));

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
            Icon(Icons.new_releases_rounded, color: Color(0xFFB57EDC), size: 22),
            SizedBox(width: 8),
            Text(
              'Releases',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
            : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🗓️ 1. Trakt.tv Style Week Strip Container
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0),
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131316),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              // Controls: [<] Today [>]
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                                    onPressed: () => _shiftWeek(-7),
                                    tooltip: 'Previous Week',
                                  ),
                                  GestureDetector(
                                    onTap: _jumpToToday,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Today',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                                    onPressed: () => _shiftWeek(7),
                                    tooltip: 'Next Week',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 7 Days Strip Row with Badges (+19, +7, etc.)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: weekDays.map((date) {
                                  final isSelected = _isSameDay(date, _selectedDate);
                                  final key = _formatDateKey(date);
                                  final itemsOnDate = _dateReleaseMap[key] ?? [];
                                  final count = itemsOnDate.length;

                                  final List<String> months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                                  final List<String> days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedDate = date);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 46,
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF26262F) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: isSelected
                                            ? Border.all(color: const Color(0xFFB57EDC).withValues(alpha: 0.5))
                                            : null,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            months[date.month - 1],
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.white38,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${date.day}',
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.white70,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            days[date.weekday - 1],
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.white38,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 4),

                                          // Release Count Badge (e.g. "+7")
                                          if (count > 0)
                                            Text(
                                              '+$count',
                                              style: TextStyle(
                                                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFB57EDC),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          else
                                            const Text('-', style: TextStyle(color: Colors.white24, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 📅 2. Releases Grouped Date by Date Below
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: weekDays.map((date) {
                            final key = _formatDateKey(date);
                            final items = _dateReleaseMap[key] ?? [];

                            if (items.isEmpty) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date Header (e.g., "July 28th, 2026")
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                                  child: Text(
                                    _getFormattedHeaderDate(date),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),

                                // Grid of Landscape Cards for this specific date
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 260,
                                    childAspectRatio: 1.25, // Landscape 16:9 ratio
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 18,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    final id = item['id'];
                                    final title = item['title'] ?? item['name'] ?? 'Untitled';
                                    final mediaType = item['media_type'] ?? (item['name'] != null ? 'tv' : 'movie');

                                    final imagePath = item['backdrop_path'] ?? item['poster_path'];
                                    final imageUrl = (imagePath != null && imagePath.toString().trim().isNotEmpty)
                                        ? 'https://image.tmdb.org/t/p/w500$imagePath'
                                        : '';

                                    // Dynamic Subtitle & Air Time Badge handling
                                    String subtitleText;
                                    String overlayBadge;

                                    if (mediaType == 'tv') {
                                      final season = item['season_number'] ?? 1;
                                      final episode = item['episode_number'] ?? (index % 12) + 1;
                                      final epName = item['episode_name'] ?? 'Episode $episode';
                                      subtitleText = 'S$season • E$episode - $epName';
                                      
                                      overlayBadge = item['air_time'] ?? '9:30 AM • New';
                                    } else {
                                      subtitleText = 'Movie Release';
                                      overlayBadge = item['air_time'] ?? '5:30 PM • New';
                                    }

                                    return MovieCard(
                                      id: id,
                                      title: title,
                                      imageUrl: imageUrl,
                                      mediaType: mediaType,
                                      isLandscape: true,
                                      subtitle: subtitleText,
                                      overlayLeftText: overlayBadge,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
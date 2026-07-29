// frontend/lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/trakt_filter_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Active Trakt Capsule Filter: 'media', 'shows', 'movies'
  String _selectedFilter = 'media';

  // Active Sidebar Filters
  String _selectedGenre = 'All';
  String _selectedStatus = 'All';
  String _selectedDecade = 'All';

  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _historyLog = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await ApiService.getWatchHistory();
      if (mounted) {
        setState(() {
          _historyLog = data;
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

  // --- Combined Filter Logic ---
  List<dynamic> get _filteredHistory {
    return _historyLog.where((item) {
      final String rawType = (item['type'] ?? item['media_type'] ?? '').toString().toLowerCase();
      final bool isTv = rawType == 'show' || rawType == 'tv';

      // 1. Trakt Media Type Filter
      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'movies' && isTv) return false;

      // 2. Sidebar Genre Filter
      if (_selectedGenre != 'All') {
        final List<dynamic> genreIds = item['genre_ids'] ?? [];
        final targetGenreId = FilterDrawer.genreMap[_selectedGenre];
        if (targetGenreId != null && !genreIds.contains(targetGenreId)) return false;
      }

      // 3. Sidebar Status Filter
      if (_selectedStatus != 'All') {
        final dateStr = item['watchedDate'] ?? item['watched_date'] ?? item['release_date'] ?? '';
        final isUpcoming = dateStr.isNotEmpty && (DateTime.tryParse(dateStr)?.isAfter(DateTime.now()) ?? false);
        if (_selectedStatus == 'Upcoming' && !isUpcoming) return false;
        if (_selectedStatus == 'Released' && isUpcoming) return false;
      }

      // 4. Sidebar Decade Filter
      if (_selectedDecade != 'All') {
        final dateStr = item['watchedDate'] ?? item['watched_date'] ?? item['release_date'] ?? '';
        final year = DateTime.tryParse(dateStr)?.year;
        if (year != null) {
          if (_selectedDecade == 'This Year' && year != 2026) return false;
          if (_selectedDecade == '2020s' && (year < 2020 || year > 2029)) return false;
          if (_selectedDecade == '2010s' && (year < 2010 || year > 2019)) return false;
          if (_selectedDecade == '2000s' && (year < 2000 || year > 2009)) return false;
          if (_selectedDecade == 'Before 1960' && year >= 1960) return false;
        }
      }

      return true;
    }).toList();
  }

  bool get _hasActiveSidebarFilters =>
      _selectedGenre != 'All' || _selectedStatus != 'All' || _selectedDecade != 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredHistory;

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
            // ── STICKY TOP HEADER BAR (REMAINS VISIBLE WHEN SCROLLING) ────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Watch History',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${filtered.length} Items',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Sticky Trakt Capsule
                  TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
                  ),
                  const SizedBox(width: 8),

                  // Sticky Sidebar Filter Trigger Button
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

            const SizedBox(height: 4),

            // ── SCROLLABLE TIMELINE CONTENT ─────────────────────────────────
            Expanded(
              child: _isLoading
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
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No $_selectedFilter recorded in history matching criteria.',
                                style: const TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchHistory,
                              color: const Color(0xFFA855F7),
                              backgroundColor: const Color(0xFF131316),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final int id = item['movie_id'] ?? item['id'] ?? 0;
                                  final String rawType = (item['type'] ?? item['media_type'] ?? '').toString().toLowerCase();
                                  final bool isShow = rawType == 'show' || rawType == 'tv';

                                  final String posterUrl = item['poster'] ?? item['poster_path'] ?? '';
                                  final String imageUrl = posterUrl.isNotEmpty
                                      ? (posterUrl.startsWith('http')
                                          ? posterUrl
                                          : 'https://image.tmdb.org/t/p/w500$posterUrl')
                                      : '';

                                  final String watchedDate = item['watchedDate'] ?? item['watched_date'] ?? 'Recently';
                                  final String watchedTime = item['watchedTime'] ?? '';

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF131316),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(12),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: AspectRatio(
                                          aspectRatio: 2 / 3,
                                          child: Container(
                                            color: const Color(0xFF1E293B),
                                            child: imageUrl.isNotEmpty
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) => const Icon(
                                                      Icons.movie_rounded,
                                                      color: Colors.white24,
                                                      size: 24,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.movie_rounded,
                                                    color: Colors.white24,
                                                    size: 24,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        item['title'] ?? 'Untitled',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (isShow && item['subtitle'] != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item['subtitle'],
                                              style: const TextStyle(
                                                color: Color(0xFFA855F7),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time_rounded,
                                                color: Colors.white38,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                watchedTime.isNotEmpty
                                                    ? '$watchedDate at $watchedTime'
                                                    : watchedDate,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (item['userRating'] != null || item['rating'] != null)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  color: Color(0xFFFFB800),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${item['userRating'] ?? item['rating']}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 8),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Colors.white24,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        if (isShow) {
                                          context.go('/tv/$id');
                                        } else {
                                          context.go('/movie/$id');
                                        }
                                      },
                                    ),
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
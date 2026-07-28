// frontend/lib/screens/calendar_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  // Key: "YYYY-MM-DD", Value: List of items releasing on that date
  Map<String, List<dynamic>> _dateReleaseMap = {};
  List<DateTime> _releaseDates = []; // Sorted list of unique dates with releases
  DateTime _selectedDate = DateTime.now();

  final ScrollController _stripScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  @override
  void dispose() {
    _stripScrollController.dispose();
    super.dispose();
  }

  // Load releases across multiple pages
  Future<void> _loadCalendarData() async {
    try {
      final results = await Future.wait([
        ApiService.getUpcomingMedia(),
        ApiService.getDiscoverMedia(category: 'releases', page: 1),
        ApiService.getDiscoverMedia(category: 'releases', page: 2),
      ]);

      Map<String, List<dynamic>> tempMap = {};

      for (var res in results) {
        final list = (res['results'] as List<dynamic>?) ?? [];
        for (var item in list) {
          final dateStr = item['release_date'] ?? item['first_air_date'];
          if (dateStr != null && dateStr.toString().trim().isNotEmpty) {
            final key = dateStr.toString().substring(0, 10); // 'YYYY-MM-DD'
            tempMap.putIfAbsent(key, () => []);
            
            // Avoid duplicate items per date
            if (!tempMap[key]!.any((existing) => existing['id'] == item['id'])) {
              tempMap[key]!.add(item);
            }
          }
        }
      }

      // Sort release dates chronologically
      List<DateTime> sortedDates = tempMap.keys
          .map((k) => DateTime.parse(k))
          .toList()
        ..sort((a, b) => a.compareTo(b));

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Default selected date to today or the closest upcoming/past release date
      DateTime initialSelected = today;
      if (sortedDates.isNotEmpty) {
        initialSelected = sortedDates.firstWhere(
          (d) => d.isAfter(today.subtract(const Duration(days: 1))),
          orElse: () => sortedDates.last,
        );
      }

      if (mounted) {
        setState(() {
          _dateReleaseMap = tempMap;
          _releaseDates = sortedDates;
          _selectedDate = initialSelected;
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

  // ⏩ Smart Jump Next: Skips days without releases
  void _jumpToNextRelease() {
    if (_releaseDates.isEmpty) return;
    final next = _releaseDates.firstWhere(
      (d) => _isAfterDay(d, _selectedDate),
      orElse: () => _selectedDate,
    );
    setState(() => _selectedDate = next);
  }

  // ⏪ Smart Jump Previous: Skips days without releases
  void _jumpToPreviousRelease() {
    if (_releaseDates.isEmpty) return;
    final prev = _releaseDates.lastWhere(
      (d) => _isBeforeDay(d, _selectedDate),
      orElse: () => _selectedDate,
    );
    setState(() => _selectedDate = prev);
  }

  // Jump to Today
  void _jumpToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_dateReleaseMap.containsKey(_formatDateKey(today))) {
      setState(() => _selectedDate = today);
    } else if (_releaseDates.isNotEmpty) {
      // Nearest date with releases
      final closest = _releaseDates.firstWhere(
        (d) => d.isAfter(today.subtract(const Duration(days: 1))),
        orElse: () => _releaseDates.last,
      );
      setState(() => _selectedDate = closest);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isBeforeDay(DateTime a, DateTime b) {
    final dayA = DateTime(a.year, a.month, a.day);
    final dayB = DateTime(b.year, b.month, b.day);
    return dayA.isBefore(dayB);
  }

  bool _isAfterDay(DateTime a, DateTime b) {
    final dayA = DateTime(a.year, a.month, a.day);
    final dayB = DateTime(b.year, b.month, b.day);
    return dayA.isAfter(dayB);
  }

  String _formatDateKey(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // Relative Date Badge (e.g., "In 3 days", "Today", "Yesterday")
  String _getRelativeDateText(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1) return 'In $diff days';
    if (diff == -1) return 'Yesterday';
    return '${diff.abs()} days ago';
  }

  // Ordinal Date Header (e.g., "July 31st, 2026")
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

  @override
  Widget build(BuildContext context) {
    final currentKey = _formatDateKey(_selectedDate);
    final selectedItems = _dateReleaseMap[currentKey] ?? [];

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
            Icon(Icons.calendar_today_rounded, color: Color(0xFFB57EDC), size: 20),
            SizedBox(width: 8),
            Text(
              'Calendar',
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
                        // 🗓️ 1. Trakt.tv Date Strip Card Container
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0),
                          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131316),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              // Top Controls: Prev [<] | Today | Next [>]
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                                    onPressed: _jumpToPreviousRelease,
                                    tooltip: 'Previous Release Date',
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
                                    onPressed: _jumpToNextRelease,
                                    tooltip: 'Next Release Date',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Date Bar Strip (-14 days to +14 days window around selected)
                              SizedBox(
                                height: 80,
                                child: ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(context).copyWith(
                                    dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                                  ),
                                  child: ListView.builder(
                                    controller: _stripScrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 29, // 14 days before, selected, 14 days after
                                    itemBuilder: (context, index) {
                                      final date = _selectedDate.add(Duration(days: index - 14));
                                      final isSelected = _isSameDay(date, _selectedDate);
                                      final dateKey = _formatDateKey(date);
                                      final hasReleases = _dateReleaseMap.containsKey(dateKey) &&
                                          _dateReleaseMap[dateKey]!.isNotEmpty;

                                      final List<String> months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                                      final List<String> days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedDate = date);
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 52,
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF26262F) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            border: isSelected
                                                ? Border.all(color: const Color(0xFFB57EDC).withValues(alpha: 0.5))
                                                : null,
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                months[date.month - 1],
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${date.day}',
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : Colors.white70,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                days[date.weekday - 1],
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),

                                              // Indicator Dot for Releases
                                              Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: hasReleases
                                                      ? (isSelected ? const Color(0xFF38BDF8) : const Color(0xFFB57EDC))
                                                      : Colors.transparent,
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
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 📅 2. Selected Date Header (e.g. "July 31st, 2026")
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            _getFormattedHeaderDate(_selectedDate),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 🎬 3. Media Grid for Selected Date
                        if (selectedItems.isEmpty)
                          Container(
                            height: 140,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131316),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Center(
                              child: Text(
                                'No releases on this date',
                                style: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              childAspectRatio: 1.25, // Landscape 16:9 aspect ratio
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 18,
                            ),
                            itemCount: selectedItems.length,
                            itemBuilder: (context, index) {
                              final item = selectedItems[index];
                              final id = item['id'];
                              final title = item['title'] ?? item['name'] ?? 'Untitled';
                              final mediaType = item['media_type'] ?? (item['name'] != null ? 'tv' : 'movie');

                              final imagePath = item['backdrop_path'] ?? item['poster_path'];
                              final imageUrl = (imagePath != null && imagePath.toString().trim().isNotEmpty)
                                  ? 'https://image.tmdb.org/t/p/w500$imagePath'
                                  : '';

                              final relativeBadge = _getRelativeDateText(_selectedDate);
                              final subtitleText = mediaType == 'tv' ? 'TV Show' : 'Movie';

                              return MovieCard(
                                id: id,
                                title: title,
                                imageUrl: imageUrl,
                                mediaType: mediaType,
                                isLandscape: true,
                                subtitle: subtitleText,
                                overlayLeftText: relativeBadge,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
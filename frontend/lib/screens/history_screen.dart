// frontend/lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/trakt_filter_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'media';

  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _historyLog = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  String? get _apiMediaType {
    if (_selectedFilter == 'shows') return 'tv';
    if (_selectedFilter == 'movies') return 'movie';
    return null;
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await ApiService.getWatchHistory(_apiMediaType);
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

  Future<void> _removeFromHistory(dynamic item) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final int index = _historyLog.indexOf(item);
    
    setState(() => _historyLog.remove(item));
    
    try {
      final historyId = item['history_id'] ?? item['id'] ?? 0;
      await ApiService.removeWatchHistory(historyId);
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Removed from history', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _historyLog.insert(index, item));
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to remove: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<dynamic> get _filteredHistory {
    return _historyLog.where((item) {
      final String rawType = (item['type'] ?? item['media_type'] ?? '').toString().toLowerCase();
      final bool isTv = rawType == 'show' || rawType == 'tv' || item['subtitle'] != null;

      if (_selectedFilter == 'shows' && !isTv) return false;
      if (_selectedFilter == 'movies' && isTv) return false;

      return true;
    }).toList();
  }

  Map<String, List<dynamic>> get _groupedHistory {
    final Map<String, List<dynamic>> grouped = {};
    
    for (var item in _filteredHistory) {
      final String rawDate = item['watchedDate'] ?? item['watched_date'] ?? item['release_date'] ?? '';
      String dateLabel = 'Unknown Date';
      
      if (rawDate.isNotEmpty) {
        try {
          final DateTime dt = DateTime.parse(rawDate);
          dateLabel = DateFormat('MMMM d, yyyy').format(dt); 
        } catch (_) {
          dateLabel = rawDate;
        }
      }
      
      if (!grouped.containsKey(dateLabel)) {
        grouped[dateLabel] = [];
      }
      grouped[dateLabel]!.add(item);
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupedHistory;
    final groupKeys = groupedData.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Column(
          children: [
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
                        '${_filteredHistory.length} Items',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TraktFilterBar(
                    selectedFilter: _selectedFilter,
                    showPeople: false,
                    onFilterChanged: (filter) {
                      if (_selectedFilter != filter) {
                        setState(() => _selectedFilter = filter);
                        _fetchHistory();
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

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
                      : _filteredHistory.isEmpty
                          ? Center(
                              child: Text(
                                'No $_selectedFilter recorded in history.',
                                style: const TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchHistory,
                              color: const Color(0xFFA855F7),
                              backgroundColor: const Color(0xFF131316),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: groupKeys.length,
                                itemBuilder: (context, index) {
                                  final dateLabel = groupKeys[index];
                                  final items = groupedData[dateLabel]!;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
                                        child: Text(
                                          dateLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: items.map((item) => _buildHistoryCard(item, dateLabel)).toList(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
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

  Widget _buildHistoryCard(dynamic item, String dateLabel) {
    final rawId = item['movie_id'] ?? item['id'] ?? 0;
    final int id = int.tryParse(rawId.toString()) ?? 0;
    final String title = item['movie_title'] ?? item['title'] ?? 'Untitled';
    
    final String rawType = (item['type'] ?? item['media_type'] ?? '').toString().toLowerCase();
    final bool isShow = rawType == 'show' || rawType == 'tv' || item['subtitle'] != null;

    final String imagePath = item['poster'] ?? item['poster_path'] ?? item['backdrop'] ?? item['backdrop_path'] ?? '';
    final String imageUrl = imagePath.isNotEmpty
        ? (imagePath.startsWith('http') ? imagePath : 'https://image.tmdb.org/t/p/w500$imagePath')
        : '';

    final String watchedTime = item['watchedTime'] ?? '12:00 AM';

    return GestureDetector(
      onTap: () {
        if (isShow) {
          context.go('/tv/$id');
        } else {
          context.go('/movie/$id');
        }
      },
      child: Container(
        width: 280, 
        height: 160, 
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C22), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: const Color(0xFF131316)),
                      )
                    : Container(color: const Color(0xFF131316)),
              ),
              
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF131316).withValues(alpha: 0.8),
                        const Color(0xFF131316),
                        const Color(0xFF131316),
                      ],
                      stops: const [0.0, 0.4, 0.5, 1.0], 
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 105, 
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_rounded, color: Colors.white24, size: 40),
                      )
                    : const Icon(Icons.image_not_supported_rounded, color: Colors.white24, size: 40),
              ),

              Positioned(
                left: 116, 
                top: 12,
                bottom: 12,
                right: 32, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    Text(
                      watchedTime,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),

              Positioned(
                right: 0,
                top: 4,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                  color: const Color(0xFF131316),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  onSelected: (value) {
                    if (value == 'remove') {
                      _removeFromHistory(item);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Remove from history', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
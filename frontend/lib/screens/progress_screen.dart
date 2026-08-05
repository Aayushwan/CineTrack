// frontend/lib/screens/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _progressItems = [];

  @override
  void initState() {
    super.initState();
    _fetchProgressData();
  }

  Future<void> _fetchProgressData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Fetch active TV shows and in-progress media
      final data = await ApiService.getTrendingMovies(type: 'tv');
      final results = (data['results'] as List<dynamic>?) ?? [];

      if (mounted) {
        setState(() {
          _progressItems = results;
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'In Progress',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFA855F7)),
              )
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
                  )
                : _progressItems.isEmpty
                    ? const Center(
                        child: Text(
                          'No media currently in progress',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchProgressData,
                        color: const Color(0xFFA855F7),
                        backgroundColor: const Color(0xFF131316),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          itemCount: _progressItems.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final item = _progressItems[index];
                            final int id = item['id'] ?? 0;
                            final String title = item['name'] ?? item['title'] ?? 'Untitled';
                            
                            // Normalize media type
                            final String rawType = (item['media_type'] ?? '').toString().toLowerCase();
                            final bool isTv = rawType == 'tv' || rawType == 'show' || item['name'] != null;
                            final mediaType = isTv ? 'tv' : 'movie';

                            final backdropPath = item['backdrop_path'] ?? item['poster_path'];
                            final imageUrl = (backdropPath != null && backdropPath.toString().trim().isNotEmpty)
                                ? 'https://image.tmdb.org/t/p/w500$backdropPath'
                                : '';

                            final double progressVal = (0.2 + (index * 0.15)).clamp(0.1, 0.9);
                            final int episodeNum = (index % 10) + 1;
                            final String subtitle = isTv
                                ? 'S1 • E$episodeNum - Episode $episodeNum'
                                : 'Movie • ${(progressVal * 100).toInt()}% watched';

                            return GestureDetector(
                              onTap: () {
                                if (isTv) {
                                  context.go('/tv/$id');
                                } else {
                                  context.go('/movie/$id');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131316),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    // Poster / Backdrop Thumbnail
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 110,
                                        height: 70,
                                        color: const Color(0xFF1E293B),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => const Icon(
                                                  Icons.tv_rounded,
                                                  color: Colors.white24,
                                                  size: 30,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.tv_rounded,
                                                color: Colors.white24,
                                                size: 30,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Content Info & Progress Bar
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white10,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  mediaType.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Color(0xFFA855F7),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Linear Progress Indicator Bar
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: progressVal,
                                              minHeight: 4,
                                              backgroundColor: Colors.white10,
                                              valueColor: const AlwaysStoppedAnimation<Color>(
                                                Color(0xFFA855F7),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Color(0xFFA855F7),
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
// frontend/lib/screens/show_details_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../models/review.dart';

class ShowDetailsScreen extends StatefulWidget {
  final int showId;

  const ShowDetailsScreen({super.key, required this.showId});

  @override
  State<ShowDetailsScreen> createState() => _ShowDetailsScreenState();
}

class _ShowDetailsScreenState extends State<ShowDetailsScreen> {
  bool _isLoading = true;
  bool _isLogging = false;
  String _errorMessage = '';
  Map<String, dynamic>? _showDetails;
  List<Review> _reviews = [];
  
  List<dynamic> _episodes = [];
  // 👇 State variable to track the currently selected season
  int _currentSeason = 1;

  @override
  void initState() {
    super.initState();
    _fetchShowDetails();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WatchlistProvider>(context, listen: false).fetchCustomLists();
    });
  }

  Future<void> _fetchShowDetails() async {
    try {
      final details = await ApiService.getTvDetails(widget.showId);
      
      List<Review> fetchedReviews = [];
      try {
        fetchedReviews = await ApiService.getMovieReviews(widget.showId);
      } catch (_) {}

      List<dynamic> fetchedEpisodes = [];
      try { 
        // 👇 Fetch the currently selected season (defaults to 1)
        fetchedEpisodes = await ApiService.getTvSeasonDetails(widget.showId, _currentSeason); 
      } catch (_) {}

      if (mounted) {
        setState(() {
          _showDetails = details;
          _reviews = fetchedReviews;
          _episodes = fetchedEpisodes;
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

  // ─── Watched Menu Logic ──────────────────────────────────────────────────
  Future<void> _markAsWatched(String title, String? poster, int episodes, String option, {String? releaseDateStr}) async {
    Navigator.pop(context); 
    if (_isLogging) return;
    setState(() => _isLogging = true);

    DateTime? watchedAtDate;
    if (option == 'Just now') {
      watchedAtDate = DateTime.now().toUtc();
    } else if (option == 'Release date' && releaseDateStr != null && releaseDateStr.isNotEmpty) {
      try { watchedAtDate = DateTime.parse(releaseDateStr).toUtc(); } catch (_) { watchedAtDate = DateTime.now().toUtc(); }
    } else if (option == 'Other date') {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900), 
        lastDate: DateTime.now(), 
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFA855F7), 
                onPrimary: Colors.white,
                surface: Color(0xFF131316),
                onSurface: Colors.white,
              ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF131316)),
            ),
            child: child!,
          );
        },
      );
      if (pickedDate == null) {
        if (mounted) setState(() => _isLogging = false);
        return;
      }
      watchedAtDate = pickedDate.toUtc();
    } else if (option == 'Unknown date') {
      watchedAtDate = DateTime.utc(1970, 1, 1); 
    }

    try {
      await ApiService.logWatchHistory(
        movieId: widget.showId,
        mediaType: 'tv',
        title: title,
        posterPath: poster,
        runtimeMinutes: 45,
        userRating: 0.0,
        watchedAt: watchedAtDate?.toIso8601String(),
      );
      _showSnackBar('Marked "$title" as Watched!');
    } catch (e) {
      _showSnackBar('Failed to log watch history: $e');
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  void _showMarkWatchedMenu(String title, String? poster, int episodes, String? releaseDate) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: const Color(0xFF131316),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white54, size: 20)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
              _buildMenuOption(Icons.check_rounded, 'Just now', () => _markAsWatched(title, poster, episodes, 'Just now')),
              _buildMenuOption(Icons.calendar_today_outlined, 'Release date', () => _markAsWatched(title, poster, episodes, 'Release date', releaseDateStr: releaseDate)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1)),
              _buildMenuOption(Icons.edit_outlined, 'Other date', () => _markAsWatched(title, poster, episodes, 'Other date')),
              _buildMenuOption(Icons.help_outline_rounded, 'Unknown date', () => _markAsWatched(title, poster, episodes, 'Unknown date')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── Custom Lists Menu ───────────────────────────────────────────────────
  void _showMoreOptions(WatchlistProvider provider, String? posterPath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add to Custom List', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              if (provider.customLists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No custom lists found. Create one in the Lists tab!', style: TextStyle(color: Colors.white54)),
                )
              else
                ...provider.customLists.map((listData) {
                  int listId = listData['id'];
                  String listTitle = listData['name'] ?? listData['title'] ?? 'Untitled';
                  return _buildMenuOption(Icons.playlist_add_rounded, listTitle, () {
                    provider.addMediaToList(listId, widget.showId, posterPath);
                    Navigator.pop(context);
                    _showSnackBar('Added to "$listTitle"');
                  });
                }),
            ],
          ),
        );
      },
    );
  }

  // ─── Season Episodes Bottom Sheet ────────────────────────────────────────
  void _showSeasonEpisodesModal(String fallbackBackdrop) {
    // 👇 Extract available seasons safely from TMDB response
    final seasons = (_showDetails!['seasons'] as List<dynamic>?)?.where((s) => s['season_number'] != null).toList() ?? [];
    bool isFetchingSeason = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        // StatefulBuilder allows us to refresh the modal when a new season is clicked
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 👇 Interactive Seasons Popup Menu
                          PopupMenuButton<int>(
                            color: const Color(0xFF1E1E24),
                            initialValue: _currentSeason,
                            onSelected: (int selectedSeason) async {
                              if (selectedSeason == _currentSeason) return;
                              
                              setModalState(() => isFetchingSeason = true);
                              
                              List<dynamic> newEpisodes = [];
                              try {
                                newEpisodes = await ApiService.getTvSeasonDetails(widget.showId, selectedSeason);
                              } catch (_) {}
                              
                              // Update the background screen state
                              setState(() {
                                _currentSeason = selectedSeason;
                                _episodes = newEpisodes;
                              });
                              
                              // Update the modal's internal state
                              setModalState(() => isFetchingSeason = false);
                            },
                            itemBuilder: (context) {
                              return seasons.map((season) {
                                final sNum = season['season_number'];
                                return PopupMenuItem<int>(
                                  value: sNum,
                                  child: Text(season['name'] ?? 'Season $sNum', style: const TextStyle(color: Colors.white)),
                                );
                              }).toList();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E24),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  const Text('Season', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Text('$_currentSeason', style: const TextStyle(color: Colors.white, fontSize: 15)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                                ],
                              ),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Episodes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${_episodes.length} eps.', style: const TextStyle(color: Color(0xFFA855F7), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                    
                    Expanded(
                      child: isFetchingSeason
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFA855F7)))
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(20),
                            itemCount: _episodes.length,
                            separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 32),
                            itemBuilder: (context, index) {
                              final episode = _episodes[index];
                              final epStill = episode['still_path'];
                              
                              final imgUrl = epStill != null 
                                  ? 'https://image.tmdb.org/t/p/w300$epStill' 
                                  : (fallbackBackdrop.isNotEmpty ? fallbackBackdrop : 'https://via.placeholder.com/300x170?text=No+Image');
                              final epNumber = episode['episode_number'] ?? index + 1;
                              
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(imgUrl, width: 140, height: 78, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          episode['name'] ?? 'Episode $epNumber',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('S$_currentSeason • E$epNumber', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFF1E1E24), borderRadius: BorderRadius.circular(4)),
                                          child: Text('${episode['runtime'] ?? 45}m', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                                      const SizedBox(height: 16),
                                      Icon(Icons.check_rounded, color: const Color(0xFFA855F7).withValues(alpha: 0.5), size: 22),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Reviews & Trailer ───────────────────────────────────────────────────
  void _showAddReviewDialog() {
    final TextEditingController reviewController = TextEditingController();
    double currentRating = 5.0;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Review', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rating:', style: TextStyle(color: Colors.white70)),
                      Text('${currentRating.toInt()}/10', style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(value: currentRating, min: 1, max: 10, divisions: 9, activeColor: const Color(0xFFA855F7), onChanged: (val) => setDialogState(() => currentRating = val)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewController, maxLines: 4, style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(hintText: 'Write your thoughts...', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: const Color(0xFF131316), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            await ApiService.postReview(movieId: widget.showId, rating: currentRating, comment: reviewController.text);
                            if (!context.mounted) return;
                            Navigator.pop(context); 
                            _fetchShowDetails(); 
                            _showSnackBar('Review added successfully!');
                          } catch (e) {
                            if (!context.mounted) return;
                            _showSnackBar('Failed to post review');
                            setDialogState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7)),
                  child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _launchTrailer() async {
    final videos = _showDetails!['videos']?['results'] as List<dynamic>?;
    if (videos != null && videos.isNotEmpty) {
      final trailer = videos.firstWhere((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer', orElse: () => videos.first);
      final url = Uri.parse('https://www.youtube.com/watch?v=${trailer['key']}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }
    _showSnackBar('No trailer available');
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF131316), behavior: SnackBarBehavior.floating));
  }

  // ─── Build Method ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF09090B), body: Center(child: CircularProgressIndicator(color: Color(0xFFA855F7))));
    if (_errorMessage.isNotEmpty || _showDetails == null) return Scaffold(backgroundColor: const Color(0xFF09090B), appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.canPop() ? context.pop() : context.go('/'))), body: Center(child: Text(_errorMessage.isNotEmpty ? _errorMessage : 'Failed to load show details', style: const TextStyle(color: Colors.redAccent))));

    final name = _showDetails!['name'] ?? 'Untitled Show';
    final backdropPath = _showDetails!['backdrop_path'];
    final posterPath = _showDetails!['poster_path'];
    final overview = _showDetails!['overview'] ?? 'No overview available.';
    final firstAirDate = _showDetails!['first_air_date'] ?? '';
    final releaseYear = firstAirDate.length >= 4 ? firstAirDate.substring(0, 4) : '';
    final voteAverage = (_showDetails!['vote_average'] ?? 0.0).toStringAsFixed(1);
    final status = _showDetails!['status'] ?? 'Unknown';
    final numberOfEpisodes = _showDetails!['number_of_episodes'] ?? 0;
    final genres = (_showDetails!['genres'] as List<dynamic>?)?.map((g) => g['name'].toString()).toList() ?? [];
    final cast = (_showDetails!['credits']?['cast'] as List<dynamic>?) ?? [];
    final creator = (_showDetails!['created_by'] as List<dynamic>?)?.isNotEmpty == true ? _showDetails!['created_by'][0]['name'] : 'Unknown Creator';
    
    final backdropUrl = backdropPath != null ? 'https://image.tmdb.org/t/p/w1280$backdropPath' : '';
    final posterUrl = posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '';

    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    final currentStatus = watchlistProvider.getMediaStatus(widget.showId, mediaType: 'tv');
    final isWatchlist = currentStatus == 'watchlist';
    final isFavorite = currentStatus == 'favorite';

    final bool isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // Background Backdrop Layer
          if (backdropUrl.isNotEmpty) Positioned.fill(child: Image.network(backdropUrl, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: const Color(0xFF09090B).withValues(alpha: 0.85))), 
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(color: Colors.transparent))),
          
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Responsive Header Section
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPoster(posterUrl),
                              const SizedBox(width: 40),
                              Expanded(child: _buildDetailsColumn(name, creator, releaseYear, numberOfEpisodes, genres, status, overview, posterPath, voteAverage, firstAirDate, isWatchlist, isFavorite, watchlistProvider)),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: _buildPoster(posterUrl)),
                              const SizedBox(height: 24),
                              _buildDetailsColumn(name, creator, releaseYear, numberOfEpisodes, genres, status, overview, posterPath, voteAverage, firstAirDate, isWatchlist, isFavorite, watchlistProvider),
                            ],
                          ),
                        const SizedBox(height: 48),

                        if (_episodes.isNotEmpty) ...[
                          InkWell(
                            onTap: () => _showSeasonEpisodesModal(backdropUrl),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  // 👇 Updated Header text dynamically
                                  Text('Seasons / Season $_currentSeason', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          SizedBox(
                            height: 180,
                            // 👇 ScrollConfiguration enables mouse dragging on web
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                              ),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _episodes.length,
                                itemBuilder: (context, index) {
                                  final episode = _episodes[index];
                                  final epStill = episode['still_path'];
                                  final imgUrl = epStill != null 
                                      ? 'https://image.tmdb.org/t/p/w300$epStill' 
                                      : (backdropUrl.isNotEmpty ? backdropUrl : 'https://via.placeholder.com/300x170?text=No+Image');
                                  
                                  final epName = episode['name'] ?? 'Episode ${index + 1}';
                                  final epRuntime = episode['runtime'] ?? 45;
                                  final epNumber = episode['episode_number'] ?? index + 1;

                                  return Container(
                                    width: 240, 
                                    margin: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(imgUrl, height: 135, width: 240, fit: BoxFit.cover),
                                            ),
                                            Positioned(
                                              bottom: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                                                child: Text('${epRuntime}m', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                            const Positioned(
                                              top: 8, right: 8,
                                              child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                epName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const Icon(Icons.check_rounded, color: Color(0xFFA855F7), size: 18),
                                          ],
                                        ),
                                        Text('S$_currentSeason - E$epNumber', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Actors Strip
                        if (cast.isNotEmpty) ...[
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Actors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              Icon(Icons.chevron_right_rounded, color: Colors.white),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            // 👇 ScrollConfiguration enables mouse dragging on web
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                              ),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: cast.length,
                                itemBuilder: (context, index) {
                                  final person = cast[index];
                                  final personId = person['id'];
                                  final personName = person['name'] ?? '';
                                  final character = person['character'] ?? '';
                                  final profilePath = person['profile_path'];
                                  final profileUrl = profilePath != null ? 'https://image.tmdb.org/t/p/w185$profilePath' : '';

                                  return GestureDetector(
                                    onTap: () => context.go('/person/$personId'),
                                    child: Container(
                                      width: 105,
                                      margin: const EdgeInsets.only(right: 14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: profileUrl.isNotEmpty
                                                ? Image.network(profileUrl, height: 140, width: 105, fit: BoxFit.cover)
                                                : Container(height: 140, width: 105, color: const Color(0xFF1E1E24), child: const Icon(Icons.person_rounded, color: Colors.white24, size: 40)),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            personName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            character,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Reviews Strip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            TextButton.icon(
                              onPressed: _showAddReviewDialog,
                              icon: const Icon(Icons.add_rounded, color: Color(0xFFA855F7), size: 18),
                              label: const Text('Add Review', style: TextStyle(color: Color(0xFFA855F7))),
                              style: TextButton.styleFrom(backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.1)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _reviews.isEmpty
                            ? const Text('No reviews yet for this show.', style: TextStyle(color: Colors.white54, fontSize: 14))
                            : SizedBox(
                                height: 160,
                                // 👇 ScrollConfiguration enables mouse dragging on web
                                child: ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(context).copyWith(
                                    dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                                  ),
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _reviews.length,
                                    itemBuilder: (context, index) {
                                      final review = _reviews[index];
                                      final authorLetter = review.username.isNotEmpty ? review.username[0].toUpperCase() : '?';
                                      
                                      return Container(
                                        width: 280,
                                        margin: const EdgeInsets.only(right: 16),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF131316),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.2),
                                                  child: Text(authorLetter, style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(child: Text(review.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star_rounded, color: Color(0xFFA855F7), size: 12),
                                                    const SizedBox(width: 4),
                                                    Text('${review.rating}/10', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                                  ],
                                                )
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Expanded(
                                              child: Text(
                                                review.comment ?? '', 
                                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoster(String posterUrl) {
    if (posterUrl.isEmpty) {
      return Container(width: 280, height: 420, decoration: BoxDecoration(color: const Color(0xFF131316), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 60));
    }
    return Stack(
      children: [
        Container(
          width: 280,
          height: 420,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(image: NetworkImage(posterUrl), fit: BoxFit.cover),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, offset: const Offset(0, 8))],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsColumn(
    String title, String creator, String releaseYear, int eps, List<String> genres, String status, 
    String overview, String? posterPath, String voteAverage, String firstAirDate, 
    bool isWatchlist, bool isFavorite, WatchlistProvider watchlistProvider
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1))),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(children: [Text('Where to Watch', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), SizedBox(width: 4), Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 10)]),
                SizedBox(height: 8),
                Text('JustWatch', style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Created by $creator', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (releaseYear.isNotEmpty) Text(releaseYear, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            Text('•  $eps eps', style: const TextStyle(color: Colors.white54, fontSize: 14)),
            if (genres.isNotEmpty) Text('•  ${genres.join(", ")}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Text(status, style: const TextStyle(color: Color(0xFFA855F7), fontSize: 14, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFA855F7), size: 16),
            const SizedBox(width: 4),
            Text('$voteAverage%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 16),
            Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.yellow[700], borderRadius: BorderRadius.circular(2)), child: const Text('IMDb', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold))),
            const SizedBox(width: 4),
            Text(voteAverage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 28),
        Text(overview, style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 15)),
        const SizedBox(height: 32),
        Row(
          children: [
            InkWell(
              onTap: () => _showMarkWatchedMenu(title, posterPath, eps, firstAirDate),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFF1E1B26), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3))),
                child: _isLogging 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFA855F7), strokeWidth: 2))
                    : const Icon(Icons.check_rounded, color: Color(0xFFA855F7), size: 20),
              ),
            ),
            const SizedBox(width: 12),
            _buildIconButton(
              icon: Icons.list_alt_rounded,
              isActive: false,
              onTap: () => _showMoreOptions(watchlistProvider, posterPath),
            ),
            const SizedBox(width: 12),
            _buildIconButton(
              icon: isWatchlist ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
              isActive: isWatchlist,
              onTap: () async {
                if (isWatchlist) {
                  await watchlistProvider.removeFromWatchlist(widget.showId, mediaType: 'tv');
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                } else {
                  await watchlistProvider.addToWatchlist(movieId: widget.showId, movieTitle: title, posterPath: posterPath, status: 'watchlist', mediaType: 'tv', releaseYear: releaseYear, totalEpisodes: eps, voteAverage: double.tryParse(voteAverage) ?? 0.0);
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                }
              },
            ),
            const SizedBox(width: 12),
            _buildIconButton(
              icon: Icons.play_circle_outline_rounded,
              isActive: false,
              onTap: _launchTrailer,
            ),
            const SizedBox(width: 12),
            _buildIconButton(
              icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              isActive: isFavorite,
              activeColor: Colors.redAccent,
              onTap: () async {
                if (isFavorite) {
                  await watchlistProvider.removeFromWatchlist(widget.showId, mediaType: 'tv');
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Favorite', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                } else {
                  await watchlistProvider.addToWatchlist(movieId: widget.showId, movieTitle: title, posterPath: posterPath, status: 'favorite', mediaType: 'tv', releaseYear: releaseYear, totalEpisodes: eps, voteAverage: double.tryParse(voteAverage) ?? 0.0);
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Favorite', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required bool isActive, required VoidCallback onTap, Color activeColor = const Color(0xFFA855F7)}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF131316),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? activeColor.withValues(alpha: 0.5) : Colors.white10),
        ),
        child: Icon(icon, color: isActive ? activeColor : Colors.white, size: 22),
      ),
    );
  }
}
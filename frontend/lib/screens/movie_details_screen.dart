// frontend/lib/screens/movie_details_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../models/review.dart';

class MovieDetailsScreen extends StatefulWidget {
  final int movieId;

  const MovieDetailsScreen({super.key, required this.movieId});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isLoading = true;
  bool _isLogging = false;
  Map<String, dynamic>? _movieData;
  List<Review> _reviews = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WatchlistProvider>(context, listen: false).fetchCustomLists();
    });
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await ApiService.getMovieDetails(widget.movieId);
      
      List<Review> fetchedReviews = [];
      try {
        fetchedReviews = await ApiService.getMovieReviews(widget.movieId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _movieData = details;
          _reviews = fetchedReviews;
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
  Future<void> _markAsWatched(String title, String? poster, int runtime, String option, {String? releaseDateStr}) async {
    Navigator.pop(context); 
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    if (_isLogging) return;
    setState(() => _isLogging = true);

    DateTime? watchedAtDate;

    if (option == 'Just now') {
      watchedAtDate = DateTime.now().toUtc();
    } else if (option == 'Release date') {
      if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
        try { watchedAtDate = DateTime.parse(releaseDateStr).toUtc(); } catch (_) { watchedAtDate = DateTime.now().toUtc(); }
      } else {
        watchedAtDate = DateTime.now().toUtc();
      }
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
              ),
              dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF131316)),
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
    }

    try {
      await ApiService.logWatchHistory(
        movieId: widget.movieId,
        mediaType: 'movie',
        title: title,
        posterPath: poster,
        runtimeMinutes: runtime,
        userRating: 0.0,
        watchedAt: watchedAtDate?.toIso8601String(),
      );
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Marked "$title" as Watched!', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF131316), behavior: SnackBarBehavior.floating));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to log watch history: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  void _showMarkWatchedMenu(String title, String? poster, int runtime, String? releaseDate) {
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
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              _buildMenuOption(Icons.check_rounded, 'Just now', () => _markAsWatched(title, poster, runtime, 'Just now')),
              _buildMenuOption(Icons.calendar_today_rounded, 'Release date', () => _markAsWatched(title, poster, runtime, 'Release date', releaseDateStr: releaseDate)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1)),
              _buildMenuOption(Icons.edit_calendar_rounded, 'Other date', () => _markAsWatched(title, poster, runtime, 'Other date')),
            ],
          ),
        );
      },
    );
  }

  // 👇 UPDATED to accept `title`
  void _showMoreOptions(WatchlistProvider provider, String? posterPath, String title) {
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
                const Padding(padding: EdgeInsets.all(24.0), child: Text('No custom lists found. Create one in the Lists tab!', style: TextStyle(color: Colors.white54)))
              else
                ...provider.customLists.map((listData) {
                  int listId = listData['id'];
                  String listTitle = listData['title'] ?? listData['name'];
                  return _buildMenuOption(Icons.playlist_add_rounded, listTitle, () {
                    // 👇 UPDATED: Passing explicit Movie details
                    provider.addMediaToList(
                      listId, 
                      widget.movieId, 
                      posterPath,
                      title: title,
                      mediaType: 'movie',
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to "$listTitle"', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF131316), behavior: SnackBarBehavior.floating));
                  });
                }),
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
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ─── Where to Watch Logic ──────────────────────────────────────────────────
  void _showWhereToWatchModal(String movieTitle) {
    final results = _movieData!['watch/providers']?['results'] as Map<String, dynamic>? ?? {};
    final providers = results['IN'] ?? results['US'] ?? {}; 
    
    final flatrate = providers['flatrate'] as List<dynamic>? ?? [];
    final rent = providers['rent'] as List<dynamic>? ?? [];
    final buy = providers['buy'] as List<dynamic>? ?? [];

    if (flatrate.isEmpty && rent.isEmpty && buy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No streaming providers available.', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316)));
      return;
    }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Where to Watch', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              
              if (flatrate.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Subscription', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold))),
                ...flatrate.map((p) => _buildProviderTile(p, movieTitle)),
              ],
              if (rent.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Rent', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold))),
                ...rent.map((p) => _buildProviderTile(p, movieTitle)),
              ],
              if (buy.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Buy', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold))),
                ...buy.map((p) => _buildProviderTile(p, movieTitle)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderTile(dynamic provider, String movieTitle) {
    final logoPath = provider['logo_path'];
    final name = provider['provider_name'] ?? 'Unknown';
    final logoUrl = logoPath != null ? 'https://image.tmdb.org/t/p/w92$logoPath' : '';

    return InkWell(
      onTap: () async {
        final query = Uri.encodeComponent('Watch $movieTitle on$name');
        final url = Uri.parse('https://www.google.com/search?q=$query');
        
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch provider link', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E1E24), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: logoUrl.isNotEmpty ? Image.network(logoUrl, width: 40, height: 40, fit: BoxFit.cover) : Container(width: 40, height: 40, color: Colors.black26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    const Text('India', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getTopProviderLogoUrl() {
    if (_movieData == null) return '';
    final results = _movieData!['watch/providers']?['results'] as Map<String, dynamic>? ?? {};
    final providers = results['IN'] ?? results['US'] ?? {};
    
    final flatrate = providers['flatrate'] as List<dynamic>? ?? [];
    if (flatrate.isNotEmpty && flatrate.first['logo_path'] != null) {
      return 'https://image.tmdb.org/t/p/w92${flatrate.first['logo_path']}';
    }
    
    final rent = providers['rent'] as List<dynamic>? ?? [];
    if (rent.isNotEmpty && rent.first['logo_path'] != null) {
      return 'https://image.tmdb.org/t/p/w92${rent.first['logo_path']}';
    }
    
    return '';
  }

  Future<void> _launchTrailerDirectly() async {
    final videos = _movieData!['videos']?['results'] as List<dynamic>?;
    final trailer = videos?.firstWhere((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer', orElse: () => videos.firstOrNull) ?? videos?.firstOrNull;

    if (trailer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No trailer available', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316)));
      }
      return;
    }

    final url = Uri.parse('https://www.youtube.com/watch?v=${trailer['key']}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch trailer', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316)));
      }
    }
  }

  void _showAddReviewDialog() {
    final TextEditingController reviewController = TextEditingController();
    double currentRating = 5.0;
    bool isSubmitting = false;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
                            await ApiService.postReview(movieId: widget.movieId, rating: currentRating, comment: reviewController.text);
                            if (!context.mounted) return; 
                            Navigator.pop(context);
                            _fetchDetails(); 
                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Review added successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                          } catch (e) {
                            if (!context.mounted) return; 
                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Failed to post review', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
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

  String _formatRuntime(int totalMinutes) {
    if (totalMinutes <= 0) return '';
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF09090B), body: Center(child: CircularProgressIndicator(color: Color(0xFFA855F7))));
    if (_errorMessage.isNotEmpty || _movieData == null) return Scaffold(backgroundColor: const Color(0xFF09090B), appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.canPop() ? context.pop() : context.go('/'))), body: Center(child: Text(_errorMessage.isNotEmpty ? _errorMessage : 'Movie details not found', style: const TextStyle(color: Colors.redAccent))));

    final title = _movieData!['title'] ?? _movieData!['name'] ?? 'Untitled';
    final overview = _movieData!['overview'] ?? 'No overview available.';
    final posterPath = _movieData!['poster_path'];
    final backdropPath = _movieData!['backdrop_path'];
    final releaseDate = _movieData!['release_date'] ?? '';
    final releaseYear = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
    final runtime = _movieData!['runtime'] is int ? (_movieData!['runtime'] as int) : int.tryParse(_movieData!['runtime']?.toString() ?? '0') ?? 0;
    final formattedRuntime = _formatRuntime(runtime);
    final voteAverage = (_movieData!['vote_average'] ?? 0.0).toStringAsFixed(1);
    final genres = (_movieData!['genres'] as List<dynamic>?)?.map((g) => g['name'].toString()).toList() ?? [];
    final cast = (_movieData!['credits']?['cast'] as List<dynamic>?) ?? [];
    final director = (_movieData!['credits']?['crew'] as List<dynamic>?)?.firstWhere((crew) => crew['job'] == 'Director', orElse: () => null)?['name'] ?? 'Unknown Director';

    final backdropUrl = backdropPath != null ? 'https://image.tmdb.org/t/p/w1280$backdropPath' : (posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '');
    final posterUrl = posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '';

    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    final currentStatus = watchlistProvider.getMediaStatus(widget.movieId, mediaType: 'movie');
    final isWatchlist = currentStatus == 'watchlist';
    final isFavorite = currentStatus == 'favorite';
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final bool isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
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
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPoster(posterUrl),
                              const SizedBox(width: 40),
                              Expanded(child: _buildDetailsColumn(title, director, voteAverage, releaseYear, formattedRuntime, genres, overview, posterPath, runtime, releaseDate, isWatchlist, isFavorite, watchlistProvider, scaffoldMessenger)),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: _buildPoster(posterUrl)),
                              const SizedBox(height: 24),
                              _buildDetailsColumn(title, director, voteAverage, releaseYear, formattedRuntime, genres, overview, posterPath, runtime, releaseDate, isWatchlist, isFavorite, watchlistProvider, scaffoldMessenger),
                            ],
                          ),
                        const SizedBox(height: 48),

                        if (cast.isNotEmpty) ...[
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [Text('Actors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), Icon(Icons.chevron_right_rounded, color: Colors.white)]
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 190,
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
                                  final profileUrl = person['profile_path'] != null ? 'https://image.tmdb.org/t/p/w185${person['profile_path']}' : '';

                                  return GestureDetector(
                                    onTap: () => context.go('/person/$personId'),
                                    child: Container(
                                      width: 110,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: profileUrl.isNotEmpty 
                                                ? Image.network(profileUrl, height: 140, width: 110, fit: BoxFit.cover)
                                                : Container(height: 140, width: 110, color: const Color(0xFF131316), child: const Icon(Icons.person_rounded, color: Colors.white24, size: 40)),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(personName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                          Text(character, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
                            ? const Text('No reviews yet for this movie.', style: TextStyle(color: Colors.white54, fontSize: 14))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                                  final review = _reviews[index];
                                  final authorLetter = review.username.isNotEmpty ? review.username[0].toUpperCase() : '?';
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: const Color(0xFF131316), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(radius: 16, backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.2), child: Text(authorLetter, style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 14))),
                                            const SizedBox(width: 12),
                                            Text(review.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                            const Spacer(),
                                            Row(children: [const Icon(Icons.star_rounded, color: Color(0xFFA855F7), size: 14), const SizedBox(width: 4), Text('${review.rating}/10', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))])
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(review.comment ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                                      ],
                                    ),
                                  );
                                },
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
    return Container(
      width: 280,
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: NetworkImage(posterUrl), fit: BoxFit.cover),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, offset: const Offset(0, 8))],
      ),
    );
  }

  Widget _buildDetailsColumn(
    String title, String director, String voteAverage, String releaseYear, String formattedRuntime, 
    List<String> genres, String overview, String? posterPath, int runtime, String releaseDate, 
    bool isWatchlist, bool isFavorite, WatchlistProvider watchlistProvider, ScaffoldMessengerState scaffoldMessenger
  ) {
    final providerLogoUrl = _getTopProviderLogoUrl();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1))),
            
            GestureDetector(
              onTap: () => _showWhereToWatchModal(title),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Row(children: [Text('Where to Watch', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), SizedBox(width: 4), Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 10)]),
                  const SizedBox(height: 8),
                  providerLogoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(providerLogoUrl, width: 32, height: 32, fit: BoxFit.cover),
                        )
                      : const Text('No services', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Directed by $director', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (releaseYear.isNotEmpty) Text(releaseYear, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            if (formattedRuntime.isNotEmpty) Text('•  $formattedRuntime', style: const TextStyle(color: Colors.white54, fontSize: 14)),
            if (genres.isNotEmpty) Text('•  ${genres.join(", ")}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFA855F7), size: 14),
                  const SizedBox(width: 4),
                  Text(voteAverage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        Text(overview, style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 15)),
        const SizedBox(height: 32),

        Row(
          children: [
            InkWell(
              onTap: () => _showMarkWatchedMenu(title, posterPath, runtime, releaseDate),
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
              icon: Icons.bookmark_add_outlined,
              isActive: isWatchlist,
              onTap: () async {
                if (isWatchlist) {
                  await watchlistProvider.removeFromWatchlist(widget.movieId, mediaType: 'movie');
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Removed from Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                } else {
                  await watchlistProvider.addToWatchlist(movieId: widget.movieId, movieTitle: title, posterPath: posterPath, status: 'watchlist', mediaType: 'movie', releaseYear: releaseYear, runtime: runtime, voteAverage: double.tryParse(voteAverage) ?? 0.0);
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Added to Watchlist', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                }
              },
            ),
            const SizedBox(width: 12),

            _buildIconButton(
              icon: Icons.play_circle_outline_rounded,
              isActive: false,
              onTap: _launchTrailerDirectly,
            ),
            const SizedBox(width: 12),

            _buildIconButton(
              icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              isActive: isFavorite,
              activeColor: Colors.redAccent,
              onTap: () async {
                if (isFavorite) {
                  await watchlistProvider.removeFromWatchlist(widget.movieId, mediaType: 'movie');
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Removed from Favorite', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                } else {
                  await watchlistProvider.addToWatchlist(movieId: widget.movieId, movieTitle: title, posterPath: posterPath, status: 'favorite', mediaType: 'movie', releaseYear: releaseYear, runtime: runtime, voteAverage: double.tryParse(voteAverage) ?? 0.0);
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Added to Favorite', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF131316), behavior: SnackBarBehavior.floating));
                }
              },
            ),
            const SizedBox(width: 12),

            _buildIconButton(
              icon: Icons.more_vert_rounded, 
              isActive: false, 
              // 👇 UPDATED: Passing Title
              onTap: () => _showMoreOptions(watchlistProvider, posterPath, title),
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
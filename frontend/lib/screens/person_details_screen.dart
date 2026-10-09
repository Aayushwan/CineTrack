import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';

class PersonDetailsScreen extends StatefulWidget {
  final int personId;

  const PersonDetailsScreen({super.key, required this.personId});

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _personDetails;

  @override
  void initState() {
    super.initState();

    _fetchPersonDetails();

    // Load watchlist items and custom lists so MovieCard can determine
    // whether each title is already in the user's watchlist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Provider.of<WatchlistProvider>(context, listen: false).fetchWatchlist();
    });
  }

  Future<void> _fetchPersonDetails() async {
    try {
      final details = await ApiService.getPersonDetails(widget.personId);

      if (!mounted) return;

      setState(() {
        _personDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFA855F7)),
        ),
      );
    }

    if (_errorMessage.isNotEmpty || _personDetails == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            _errorMessage.isNotEmpty ? _errorMessage : 'Failed to load profile',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final name = (_personDetails!['name'] ?? 'Unknown').toString();

    final biography =
        (_personDetails!['biography'] ?? 'No biography available.').toString();

    final knownFor = (_personDetails!['known_for_department'] ?? '').toString();

    final placeOfBirth = (_personDetails!['place_of_birth'] ?? '').toString();

    final birthday = (_personDetails!['birthday'] ?? '').toString();

    final profilePath = _personDetails!['profile_path'];

    final profileUrl = profilePath != null && profilePath.toString().isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500'
              '${profilePath.toString()}'
        : '';

    final combinedCredits = _personDetails!['combined_credits'];

    final castCredits = List<Map<String, dynamic>>.from(
      combinedCredits is Map<String, dynamic>
          ? (combinedCredits['cast'] as List<dynamic>? ?? [])
          : [],
    );

    castCredits.sort((a, b) {
      final dateA = (a['release_date'] ?? a['first_air_date'] ?? '').toString();

      final dateB = (b['release_date'] ?? b['first_air_date'] ?? '').toString();

      return dateB.compareTo(dateA);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 110,
                    height: 150,
                    color: const Color(0xFF131316),
                    child: profileUrl.isNotEmpty
                        ? Image.network(
                            profileUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Colors.white24,
                                  size: 50,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.white24,
                              size: 50,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (knownFor.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          knownFor,
                          style: const TextStyle(
                            color: Color(0xFFA855F7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (birthday.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Born: $birthday',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (placeOfBirth.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          placeOfBirth,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Biography',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              biography,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filmography',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${castCredits.length} titles',
                  style: const TextStyle(
                    color: Color(0xFFA855F7),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (castCredits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No credits found.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  mainAxisExtent: 280,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: castCredits.length,
                itemBuilder: (context, index) {
                  final item = castCredits[index];

                  final mediaId =
                      int.tryParse((item['id'] ?? 0).toString()) ?? 0;

                  final mediaTitle =
                      (item['title'] ?? item['name'] ?? 'Untitled').toString();

                  final character = (item['character'] ?? '').toString().trim();

                  final rawType = (item['media_type'] ?? '')
                      .toString()
                      .toLowerCase();

                  final isTv =
                      rawType == 'tv' ||
                      rawType == 'show' ||
                      item['first_air_date'] != null ||
                      (item['name'] != null && item['title'] == null);

                  final parsedMediaType = isTv ? 'tv' : 'movie';

                  final dateStr =
                      (item['release_date'] ?? item['first_air_date'] ?? '')
                          .toString();

                  final year = dateStr.length >= 4
                      ? dateStr.substring(0, 4)
                      : 'TBA';

                  final itemPoster = item['poster_path'];

                  final itemPosterUrl =
                      itemPoster != null && itemPoster.toString().isNotEmpty
                      ? 'https://image.tmdb.org'
                            '/t/p/w342'
                            '${itemPoster.toString()}'
                      : '';

                  final rating = item['vote_average'] != null
                      ? double.tryParse(item['vote_average'].toString())
                      : null;

                  return MovieCard(
                    id: mediaId,
                    title: mediaTitle,
                    imageUrl: itemPosterUrl,
                    mediaType: parsedMediaType,
                    year: year,
                    rating: rating,
                    subtitle: character.isNotEmpty ? character : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

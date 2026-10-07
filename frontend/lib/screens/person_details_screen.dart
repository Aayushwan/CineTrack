// frontend/lib/screens/person_details_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

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
  }

  Future<void> _fetchPersonDetails() async {
    try {
      final details = await ApiService.getPersonDetails(widget.personId);
      if (mounted) {
        setState(() {
          _personDetails = details;
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

    final name = _personDetails!['name'] ?? 'Unknown';
    final biography = _personDetails!['biography'] ?? 'No biography available.';
    final knownFor = _personDetails!['known_for_department'] ?? '';
    final placeOfBirth = _personDetails!['place_of_birth'] ?? '';
    final birthday = _personDetails!['birthday'] ?? '';
    final profilePath = _personDetails!['profile_path'];
    final profileUrl = profilePath != null
        ? 'https://image.tmdb.org/t/p/w500$profilePath'
        : '';

    // Extract cast credits and sort latest first (descending by release date)
    final castCredits = List<Map<String, dynamic>>.from(
      (_personDetails!['combined_credits']?['cast'] as List<dynamic>?) ?? [],
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
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
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                              child: Icon(Icons.person_rounded, color: Colors.white24, size: 50),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.person_rounded, color: Colors.white24, size: 50),
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
                          style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (birthday.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Born: $birthday',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                      if (placeOfBirth.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          placeOfBirth,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Biography
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
              style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 28),

            // Vertical Filmography List
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
                  style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (castCredits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No credits found.', style: TextStyle(color: Colors.white54, fontSize: 14)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: castCredits.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 18,
                ),
                itemBuilder: (context, index) {
                  final item = castCredits[index];
                  final mediaId = item['id'];
                  final mediaTitle = item['title'] ?? item['name'] ?? 'Untitled';
                  final character = (item['character'] ?? '').toString().trim();

                  // Determine media type
                  final String rawType = (item['media_type'] ?? '').toString().toLowerCase();
                  final bool isTv = rawType == 'tv' ||
                      rawType == 'show' ||
                      item['first_air_date'] != null ||
                      (item['name'] != null && item['title'] == null);

                  // Extract release year
                  final dateStr = (item['release_date'] ?? item['first_air_date'] ?? '').toString();
                  final year = dateStr.length >= 4 ? dateStr.substring(0, 4) : 'TBA';

                  final itemPoster = item['poster_path'];
                  final itemPosterUrl = itemPoster != null && itemPoster.toString().isNotEmpty
                      ? 'https://image.tmdb.org/t/p/w185$itemPoster'
                      : '';

                  return InkWell(
                    onTap: () {
                      if (isTv) {
                        context.go('/tv/$mediaId');
                      } else {
                        context.go('/movie/$mediaId');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          // Poster Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50,
                              height: 75,
                              color: const Color(0xFF131316),
                              child: itemPosterUrl.isNotEmpty
                                  ? Image.network(
                                      itemPosterUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Center(child: Icon(Icons.movie_rounded, color: Colors.white24, size: 24)),
                                    )
                                  : const Center(child: Icon(Icons.movie_rounded, color: Colors.white24, size: 24)),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Title, Role & Metadata
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mediaTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (character.isNotEmpty)
                                  Text(
                                    'as $character',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFA855F7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E1E24),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Text(
                                        isTv ? 'TV' : 'MOVIE',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      year,
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
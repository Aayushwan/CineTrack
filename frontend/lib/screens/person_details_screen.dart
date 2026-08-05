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

    final credits = (_personDetails!['combined_credits']?['cast'] as List<dynamic>?) ?? [];

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
            const SizedBox(height: 24),

            // Filmography / Known For
            if (credits.isNotEmpty) ...[
              const Text(
                'Known For',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 185,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: credits.length,
                  itemBuilder: (context, index) {
                    final item = credits[index];
                    final mediaId = item['id'];
                    final mediaTitle = item['title'] ?? item['name'] ?? 'Untitled';
                    
                    // Normalize media type
                    final String rawType = (item['media_type'] ?? '').toString().toLowerCase();
                    final bool isTv = rawType == 'tv' ||
                        rawType == 'show' ||
                        item['first_air_date'] != null ||
                        (item['name'] != null && item['title'] == null);

                    final itemPoster = item['poster_path'];
                    final itemPosterUrl = itemPoster != null
                        ? 'https://image.tmdb.org/t/p/w185$itemPoster'
                        : '';

                    return GestureDetector(
                      onTap: () {
                        if (isTv) {
                          context.go('/tv/$mediaId');
                        } else {
                          context.go('/movie/$mediaId');
                        }
                      },
                      child: Container(
                        width: 105,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: const Color(0xFF131316),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: itemPosterUrl.isNotEmpty
                                          ? Image.network(
                                              itemPosterUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Center(
                                                child: Icon(Icons.movie_rounded, color: Colors.white24),
                                              ),
                                            )
                                          : const Center(
                                              child: Icon(Icons.movie_rounded, color: Colors.white24),
                                            ),
                                    ),
                                  ),

                                  // Top Left Media Badge (TV / MOVIE)
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isTv ? 'TV' : 'MOVIE',
                                        style: const TextStyle(
                                          color: Color(0xFFA855F7),
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              mediaTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
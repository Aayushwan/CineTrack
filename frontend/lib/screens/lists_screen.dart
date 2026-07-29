// frontend/lib/screens/lists_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/trakt_filter_bar.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  bool _isLoading = true;
  List<dynamic> _watchlistItems = [];

  // Active Trakt Filter: 'media', 'shows', 'movies'
  String _selectedFilter = 'media';

  // Custom User Lists
  final List<Map<String, dynamic>> _myLists = [];

  @override
  void initState() {
    super.initState();
    _fetchWatchlist();
  }

  Future<void> _fetchWatchlist() async {
    try {
      final items = await ApiService.getWatchlist();
      if (mounted) {
        setState(() {
          _watchlistItems = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Filter Watchlist items based on selected Trakt capsule filter
  List<dynamic> get _filteredWatchlist {
    return _watchlistItems.where((item) {
      final String mediaType = (item['media_type'] ?? '').toString().toLowerCase();
      final bool isTv = mediaType == 'tv' || item['first_air_date'] != null;
      final bool isMovie = !isTv;

      if (_selectedFilter == 'movies' && !isMovie) return false;
      if (_selectedFilter == 'shows' && !isTv) return false;
      return true; // 'media' includes both movies and shows
    }).toList();
  }

  // ─── Modal to Create New List ──────────────────────────────────────────────
  void _showCreateListModal() {
    final TextEditingController titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131316),
        title: const Text(
          'Create New List',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter list title...',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFA855F7)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7)),
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                setState(() {
                  _myLists.insert(0, {
                    'title': titleController.text.trim(),
                    'posters': <String>[],
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Modal to Rename List ──────────────────────────────────────────────────
  void _showRenameListModal(int index) {
    final currentTitle = _myLists[index]['title'] ?? '';
    final TextEditingController controller = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131316),
        title: const Text(
          'Rename List',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new list title...',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFA855F7)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7)),
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _myLists[index]['title'] = newTitle;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Dialog to Confirm Delete List ─────────────────────────────────────────
  void _showDeleteListConfirmation(int index) {
    final title = _myLists[index]['title'] ?? 'this list';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131316),
        title: const Text(
          'Delete List',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                _myLists.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String username = authProvider.username ?? 'User';
    final filteredList = _filteredWatchlist;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        title: const Text(
          'Lists',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Center-Aligned Trakt Filter Bar ───────────────────────────
              TraktFilterBar(
                selectedFilter: _selectedFilter,
                showPeople: false, // Only Media, Shows, Movies needed for lists
                onFilterChanged: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
              const SizedBox(height: 20),

              // ─── 1. WATCHLIST SECTION ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _SectionHeader(
                  title: 'Watchlist',
                  onTap: () => context.go('/watchlist'),
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                height: 245,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFA855F7)),
                      )
                    : filteredList.isEmpty
                        ? _buildEmptyState('No $_selectedFilter items in your watchlist.')
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              return _WatchlistPosterCard(item: item);
                            },
                          ),
              ),

              const SizedBox(height: 36),

              // ─── 2. MY LISTS SECTION ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader(
                      title: 'My Lists',
                      onTap: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                      onPressed: _showCreateListModal,
                      tooltip: 'Create New List',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                height: 230,
                child: _myLists.isEmpty
                    ? _buildEmptyState('No custom lists created yet. Tap + to add one!')
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _myLists.length,
                        itemBuilder: (context, index) {
                          final listData = _myLists[index];
                          return _MyListCard(
                            title: listData['title'],
                            author: username,
                            posters: List<String>.from(listData['posters']),
                            onRename: () => _showRenameListModal(index),
                            onDelete: () => _showDeleteListConfirmation(index),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_filter_outlined, color: Colors.white24, size: 36),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRAKT SECTION HEADER: (^) Title >
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SectionHeader({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 1.5),
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. WATCHLIST POSTER CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _WatchlistPosterCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _WatchlistPosterCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final int movieId = item['movie_id'] ?? item['id'] ?? 0;
    final String mediaType = (item['media_type'] ?? '').toString().toLowerCase();
    final bool isTv = mediaType == 'tv' || item['first_air_date'] != null;

    final String posterPath = item['poster_path'] ?? '';
    final String imageUrl = posterPath.isNotEmpty
        ? (posterPath.startsWith('http') ? posterPath : 'https://image.tmdb.org/t/p/w500$posterPath')
        : 'https://via.placeholder.com/130x195';

    final String dateStr = item['release_date'] ?? item['first_air_date'] ?? item['year'] ?? '';
    final String year = dateStr.length >= 4 ? dateStr.substring(0, 4) : '2025';

    final double ratingVal = (item['vote_average'] ?? item['rating'] ?? 0.0).toDouble();
    final String ratingStr = ratingVal > 0 ? ratingVal.toStringAsFixed(1) : '7.5';

    return GestureDetector(
      onTap: () {
        if (isTv) {
          context.go('/tv/$movieId');
        } else {
          context.go('/movie/$movieId');
        }
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF1E1E24),
                        child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 40),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                  ),
                ),

                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bookmark_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.public_rounded, color: Colors.white38, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      year,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12),
                    const SizedBox(width: 2),
                    Text(
                      ratingStr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. MY LIST CARD
// ─────────────────────────────────────────────────────────────────────────────
class _MyListCard extends StatelessWidget {
  final String title;
  final String author;
  final List<String> posters;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _MyListCard({
    required this.title,
    required this.author,
    required this.posters,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final String initial = author.isNotEmpty ? author[0].toUpperCase() : 'U';

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.2),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFFA855F7),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                        children: [
                          const TextSpan(text: 'by '),
                          TextSpan(
                            text: author,
                            style: const TextStyle(
                              color: Color(0xFFA855F7),
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                color: const Color(0xFF1E1E24),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                onSelected: (value) {
                  if (value == 'rename') {
                    onRename();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Rename',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 125,
            child: posters.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'No items in list',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  )
                : Stack(
                    children: List.generate(posters.length.clamp(0, 5), (index) {
                      final double leftOffset = index * 42.0;
                      return Positioned(
                        left: leftOffset,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 85,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(-2, 0),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              posters[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFF22222A),
                                child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 24),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}
// frontend/lib/screens/lists_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/watchlist_provider.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch permanent custom lists from the database on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WatchlistProvider>(context, listen: false).fetchCustomLists();
    });
  }

  // ─── Modal to Create New List ──────────────────────────────────────────────
  void _showCreateListModal(WatchlistProvider provider) {
    final TextEditingController titleController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
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
                onPressed: isSubmitting ? null : () async {
                  final title = titleController.text.trim();
                  if (title.isNotEmpty) {
                    setModalState(() => isSubmitting = true);
                    try {
                      await provider.createList(title);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Created "$title"'), backgroundColor: const Color(0xFF131316))
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent)
                      );
                      setModalState(() => isSubmitting = false);
                    }
                  }
                },
                child: isSubmitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  // ─── Dialog to Confirm Delete List ─────────────────────────────────────────
  void _showDeleteListConfirmation(WatchlistProvider provider, int listId, String title) {
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
              provider.deleteList(listId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Sheet Modal to View All Items in List ────────────────────────
  void _showListDetailsModal(String listTitle, List<String> posters) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131316),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, // Opens taking up 70% of screen
          minChildSize: 0.4,
          maxChildSize: 0.95, // Can be dragged to nearly full screen
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Pop-up Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        listTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                
                // Grid of Posters
                Expanded(
                  child: posters.isEmpty
                      ? const Center(
                          child: Text(
                            'No movies in this list yet.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, // 3 posters per row
                            childAspectRatio: 2 / 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: posters.length,
                          itemBuilder: (context, index) {
                            return _buildSimplePosterCard(posters[index]);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        title: const Text(
          'My Lists',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            onPressed: () => _showCreateListModal(watchlistProvider),
            tooltip: 'Create New List',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ─── CUSTOM LISTS STACKED ROWS ────────────────────────────
              if (watchlistProvider.customLists.isEmpty)
                _buildEmptyState('No custom lists created yet. Tap + to add one!')
              else
                ...watchlistProvider.customLists.map((listData) {
                  final listId = listData['id'];
                  final listTitle = listData['name'] ?? listData['title'] ?? 'Untitled';
                  final List<String> posters = List<String>.from(listData['posters'] ?? []);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // List Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          children: [
                            Expanded(
                              // 👇 Opens the Bottom Sheet Modal
                              child: InkWell(
                                onTap: () => _showListDetailsModal(listTitle, posters),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.remove_circle_outline_rounded, color: Colors.white54, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        listTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 3-Dots Menu for Deleting
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showDeleteListConfirmation(watchlistProvider, listId, listTitle),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Horizontal Poster Row (Preview)
                      SizedBox(
                        height: 220,
                        child: posters.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(left: 20.0),
                                child: Text('No movies in this list yet.', style: TextStyle(color: Colors.white38)),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: posters.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 130,
                                    margin: const EdgeInsets.only(right: 14),
                                    child: _buildSimplePosterCard(posters[index]),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // Refactored to seamlessly work inside both ListView and GridView
  Widget _buildSimplePosterCard(String posterPath) {
    final String imageUrl = posterPath.isNotEmpty
        ? (posterPath.startsWith('http') ? posterPath : 'https://image.tmdb.org/t/p/w500$posterPath')
        : 'https://via.placeholder.com/130x195';

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFF1E1E24),
              child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 40),
            ),
          ),
        ),
        // Top Right 3-Dots (Decorative)
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
          ),
        ),
        // Bottom Right Checkmark (Decorative)
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.black, size: 12, weight: 800),
          ),
        ),
      ],
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
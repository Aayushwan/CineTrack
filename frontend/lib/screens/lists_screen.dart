// frontend/lib/screens/lists_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/watchlist_provider.dart';
import '../widgets/movie_card.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  @override
  void initState() {
    super.initState();
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isNotEmpty) {
                          setModalState(() => isSubmitting = true);
                          try {
                            await provider.createList(title);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            setModalState(() => isSubmitting = false);
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Modal to Rename List ──────────────────────────────────────────────
  void _showRenameListModal(
    WatchlistProvider provider,
    int listId,
    String currentName,
  ) {
    final TextEditingController titleController = TextEditingController(
      text: currentName,
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF131316),
            title: const Text(
              'Rename List',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: titleController,
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isNotEmpty && title != currentName) {
                          setModalState(() => isSubmitting = true);
                          try {
                            await provider.renameList(listId, title);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            setModalState(() => isSubmitting = false);
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Dialog to Confirm Delete List ─────────────────────────────────────────
  void _showDeleteListConfirmation(
    WatchlistProvider provider,
    int listId,
    String title,
  ) {
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
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

  // ─── Modal to View Expanded List (With Custom 3-Dot Remove) ──────────────
  void _showListDetailsModal(
    WatchlistProvider provider,
    int listId,
    String listTitle,
    List<dynamic> items,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        final isWide = screenWidth >= 800;

        return Dialog(
          backgroundColor: const Color(0xFF131316),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            width: isWide ? screenWidth * 0.85 : screenWidth * 0.95,
            height: screenHeight * 0.85,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          listTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 20),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'No items in this list yet.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 160,
                                childAspectRatio: 0.58,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: items.length,
                          itemBuilder: (gridContext, index) {
                            final item = items[index];
                            final rawId = item is Map
                                ? (item['id'] ??
                                      item['movie_id'] ??
                                      item['media_id'])
                                : 0;

                            return Stack(
                              children: [
                                GestureDetector(
                                  onTapDown: (_) =>
                                      Navigator.pop(dialogContext),
                                  child: _buildMovieCardFromItem(
                                    item,
                                    hideActionMenu: true,
                                  ),
                                ),

                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    height: 26,
                                    width: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.more_vert_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      color: const Color(0xFF131316),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: const BorderSide(
                                          color: Colors.white12,
                                        ),
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'remove') {
                                          Navigator.pop(
                                            dialogContext,
                                          ); // Close modal
                                          try {
                                            await provider.removeItemFromList(
                                              listId,
                                              rawId,
                                            );
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Item removed',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                backgroundColor: Color(
                                                  0xFF131316,
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to remove: $e',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .remove_circle_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Remove from list',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
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

              if (watchlistProvider.customLists.isEmpty)
                _buildEmptyState(
                  'No custom lists created yet. Tap + to add one!',
                )
              else
                ...watchlistProvider.customLists.map((listData) {
                  final listId = listData['id'];
                  final listTitle =
                      listData['name'] ?? listData['title'] ?? 'Untitled';
                  final List<dynamic> items =
                      (listData['items'] ?? listData['posters'] ?? [])
                          as List<dynamic>;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showListDetailsModal(
                                  watchlistProvider,
                                  listId,
                                  listTitle,
                                  items,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: Colors.white54,
                                        size: 16,
                                      ),
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
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 👇 Replaced standalone Edit/Delete icons with a clean 3-dot menu
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                              color: const Color(0xFF131316),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Colors.white12),
                              ),
                              onSelected: (value) {
                                if (value == 'rename') {
                                  _showRenameListModal(
                                    watchlistProvider,
                                    listId,
                                    listTitle,
                                  );
                                } else if (value == 'delete') {
                                  _showDeleteListConfirmation(
                                    watchlistProvider,
                                    listId,
                                    listTitle,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Rename List',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete List',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        height: 230,
                        child: items.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(left: 20.0),
                                child: Text(
                                  'No items in this list yet.',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 115,
                                    margin: const EdgeInsets.only(right: 14),
                                    child: _buildMovieCardFromItem(
                                      items[index],
                                    ),
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

  Widget _buildMovieCardFromItem(dynamic item, {bool hideActionMenu = false}) {
    if (item is! Map) {
      return MovieCard(
        id: 0,
        title: 'Unknown',
        imageUrl: item.toString().startsWith('http')
            ? item.toString()
            : 'https://image.tmdb.org/t/p/w500${item.toString()}',
        mediaType: 'movie',
        hideActionMenu: hideActionMenu,
      );
    }

    final rawId = item['id'] ?? item['movie_id'] ?? item['media_id'];
    final int id = rawId != null ? int.tryParse(rawId.toString()) ?? 0 : 0;

    // Extract the title properly. If it falls back to 'Unknown', it means the DB doesn't have it.
    final String title =
        item['title'] ?? item['name'] ?? item['movie_title'] ?? 'Unknown';

    final String rawType = (item['media_type'] ?? '').toString().toLowerCase();
    final String mediaType =
        (rawType == 'tv' || rawType == 'show' || item['name'] != null)
        ? 'tv'
        : 'movie';

    final String posterPath = item['poster_path'] ?? item['poster'] ?? '';
    final String imageUrl = posterPath.isNotEmpty
        ? (posterPath.startsWith('http')
              ? posterPath
              : 'https://image.tmdb.org/t/p/w500$posterPath')
        : '';

    final releaseDate =
        (item['release_year'] ??
                item['release_date'] ??
                item['first_air_date'] ??
                item['year'] ??
                '')
            .toString();
    final yearStr = (releaseDate.length >= 4)
        ? releaseDate.substring(0, 4)
        : null;
    final voteAverage =
        double.tryParse(
          (item['vote_average'] ?? item['rating'] ?? 0.0).toString(),
        ) ??
        0.0;

    return MovieCard(
      id: id,
      title: title,
      imageUrl: imageUrl,
      mediaType: mediaType,
      isLandscape: false,
      year: yearStr,
      rating: voteAverage,
      hideActionMenu: hideActionMenu,
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
            const Icon(
              Icons.movie_filter_outlined,
              color: Colors.white24,
              size: 36,
            ),
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

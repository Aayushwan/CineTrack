import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        Provider.of<WatchlistProvider>(context, listen: false).fetchWatchlist();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);

    final filteredItems = watchlistProvider.items.where((item) {
      if (_selectedFilter == 'all') return true;
      return item.status == _selectedFilter;
    }).toList();

    final canPop = GoRouter.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Optional Back Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (canPop) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => context.pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        'My Collection',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ),
                  // Filter Chips
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('All', 'all'),
                      _buildFilterChip('Watchlist', 'watchlist'),
                      _buildFilterChip('Favorites', 'favorite'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (watchlistProvider.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFE11D48)),
                  ),
                )
              else if (filteredItems.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmark_outline_rounded,
                            size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text(
                          'No items saved in this list yet.',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                          ),
                          onPressed: () => context.go('/'),
                          child: const Text('Explore Titles',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final posterUrl = item.fullPosterUrl.trim();

                      return GestureDetector(
                        onTap: () {
                          final String mediaType = (item as dynamic).mediaType ?? 'movie';

                          if (mediaType == 'tv') {
                            context.go('/tv/${item.movieId}');
                          } else {
                            context.go('/movie/${item.movieId}');
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 🖼️ Full-Cover Poster Image (with safety check)
                                posterUrl.isNotEmpty
                                    ? Image.network(
                                        posterUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          color: const Color(0xFF1E293B),
                                          child: const Center(
                                            child: Icon(Icons.broken_image,
                                                color: Colors.white38, size: 40),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFF1E293B),
                                        child: const Center(
                                          child: Icon(Icons.movie_rounded,
                                              color: Colors.white38, size: 40),
                                        ),
                                      ),

                                // 🌘 Gradient Overlay
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black87,
                                          Colors.black,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // 📝 Title
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  right: 12,
                                  child: Text(
                                    item.movieTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ),

                                // 🗑️ Remove Button
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 20),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        watchlistProvider.removeFromWatchlist(item.movieId);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${item.movieTitle} removed'),
                                            backgroundColor: Colors.grey.shade800,
                                            duration: const Duration(seconds: 2),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = value);
      },
      selectedColor: const Color(0xFFE11D48),
      backgroundColor: const Color(0xFF131316),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white60,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? Colors.transparent : Colors.white10),
    );
  }
}
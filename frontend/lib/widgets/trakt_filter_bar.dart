// frontend/lib/widgets/trakt_filter_bar.dart
import 'package:flutter/material.dart';

class TraktFilterBar extends StatelessWidget {
  /// 'media', 'shows', 'movies', 'people'
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final bool showPeople;

  const TraktFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    this.showPeople = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterItem(
              id: 'media',
              label: 'Media',
              icon: Icons.perm_media_outlined,
              isSelected: selectedFilter == 'media',
              onTap: () => onFilterChanged('media'),
            ),
            const SizedBox(width: 4),
            _FilterItem(
              id: 'shows',
              label: 'Shows',
              icon: Icons.tv_rounded,
              isSelected: selectedFilter == 'shows',
              onTap: () => onFilterChanged('shows'),
            ),
            const SizedBox(width: 4),
            _FilterItem(
              id: 'movies',
              label: 'Movies',
              icon: Icons.movie_outlined,
              isSelected: selectedFilter == 'movies',
              onTap: () => onFilterChanged('movies'),
            ),
            if (showPeople) ...[
              const SizedBox(width: 4),
              _FilterItem(
                id: 'people',
                label: 'People',
                icon: Icons.person_outline_rounded,
                isSelected: selectedFilter == 'people',
                onTap: () => onFilterChanged('people'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color purpleAccent = Color(0xFFA855F7);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.fastOutSlowIn,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? purpleAccent : const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.white,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
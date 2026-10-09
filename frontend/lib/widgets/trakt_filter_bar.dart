// frontend/lib/widgets/trakt_filter_bar.dart

import 'package:flutter/material.dart';

class TraktFilterBar extends StatelessWidget {
  /// Supported values: 'media', 'shows', 'movies', and 'people'.
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
          color: const Color(0xFF141419).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterItem(
              id: 'media',
              label: 'Media',
              icon: Icons.perm_media_outlined,
              selectedIcon: Icons.perm_media_rounded,
              isSelected: selectedFilter == 'media',
              onTap: () => onFilterChanged('media'),
            ),
            const SizedBox(width: 3),
            _FilterItem(
              id: 'shows',
              label: 'Shows',
              icon: Icons.live_tv_outlined,
              selectedIcon: Icons.live_tv_rounded,
              isSelected: selectedFilter == 'shows',
              onTap: () => onFilterChanged('shows'),
            ),
            const SizedBox(width: 3),
            _FilterItem(
              id: 'movies',
              label: 'Movies',
              icon: Icons.local_movies_outlined,
              selectedIcon: Icons.local_movies_rounded,
              isSelected: selectedFilter == 'movies',
              onTap: () => onFilterChanged('movies'),
            ),
            if (showPeople) ...[
              const SizedBox(width: 3),
              _FilterItem(
                id: 'people',
                label: 'People',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
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

class _FilterItem extends StatefulWidget {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterItem> createState() => _FilterItemState();
}

class _FilterItemState extends State<_FilterItem> {
  static const Color _purple = Color(0xFFB143EB);
  static const Color _lightPurple = Color(0xFFCA66FF);
  static const Color _darkPurple = Color(0xFF8431D9);

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = _isHovered || _isPressed;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: 'Show ${widget.label.toLowerCase()}',
      child: Tooltip(
        message: widget.isSelected ? '' : widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() {
              _isHovered = true;
            });
          },
          onExit: (_) {
            setState(() {
              _isHovered = false;
            });
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (pressed) {
                setState(() {
                  _isPressed = pressed;
                });
              },
              borderRadius: BorderRadius.circular(12),
              splashColor: _lightPurple.withValues(alpha: 0.16),
              highlightColor: _lightPurple.withValues(alpha: 0.08),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                height: 38,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isSelected ? 12 : 9,
                ),
                decoration: BoxDecoration(
                  gradient: widget.isSelected
                      ? const LinearGradient(
                          colors: [_purple, _darkPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.isSelected
                      ? null
                      : isInteractive
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isSelected
                        ? _lightPurple.withValues(alpha: 0.28)
                        : isInteractive
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.26),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        widget.isSelected ? widget.selectedIcon : widget.icon,
                        key: ValueKey(widget.isSelected),
                        size: 17,
                        color: widget.isSelected
                            ? Colors.white
                            : isInteractive
                            ? Colors.white.withValues(alpha: 0.82)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 190),
                      curve: Curves.easeOutCubic,
                      child: widget.isSelected
                          ? Padding(
                              padding: const EdgeInsets.only(left: 7),
                              child: Text(
                                widget.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.15,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

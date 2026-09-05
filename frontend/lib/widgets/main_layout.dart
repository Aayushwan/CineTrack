// frontend/lib/widgets/main_layout.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({
    super.key,
    required this.child,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final String currentRoute = GoRouterState.of(context).uri.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Row(
        children: [
          // ─── 1. TRAKT-STYLE FLOATING SIDEBAR ───────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            width: _isExpanded ? 240 : 72,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Column(
              children: [
                // ── Top Header: Hamburger Menu ─────────────────────────
                Container(
                  height: 80,
                  padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 16 : 0),
                  // dynamically align based on state to ensure icon stays centered when collapsed
                  alignment: _isExpanded ? Alignment.centerLeft : Alignment.center,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(), // 👈 Prevents animation layout overflow
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                          tooltip: _isExpanded ? 'Collapse Menu' : 'Expand Menu',
                          splashRadius: 24,
                        ),
                        if (_isExpanded) ...[
                          const SizedBox(width: 12),
                          const Text(
                            'cinetrack',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Middle: Trakt Floating Pill Container (Non-Scrollable) ──
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: _isExpanded ? 8 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131316),
                        borderRadius: BorderRadius.circular(_isExpanded ? 16 : 40),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SidebarNavItem(
                            icon: Icons.search_rounded,
                            label: 'Search',
                            route: '/search',
                            currentRoute: currentRoute,
                            isExpanded: _isExpanded,
                          ),
                          _SidebarNavItem(
                            icon: Icons.home_outlined, 
                            label: 'Home',
                            route: '/',
                            currentRoute: currentRoute,
                            isExpanded: _isExpanded,
                            subItems: _isExpanded ? [
                              _SubNavItem(label: 'Continue Watching', route: '/'),
                              _SubNavItem(label: 'Calendar', route: '/calendar'),
                              _SubNavItem(label: 'Recommended', route: '/recommended'),
                            ] : null,
                          ),
                          _SidebarNavItem(
                            icon: Icons.auto_awesome_rounded, 
                            label: 'Discover',
                            route: '/discover',
                            currentRoute: currentRoute,
                            isExpanded: _isExpanded,
                            subItems: _isExpanded ? [
                              _SubNavItem(label: 'Trending', route: '/discover/trending'),
                              _SubNavItem(label: 'Releases', route: '/releases'),
                              _SubNavItem(label: 'Anticipated', route: '/discover/anticipated'),
                              _SubNavItem(label: 'Popular', route: '/discover/popular'),
                            ] : null,
                          ),
                          _SidebarNavItem(
                            icon: Icons.format_list_bulleted_rounded,
                            label: 'Lists',
                            route: '/lists',
                            currentRoute: currentRoute,
                            isExpanded: _isExpanded,
                            subItems: _isExpanded ? [
                              _SubNavItem(label: 'Watchlist', route: '/watchlist'),
                              _SubNavItem(label: 'My Lists', route: '/lists'),
                            ] : null,
                          ),
                          _SidebarNavItem(
                            icon: Icons.access_time_rounded,
                            label: 'History',
                            route: '/history',
                            currentRoute: currentRoute,
                            isExpanded: _isExpanded,
                          ),
                          _SidebarNavItem(
                            icon: Icons.person_rounded,
                            label: 'Profile',
                            route: '/profile',
                            currentRoute: currentRoute,
                            isExpanded: _isExpanded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ─── 2. MAIN CONTENT AREA ───────────────────────────────────────
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR ITEM WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final bool isExpanded;
  final List<_SubNavItem>? subItems;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.isExpanded,
    this.subItems,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isActiveRoute {
    if (widget.currentRoute == widget.route) return true;
    if (widget.subItems != null) {
      return widget.subItems!.any((sub) => widget.currentRoute == sub.route);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const Color activePurple = Color(0xFFA855F7);
    final bool isHighlighted = _isActiveRoute || _isHovered || _isPressed;
    final Color currentColor = isHighlighted ? activePurple : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: () => context.go(widget.route),
            onHighlightChanged: (pressed) => setState(() => _isPressed = pressed),
            borderRadius: BorderRadius.circular(widget.isExpanded ? 8 : 30),
            splashColor: activePurple.withValues(alpha: 0.2),
            highlightColor: activePurple.withValues(alpha: 0.1),
            child: Container(
              alignment: widget.isExpanded ? Alignment.centerLeft : Alignment.center,
              padding: EdgeInsets.symmetric(
                vertical: 8,
                horizontal: widget.isExpanded ? 10 : 0,
              ),
              decoration: BoxDecoration(
                color: _isActiveRoute
                    ? activePurple.withValues(alpha: 0.15)
                    : _isHovered
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(widget.isExpanded ? 8 : 30),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(), // 👈 Prevents animation layout overflow
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: currentColor,
                      size: 22,
                    ),
                    if (widget.isExpanded) ...[
                      const SizedBox(width: 12),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: currentColor,
                          fontSize: 14,
                          fontWeight: _isActiveRoute ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Sub-items list
        if (widget.isExpanded && widget.subItems != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 1, bottom: 3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(), // 👈 Prevents animation layout overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: widget.subItems!.map((sub) {
                  final bool isSubActive = widget.currentRoute == sub.route;
                  return _SubItemTile(
                    label: sub.label,
                    route: sub.route,
                    isActive: isSubActive,
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _SubNavItem {
  final String label;
  final String route;
  _SubNavItem({required this.label, required this.route});
}

class _SubItemTile extends StatefulWidget {
  final String label;
  final String route;
  final bool isActive;

  const _SubItemTile({
    required this.label,
    required this.route,
    required this.isActive,
  });

  @override
  State<_SubItemTile> createState() => _SubItemTileState();
}

class _SubItemTileState extends State<_SubItemTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const Color activePurple = Color(0xFFA855F7);
    final bool isHighlighted = widget.isActive || _isHovered || _isPressed;
    final Color textColor = isHighlighted ? activePurple : Colors.white70;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () => context.go(widget.route),
        onHighlightChanged: (pressed) => setState(() => _isPressed = pressed),
        borderRadius: BorderRadius.circular(6),
        splashColor: activePurple.withValues(alpha: 0.2),
        highlightColor: activePurple.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
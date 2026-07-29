// frontend/lib/widgets/main_layout.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
    final authProvider = Provider.of<AuthProvider>(context);
    final String username = authProvider.username ?? 'User';
    final String initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Row(
        children: [
          // ─── 1. TRAKT-STYLE DUAL-STATE SIDEBAR ───────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            width: _isExpanded ? 240 : 68,
            clipBehavior: Clip.hardEdge, // 👈 Prevents pixel overflow warnings
            decoration: BoxDecoration(
              color: const Color(0xFF131316),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // ── Top Header: [≡] Toggle + Logo ─────────────────────────
                Container(
                  height: 64,
                  padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 14 : 8),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: _isExpanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                        onPressed: () => setState(() => _isExpanded = !_isExpanded),
                        tooltip: _isExpanded ? 'Collapse Menu' : 'Expand Menu',
                        splashRadius: 20,
                      ),
                      if (_isExpanded) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA855F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.check_box_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
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

                const Divider(color: Colors.white12, height: 1),

                // ── Navigation Menu Items ─────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: _isExpanded ? 8 : 4, // 👈 Tighter horizontal space when collapsed
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search
                        _SidebarNavItem(
                          icon: Icons.search_rounded,
                          label: 'Search',
                          route: '/search',
                          currentRoute: currentRoute,
                          isExpanded: _isExpanded,
                        ),

                        // Home & Sub-items
                        _SidebarNavItem(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          route: '/',
                          currentRoute: currentRoute,
                          isExpanded: _isExpanded,
                          subItems: [
                            _SubNavItem(label: 'Continue Watching', route: '/'),
                            _SubNavItem(label: 'Calendar', route: '/calendar'),
                            _SubNavItem(label: 'Recommended', route: '/recommended'),
                          ],
                        ),

                        // Discover & Sub-items
                        _SidebarNavItem(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Discover',
                          route: '/discover',
                          currentRoute: currentRoute,
                          isExpanded: _isExpanded,
                          subItems: [
                            _SubNavItem(label: 'Trending', route: '/discover/trending'),
                            _SubNavItem(label: 'Releases', route: '/releases'),
                            _SubNavItem(label: 'Anticipated', route: '/discover/anticipated'),
                            _SubNavItem(label: 'Popular', route: '/discover/popular'),
                          ],
                        ),

                        // Lists & Sub-items
                        _SidebarNavItem(
                          icon: Icons.format_list_bulleted_rounded,
                          label: 'Lists',
                          route: '/lists',
                          currentRoute: currentRoute,
                          isExpanded: _isExpanded,
                          subItems: [
                            _SubNavItem(label: 'Watchlist', route: '/watchlist'),
                            _SubNavItem(label: 'My Lists', route: '/lists'),
                          ],
                        ),

                        // History
                        _SidebarNavItem(
                          icon: Icons.access_time_rounded,
                          label: 'History',
                          route: '/history',
                          currentRoute: currentRoute,
                          isExpanded: _isExpanded,
                        ),

                        // Settings / Profile
                        _SidebarNavItem(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          route: '/profile',
                          currentRoute: currentRoute,
                          isExpanded: _isExpanded,
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),

                // ── Footer: Dynamic Logged-in User Profile ───────────────
                InkWell(
                  onTap: () => context.go('/profile'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: _isExpanded ? 14 : 8,
                    ),
                    child: Row(
                      mainAxisAlignment: _isExpanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.2),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Color(0xFFA855F7),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_isExpanded) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
// SIDEBAR ITEM WIDGET (WHITE DEFAULT -> PURPLE ON HOVER / CLICK / ACTIVE)
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
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: () => context.go(widget.route),
            onHighlightChanged: (pressed) => setState(() => _isPressed = pressed),
            borderRadius: BorderRadius.circular(10),
            splashColor: activePurple.withValues(alpha: 0.2),
            highlightColor: activePurple.withValues(alpha: 0.1),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: 10,
                horizontal: widget.isExpanded ? 12 : 8, // 👈 Reduced padding when collapsed
              ),
              decoration: BoxDecoration(
                color: _isActiveRoute
                    ? activePurple.withValues(alpha: 0.15)
                    : _isHovered
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: widget.isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center, // 👈 Center icon in collapsed mode
                children: [
                  Icon(
                    widget.icon,
                    color: currentColor,
                    size: 22,
                  ),
                  if (widget.isExpanded) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: currentColor,
                          fontSize: 15,
                          fontWeight: _isActiveRoute ? FontWeight.bold : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Sub-items rendered only when Sidebar is Expanded
        if (widget.isExpanded && widget.subItems != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 2, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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

        const SizedBox(height: 4),
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
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}